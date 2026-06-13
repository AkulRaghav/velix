// Package handlers implements the CallService RPCs.
//
// Brokers LiveKit room creation + token issuance. Bytes flow through
// LiveKit; this service never sees media frames.
package handlers

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixctx"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixnats"
	"github.com/velix/backend/pkg/velixobs"
	"github.com/velix/backend/pkg/velixsql"
)

const (
	CallTokenLifetime = 5 * time.Minute
)

var allowedModes = map[string]struct{}{"audio": {}, "video": {}}
var allowedSecurityModes = map[string]struct{}{"e2ee": {}, "sfu_trust": {}}

type Deps struct {
	TxRunner velixsql.TxRunner
	Calls    CallStore
	LiveKit  LiveKitClient
	Events   velixnats.Publisher
	Clock    Clock
	IDs      IDGenerator
	Log      velixobs.Logger
	Metrics  *Metrics
}

type CallHandlers struct {
	tx       velixsql.TxRunner
	calls    CallStore
	livekit  LiveKitClient
	events   velixnats.Publisher
	clock    Clock
	ids      IDGenerator
	log      velixobs.Logger
	metrics  *Metrics
}

func NewHandlers(d Deps) *CallHandlers {
	return &CallHandlers{
		tx: d.TxRunner, calls: d.Calls, livekit: d.LiveKit, events: d.Events,
		clock: d.Clock, ids: d.IDs, log: d.Log, metrics: d.Metrics,
	}
}

type CallRow struct {
	ID             string
	ConversationID string
	Mode           string
	SecurityMode   string
	StartedBy      string
	StartedAt      time.Time
	EndedAt        *time.Time
	State          string // "live" | "ended"
}

type CallStore interface {
	InsertCall(ctx context.Context, tx velixsql.Tx, c CallRow) error
	GetByID(ctx context.Context, tx velixsql.Tx, id string) (CallRow, error)
	MarkEnded(ctx context.Context, tx velixsql.Tx, id string, endedAt time.Time) error
}

// LiveKitClient brokers rooms and tokens.
type LiveKitClient interface {
	CreateRoom(ctx context.Context, name string) error
	IssueToken(ctx context.Context, room, identity string, e2eeMode bool, ttl time.Duration) (string, error)
	DeleteRoom(ctx context.Context, name string) error
}

type Clock interface{ Now() time.Time }
type IDGenerator interface{ NewULID() (string, error) }

type Metrics struct {
	CallsCreated velixobs.Counter
	CallsEnded   velixobs.Counter
	TokensIssued velixobs.Counter
}

// ----- CreateCall ----------------------------------------------------------

type CreateCallRequest struct {
	IdempotencyKey string
	ConversationID string
	Mode           string
	SecurityMode   string
}

type CreateCallResponse struct {
	CallID         string
	LiveKitRoom    string
	LiveKitToken   string
	TokenExpiresAt time.Time
}

func (h *CallHandlers) CreateCall(ctx context.Context, req *CreateCallRequest) (*CreateCallResponse, error) {
	if req == nil || req.IdempotencyKey == "" || req.ConversationID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "idempotency_key and conversation_id required")
	}
	if _, ok := allowedModes[req.Mode]; !ok {
		return nil, velixerr.New(velixerr.CodeInvalid, "mode must be audio|video")
	}
	if req.SecurityMode == "" {
		req.SecurityMode = "e2ee"
	}
	if _, ok := allowedSecurityModes[req.SecurityMode]; !ok {
		return nil, velixerr.New(velixerr.CodeInvalid, "security_mode must be e2ee|sfu_trust")
	}
	caller := velixctx.AccountID(ctx)
	if caller == "" {
		return nil, velixerr.New(velixerr.CodeUnauthorized, "principal required")
	}

	callID, err := h.ids.NewULID()
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "id gen", err)
	}
	now := h.clock.Now().UTC()
	roomName := "velix-" + callID

	if err := h.livekit.CreateRoom(ctx, roomName); err != nil {
		return nil, velixerr.Wrap(velixerr.CodeUnavailable, "livekit create room", err)
	}
	token, err := h.livekit.IssueToken(ctx, roomName, caller, req.SecurityMode == "e2ee", CallTokenLifetime)
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeUnavailable, "livekit issue token", err)
	}

	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return h.calls.InsertCall(ctx, tx, CallRow{
			ID: callID, ConversationID: req.ConversationID,
			Mode: req.Mode, SecurityMode: req.SecurityMode,
			StartedBy: caller, StartedAt: now, State: "live",
		})
	}); err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "insert call", err)
	}

	h.metrics.CallsCreated.Inc()
	h.metrics.TokensIssued.Inc()
	return &CreateCallResponse{
		CallID: callID, LiveKitRoom: roomName, LiveKitToken: token,
		TokenExpiresAt: now.Add(CallTokenLifetime),
	}, nil
}

// ----- IssueCallToken ------------------------------------------------------

type IssueCallTokenRequest struct{ CallID string }
type IssueCallTokenResponse struct {
	LiveKitToken   string
	TokenExpiresAt time.Time
}

func (h *CallHandlers) IssueCallToken(ctx context.Context, req *IssueCallTokenRequest) (*IssueCallTokenResponse, error) {
	if req == nil || req.CallID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "call_id required")
	}
	caller := velixctx.AccountID(ctx)
	now := h.clock.Now().UTC()
	var roomName string
	var e2ee bool
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		row, err := h.calls.GetByID(ctx, tx, req.CallID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeNotFound, "call not found", err)
		}
		if row.State != "live" {
			return velixerr.New(velixerr.CodeNotFound, "call ended")
		}
		roomName = "velix-" + row.ID
		e2ee = row.SecurityMode == "e2ee"
		return nil
	}); err != nil {
		return nil, err
	}
	token, err := h.livekit.IssueToken(ctx, roomName, caller, e2ee, CallTokenLifetime)
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeUnavailable, "livekit issue token", err)
	}
	h.metrics.TokensIssued.Inc()
	return &IssueCallTokenResponse{LiveKitToken: token, TokenExpiresAt: now.Add(CallTokenLifetime)}, nil
}

// ----- EndCall -------------------------------------------------------------

type EndCallRequest struct {
	IdempotencyKey string
	CallID         string
}
type EndCallResponse struct{}

func (h *CallHandlers) EndCall(ctx context.Context, req *EndCallRequest) (*EndCallResponse, error) {
	if req == nil || req.CallID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "call_id required")
	}
	now := h.clock.Now().UTC()
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		row, err := h.calls.GetByID(ctx, tx, req.CallID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeNotFound, "call not found", err)
		}
		if row.State == "ended" {
			return nil // idempotent
		}
		if err := h.calls.MarkEnded(ctx, tx, row.ID, now); err != nil {
			return velixerr.Wrap(velixerr.CodeInternal, "mark ended", err)
		}
		_ = h.livekit.DeleteRoom(ctx, "velix-"+row.ID)
		return nil
	}); err != nil {
		return nil, err
	}
	h.metrics.CallsEnded.Inc()
	return &EndCallResponse{}, nil
}

// ----- RejectCall ----------------------------------------------------------

type RejectCallRequest struct {
	IdempotencyKey string
	CallID         string
	Reason         string
}
type RejectCallResponse struct{}

func (h *CallHandlers) RejectCall(ctx context.Context, req *RejectCallRequest) (*RejectCallResponse, error) {
	if req == nil || req.CallID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "call_id required")
	}
	// Reject is a notification to the caller; this service publishes an event
	// and does not change the call row state. Other devices stop ringing
	// based on the event.
	_ = h.events.Publish(ctx, "velix.call.rejected", []byte(req.CallID))
	return &RejectCallResponse{}, nil
}
