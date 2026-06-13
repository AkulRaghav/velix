package handlers

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixctx"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixsql"
)

// PublishPrekeysRequest mirrors identityv1.PublishPrekeysRequest.
type PublishPrekeysRequest struct {
	SignedPrekey          []byte
	SignedPrekeySignature []byte
	SignedAt              time.Time
	OneTimePrekeys        [][]byte
}

type PublishPrekeysResponse struct{}

// PublishPrekeys uploads the device's signed prekey + a fresh batch of
// one-time prekeys. Replaces the signed prekey atomically; appends OTPKs.
func (h *IdentityHandlers) PublishPrekeys(ctx context.Context, req *PublishPrekeysRequest) (*PublishPrekeysResponse, error) {
	if req == nil {
		return nil, errInvalid("nil request")
	}
	if len(req.SignedPrekey) != 32 {
		return nil, errInvalid("signed_prekey must be 32 bytes")
	}
	if len(req.SignedPrekeySignature) != 64 {
		return nil, errInvalid("signed_prekey_signature must be 64 bytes")
	}
	if req.SignedAt.IsZero() {
		return nil, errInvalid("signed_at required")
	}
	if len(req.OneTimePrekeys) > 100 {
		return nil, errInvalid("too many one_time_prekeys (max 100 per call)")
	}
	for i, k := range req.OneTimePrekeys {
		if len(k) != 32 {
			return nil, velixerr.New(velixerr.CodeInvalid, "one_time_prekeys[*] must be 32 bytes; index "+ulid(i))
		}
	}

	accountID := velixctx.AccountID(ctx)
	deviceID := velixctx.DeviceID(ctx)
	if accountID == "" || deviceID == "" {
		return nil, velixerr.New(velixerr.CodeUnauthorized, "principal required")
	}

	if err := h.tx.Run(ctx, velixsql.IsoRepeatableRead, func(ctx context.Context, tx velixsql.Tx) error {
		// Verify the signed prekey signature against the account's identity key.
		idPub, err := h.prekeys.GetIdentityPublicKey(ctx, tx, accountID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeNotFound, "identity not found", err)
		}
		if err := h.sigs.VerifyEd25519(idPub, req.SignedPrekey, req.SignedPrekeySignature); err != nil {
			return velixerr.Wrap(velixerr.CodeUnauthorized, "signed_prekey signature invalid", err)
		}
		if err := h.prekeys.UpsertSignedPrekey(ctx, tx, accountID, deviceID,
			req.SignedPrekey, req.SignedPrekeySignature, req.SignedAt); err != nil {
			return velixerr.Wrap(velixerr.CodeInternal, "upsert signed prekey", err)
		}
		if len(req.OneTimePrekeys) > 0 {
			if err := h.prekeys.InsertOneTimePrekeys(ctx, tx, accountID, deviceID, req.OneTimePrekeys); err != nil {
				return velixerr.Wrap(velixerr.CodeInternal, "insert one-time prekeys", err)
			}
		}
		return nil
	}); err != nil {
		return nil, err
	}

	h.metrics.PrekeysPublished.Add(float64(len(req.OneTimePrekeys)) + 1)
	return &PublishPrekeysResponse{}, nil
}

// FetchPrekeyBundleRequest mirrors identityv1.FetchPrekeyBundleRequest.
type FetchPrekeyBundleRequest struct {
	AccountID string
	DeviceID  string
}

// FetchPrekeyBundle returns the recipient's prekey bundle for X3DH; consumes
// one one-time prekey if available.
func (h *IdentityHandlers) FetchPrekeyBundle(ctx context.Context, req *FetchPrekeyBundleRequest) (*PrekeyBundle, error) {
	if req == nil || req.AccountID == "" || req.DeviceID == "" {
		return nil, errInvalid("account_id and device_id required")
	}
	var bundle PrekeyBundle
	if err := h.tx.Run(ctx, velixsql.IsoRepeatableRead, func(ctx context.Context, tx velixsql.Tx) error {
		idPub, err := h.prekeys.GetIdentityPublicKey(ctx, tx, req.AccountID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeNotFound, "identity not found", err)
		}
		signed, sig, err := h.prekeys.GetSignedPrekey(ctx, tx, req.AccountID, req.DeviceID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeNotFound, "signed prekey missing", err)
		}
		otpk, err := h.prekeys.ConsumeOneTimePrekey(ctx, tx, req.AccountID, req.DeviceID)
		if err != nil {
			return velixerr.Wrap(velixerr.CodeInternal, "consume one-time prekey", err)
		}
		bundle = PrekeyBundle{
			IdentityPublicKey:     idPub,
			SignedPrekey:          signed,
			SignedPrekeySignature: sig,
			OneTimePrekey:         otpk,
		}
		return nil
	}); err != nil {
		return nil, err
	}
	if bundle.OneTimePrekey != nil {
		h.metrics.PrekeyConsumed.Inc()
	}
	return &bundle, nil
}

// ulid is a tiny stringifier for error indices; not a real ULID.
func ulid(n int) string {
	const digits = "0123456789"
	if n < 10 {
		return string(digits[n])
	}
	return ulid(n/10) + string(digits[n%10])
}
