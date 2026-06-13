// Package handlers implements the NotifierService RPCs.
//
// Internal-only service. Consumed by Velix services + a NATS subscription
// on velix.push.requested. Forwards encrypted payloads to APNs / FCM /
// WebPush. Never decrypts.
package handlers

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixnats"
	"github.com/velix/backend/pkg/velixobs"
	"github.com/velix/backend/pkg/velixsql"
)

const MaxPayloadBytes = 4 * 1024 // APNs/FCM payload ceiling

type Deps struct {
	TxRunner   velixsql.TxRunner
	Deliveries DeliveryStore
	APNs       APNsClient
	FCM        FCMClient
	WebPush    WebPushClient
	Tokens     TokenLookup
	Events     velixnats.Publisher
	Clock      Clock
	IDs        IDGenerator
	Log        velixobs.Logger
	Metrics    *Metrics
}

type NotifierHandlers struct {
	tx       velixsql.TxRunner
	delivs   DeliveryStore
	apns     APNsClient
	fcm      FCMClient
	webpush  WebPushClient
	tokens   TokenLookup
	events   velixnats.Publisher
	clock    Clock
	ids      IDGenerator
	log      velixobs.Logger
	metrics  *Metrics
}

func NewHandlers(d Deps) *NotifierHandlers {
	return &NotifierHandlers{
		tx: d.TxRunner, delivs: d.Deliveries,
		apns: d.APNs, fcm: d.FCM, webpush: d.WebPush, tokens: d.Tokens,
		events: d.Events, clock: d.Clock, ids: d.IDs, log: d.Log, metrics: d.Metrics,
	}
}

type Delivery struct {
	ID         string
	EventID    string
	DeviceID   string
	Platform   string
	State      string
	UpdatedAt  time.Time
	Reason     string
}

type DeliveryStore interface {
	Insert(ctx context.Context, tx velixsql.Tx, d Delivery) error
	GetByID(ctx context.Context, tx velixsql.Tx, id string) (Delivery, error)
	GetByEventID(ctx context.Context, tx velixsql.Tx, eventID string) (Delivery, bool, error)
	MarkSent(ctx context.Context, tx velixsql.Tx, id string, at time.Time) error
	MarkFailed(ctx context.Context, tx velixsql.Tx, id string, reason string, at time.Time) error
}

// TokenLookup resolves device → push token. Cached aggressively.
type TokenLookup interface {
	ForDevice(ctx context.Context, deviceID string) (platform string, token []byte, webpush []byte, err error)
}

// APNsClient sends encrypted payloads via Apple Push Notification service.
type APNsClient interface {
	Send(ctx context.Context, token []byte, encryptedPayload []byte, expiresAt time.Time, priority string) error
}

// FCMClient sends encrypted payloads via Firebase Cloud Messaging.
type FCMClient interface {
	Send(ctx context.Context, token []byte, encryptedPayload []byte, expiresAt time.Time, priority string) error
}

// WebPushClient sends encrypted payloads via Web Push protocol.
type WebPushClient interface {
	Send(ctx context.Context, subscription []byte, encryptedPayload []byte, expiresAt time.Time, priority string) error
}

type Clock interface{ Now() time.Time }
type IDGenerator interface{ NewULID() (string, error) }

type Metrics struct {
	PushesEnqueued velixobs.Counter
	PushesSent     velixobs.Counter
	PushesFailed   velixobs.Counter
}

// ----- EnqueuePush ---------------------------------------------------------

type EnqueuePushRequest struct {
	EventID          string
	DeviceID         string
	EncryptedPayload []byte
	ExpiresAt        time.Time
	Priority         string
}

type EnqueuePushResponse struct{ DeliveryID string }

func (h *NotifierHandlers) EnqueuePush(ctx context.Context, req *EnqueuePushRequest) (*EnqueuePushResponse, error) {
	if req == nil || req.EventID == "" || req.DeviceID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "event_id and device_id required")
	}
	if len(req.EncryptedPayload) == 0 || len(req.EncryptedPayload) > MaxPayloadBytes {
		return nil, velixerr.New(velixerr.CodeInvalid, "encrypted_payload size out of range")
	}
	if req.ExpiresAt.IsZero() || req.ExpiresAt.Before(h.clock.Now()) {
		return nil, velixerr.New(velixerr.CodeInvalid, "expires_at must be future")
	}
	priority := req.Priority
	if priority == "" {
		priority = "high"
	}

	// Idempotency: existing delivery for this event_id?
	var existing Delivery
	var found bool
	_ = h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		d, ok, err := h.delivs.GetByEventID(ctx, tx, req.EventID)
		if err == nil && ok {
			existing = d
			found = true
		}
		return nil
	})
	if found {
		return &EnqueuePushResponse{DeliveryID: existing.ID}, nil
	}

	platform, token, webpush, err := h.tokens.ForDevice(ctx, req.DeviceID)
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeNotFound, "no active token for device", err)
	}
	id, err := h.ids.NewULID()
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "id gen", err)
	}
	now := h.clock.Now().UTC()
	delivery := Delivery{
		ID: id, EventID: req.EventID, DeviceID: req.DeviceID,
		Platform: platform, State: "queued", UpdatedAt: now,
	}
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return h.delivs.Insert(ctx, tx, delivery)
	}); err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "insert delivery", err)
	}

	go h.sendAsync(delivery, platform, token, webpush, req.EncryptedPayload, req.ExpiresAt, priority)

	h.metrics.PushesEnqueued.Inc()
	return &EnqueuePushResponse{DeliveryID: id}, nil
}

func (h *NotifierHandlers) sendAsync(d Delivery, platform string, token, webpush, payload []byte, expiresAt time.Time, priority string) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var sendErr error
	switch platform {
	case "apns", "apns_voip":
		sendErr = h.apns.Send(ctx, token, payload, expiresAt, priority)
	case "fcm":
		sendErr = h.fcm.Send(ctx, token, payload, expiresAt, priority)
	case "webpush":
		sendErr = h.webpush.Send(ctx, webpush, payload, expiresAt, priority)
	default:
		sendErr = velixerr.New(velixerr.CodeInvalid, "unknown platform")
	}

	now := h.clock.Now().UTC()
	if sendErr != nil {
		_ = h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
			return h.delivs.MarkFailed(ctx, tx, d.ID, sendErr.Error(), now)
		})
		h.metrics.PushesFailed.Inc()
		return
	}
	_ = h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return h.delivs.MarkSent(ctx, tx, d.ID, now)
	})
	h.metrics.PushesSent.Inc()
}

// ----- GetPushStatus -------------------------------------------------------

type GetPushStatusRequest struct{ DeliveryID string }
type GetPushStatusResponse struct {
	State         string
	Platform      string
	UpdatedAt     time.Time
	FailureReason string
}

func (h *NotifierHandlers) GetPushStatus(ctx context.Context, req *GetPushStatusRequest) (*GetPushStatusResponse, error) {
	if req == nil || req.DeliveryID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "delivery_id required")
	}
	var d Delivery
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		var err error
		d, err = h.delivs.GetByID(ctx, tx, req.DeliveryID)
		return err
	}); err != nil {
		return nil, velixerr.Wrap(velixerr.CodeNotFound, "delivery not found", err)
	}
	return &GetPushStatusResponse{
		State: d.State, Platform: d.Platform,
		UpdatedAt: d.UpdatedAt, FailureReason: d.Reason,
	}, nil
}
