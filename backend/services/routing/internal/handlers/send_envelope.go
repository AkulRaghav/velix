// Package handlers implements the routing service's RPC entry points.
//
// Each handler:
//   - validates input
//   - checks idempotency
//   - performs the durable write
//   - publishes the NATS event
//   - returns the response (cached in idempotency table for 24h)
package handlers

import (
	"context"
	"fmt"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// MaxCiphertextBytes is the per-envelope ciphertext size limit.
// Larger payloads must use media uploads (presigned R2 URL).
const MaxCiphertextBytes = 64 * 1024

// MaxRecipientsPerSend bounds the fanout per RPC. Group conversations with
// more devices send multiple SendEnvelope RPCs.
const MaxRecipientsPerSend = 256

// SendEnvelopeRequest is the abstract request shape this handler operates on.
// In production the proto-generated *routingv1.SendEnvelopeRequest is a
// drop-in match; we keep the handler interface-driven so tests can use
// hand-rolled fixtures and so the proto package is hot-swappable.
type SendEnvelopeRequest struct {
	IdempotencyKey string
	Recipients     []EnvelopeRecipient
}

type EnvelopeRecipient struct {
	RecipientAccountID string
	RecipientDeviceID  string
	Ciphertext         []byte
}

type SendEnvelopeResponse struct {
	Delivered []DeliveredEnvelope
}

type DeliveredEnvelope struct {
	RecipientDeviceID string
	EnvelopeID        string
	EnqueuedAt        time.Time
}

// SendEnvelope is the realtime hot path. p99 server-side handler time ≤ 80 ms.
// See docs/phase-6/03-realtime-messaging.md.
func (h *RoutingHandlers) SendEnvelope(
	ctx context.Context,
	req *SendEnvelopeRequest,
) (*SendEnvelopeResponse, error) {
	if err := validateSendEnvelope(req); err != nil {
		return nil, err
	}

	auth := h.auth.MustFromContext(ctx)

	// Idempotency: if we've already processed this (account, key), return the
	// cached response. The cache lives in Postgres for durability + Redis for
	// hot reads; the read-through is encapsulated by IdempotencyStore.
	if cached, ok, err := h.idem.Get(ctx, auth.AccountID, req.IdempotencyKey); err != nil {
		return nil, status.Errorf(codes.Internal, "idem lookup: %v", err)
	} else if ok {
		// We previously serialized the response; deserialize and return.
		out := &SendEnvelopeResponse{}
		if err := h.codec.Unmarshal(cached, out); err != nil {
			// Corrupt cache row — fall through and re-run the handler. The
			// underlying writes are idempotent on (idempotency_key, recipient_device).
			h.log.Warn(ctx, "idem cache unmarshal failed; replaying handler",
				"account", auth.AccountID, "key", req.IdempotencyKey)
		} else {
			return out, nil
		}
	}

	// Durable write: one message_envelope row per recipient device, in a
	// single transaction. Each row carries a server-assigned ULID.
	envelopes := make([]EnvelopeRow, 0, len(req.Recipients))
	enqueuedAt := h.clock.Now().UTC()
	ttl := enqueuedAt.Add(30 * 24 * time.Hour)
	for _, r := range req.Recipients {
		id, err := h.ids.NewULID()
		if err != nil {
			return nil, status.Errorf(codes.Internal, "id gen: %v", err)
		}
		envelopes = append(envelopes, EnvelopeRow{
			ID:                 id,
			RecipientAccountID: r.RecipientAccountID,
			RecipientDeviceID:  r.RecipientDeviceID,
			Ciphertext:         r.Ciphertext,
			EnqueuedAt:         enqueuedAt,
			TTLAt:              ttl,
		})
	}

	resp := &SendEnvelopeResponse{Delivered: make([]DeliveredEnvelope, 0, len(envelopes))}

	if err := h.tx.RunSerializable(ctx, func(ctx context.Context, tx Tx) error {
		if err := h.envelopes.InsertBatch(ctx, tx, envelopes); err != nil {
			return fmt.Errorf("insert envelopes: %w", err)
		}
		// Build response inside the transaction so we can serialize it for
		// the idempotency cache before returning.
		for _, e := range envelopes {
			resp.Delivered = append(resp.Delivered, DeliveredEnvelope{
				RecipientDeviceID: e.RecipientDeviceID,
				EnvelopeID:        e.ID,
				EnqueuedAt:        e.EnqueuedAt,
			})
		}
		// Persist the idempotency response.
		blob, err := h.codec.Marshal(resp)
		if err != nil {
			return fmt.Errorf("marshal idem cache: %w", err)
		}
		if err := h.idem.Put(ctx, tx, auth.AccountID, req.IdempotencyKey, blob,
			enqueuedAt.Add(24*time.Hour)); err != nil {
			return fmt.Errorf("put idem: %w", err)
		}
		return nil
	}); err != nil {
		return nil, status.Errorf(codes.Internal, "tx: %v", err)
	}

	// After commit, fan out to NATS. We do NOT block the response on these
	// publishes; failures are retried by a background reconciler that scans
	// for envelopes whose row exists but whose NATS publish never succeeded
	// (tracked via a `nats_published_at IS NULL` partial index).
	//
	// TTL: the publish here uses a context with a 1s timeout so a degraded
	// NATS does not slow the hot path. The reconciler is the safety net.
	go h.publishEnvelopesAsync(envelopes)

	h.metrics.EnvelopesEnqueued.Add(float64(len(envelopes)))

	return resp, nil
}

// publishEnvelopesAsync emits velix.deliver.<account>.<device> for each
// recipient. The hot path does not wait. Reconciliation handles publish
// failures; see docs/phase-6/11-failure-and-retry.md.
func (h *RoutingHandlers) publishEnvelopesAsync(envelopes []EnvelopeRow) {
	pubCtx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()
	for _, e := range envelopes {
		subject := fmt.Sprintf("velix.deliver.%s.%s", e.RecipientAccountID, e.RecipientDeviceID)
		if err := h.events.Publish(pubCtx, subject, &DeliverEnvelopeEventDTO{
			EventID:            e.ID,
			EnvelopeID:         e.ID,
			RecipientAccountID: e.RecipientAccountID,
			RecipientDeviceID:  e.RecipientDeviceID,
			Ciphertext:         e.Ciphertext,
			EnqueuedAt:         e.EnqueuedAt,
			TTLAt:              e.TTLAt,
		}); err != nil {
			// Non-fatal: reconciler will retry. We do bump a metric so we know.
			h.metrics.PublishFailures.Inc()
			h.log.Warn(pubCtx, "deliver-publish failed", "envelope_id", e.ID, "err", err)
		}
	}
}

// validateSendEnvelope is the explicit gate at the top of SendEnvelope.
// Returning anything other than InvalidArgument from here is a bug.
func validateSendEnvelope(req *SendEnvelopeRequest) error {
	if req == nil {
		return status.Error(codes.InvalidArgument, "nil request")
	}
	if req.IdempotencyKey == "" {
		return status.Error(codes.InvalidArgument, "idempotency_key required")
	}
	if len(req.IdempotencyKey) > 64 {
		return status.Error(codes.InvalidArgument, "idempotency_key too long")
	}
	if len(req.Recipients) == 0 {
		return status.Error(codes.InvalidArgument, "recipients required")
	}
	if len(req.Recipients) > MaxRecipientsPerSend {
		return status.Errorf(codes.InvalidArgument,
			"too many recipients: %d > %d", len(req.Recipients), MaxRecipientsPerSend)
	}
	for i, r := range req.Recipients {
		if r.RecipientAccountID == "" {
			return status.Errorf(codes.InvalidArgument,
				"recipients[%d].recipient_account_id required", i)
		}
		if r.RecipientDeviceID == "" {
			return status.Errorf(codes.InvalidArgument,
				"recipients[%d].recipient_device_id required", i)
		}
		if len(r.Ciphertext) == 0 {
			return status.Errorf(codes.InvalidArgument,
				"recipients[%d].ciphertext required", i)
		}
		if len(r.Ciphertext) > MaxCiphertextBytes {
			return status.Errorf(codes.InvalidArgument,
				"recipients[%d].ciphertext too large: %d > %d",
				i, len(r.Ciphertext), MaxCiphertextBytes)
		}
	}
	return nil
}
