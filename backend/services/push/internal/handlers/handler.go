// Package handlers implements PushService RPCs.
//
// PushService manages device push tokens and emits PushRequestEvent for
// the notifier. It NEVER decrypts user content.
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

var allowedPlatforms = map[string]struct{}{
	"apns": {}, "apns_voip": {}, "fcm": {}, "webpush": {},
}

type Deps struct {
	TxRunner velixsql.TxRunner
	Tokens   TokenStore
	Events   velixnats.Publisher
	Clock    Clock
	IDs      IDGenerator
	Log      velixobs.Logger
	Metrics  *Metrics
}

type PushHandlers struct {
	tx      velixsql.TxRunner
	tokens  TokenStore
	events  velixnats.Publisher
	clock   Clock
	ids     IDGenerator
	log     velixobs.Logger
	metrics *Metrics
}

func NewHandlers(d Deps) *PushHandlers {
	return &PushHandlers{
		tx: d.TxRunner, tokens: d.Tokens, events: d.Events,
		clock: d.Clock, ids: d.IDs, log: d.Log, metrics: d.Metrics,
	}
}

type Token struct {
	ID                 string
	AccountID          string
	DeviceID           string
	Platform           string
	Token              []byte
	WebPushSubscription []byte
	RegisteredAt       time.Time
	LastUsedAt         time.Time
	Status             string
}

type TokenStore interface {
	Insert(ctx context.Context, tx velixsql.Tx, t Token) error
	Revoke(ctx context.Context, tx velixsql.Tx, tokenID, accountID string) error
	List(ctx context.Context, tx velixsql.Tx, accountID string) ([]Token, error)
}

type Clock interface{ Now() time.Time }
type IDGenerator interface{ NewULID() (string, error) }

type Metrics struct {
	TokensRegistered velixobs.Counter
	TokensRevoked    velixobs.Counter
}

// ----- RegisterToken -------------------------------------------------------

type RegisterTokenRequest struct {
	IdempotencyKey      string
	DeviceID            string
	Platform            string
	Token               []byte
	WebPushSubscription []byte
}

type RegisterTokenResponse struct {
	TokenID string
}

func (h *PushHandlers) RegisterToken(ctx context.Context, req *RegisterTokenRequest) (*RegisterTokenResponse, error) {
	if req == nil || req.IdempotencyKey == "" || req.DeviceID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "idempotency_key and device_id required")
	}
	if _, ok := allowedPlatforms[req.Platform]; !ok {
		return nil, velixerr.New(velixerr.CodeInvalid, "platform invalid")
	}
	if req.Platform == "webpush" {
		if len(req.WebPushSubscription) == 0 {
			return nil, velixerr.New(velixerr.CodeInvalid, "webpush_subscription required for webpush")
		}
	} else {
		if len(req.Token) == 0 {
			return nil, velixerr.New(velixerr.CodeInvalid, "token required for native platforms")
		}
	}
	if len(req.Token) > 4096 || len(req.WebPushSubscription) > 4096 {
		return nil, velixerr.New(velixerr.CodeInvalid, "token too large")
	}
	accountID := velixctx.AccountID(ctx)
	if accountID == "" {
		return nil, velixerr.New(velixerr.CodeUnauthorized, "principal required")
	}

	id, err := h.ids.NewULID()
	if err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "id gen", err)
	}
	now := h.clock.Now().UTC()
	tok := Token{
		ID: id, AccountID: accountID, DeviceID: req.DeviceID,
		Platform: req.Platform, Token: req.Token,
		WebPushSubscription: req.WebPushSubscription,
		RegisteredAt: now, LastUsedAt: now, Status: "active",
	}
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return h.tokens.Insert(ctx, tx, tok)
	}); err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "insert token", err)
	}
	h.metrics.TokensRegistered.Inc()
	return &RegisterTokenResponse{TokenID: id}, nil
}

// ----- RevokeToken ---------------------------------------------------------

type RevokeTokenRequest struct{ TokenID string }
type RevokeTokenResponse struct{}

func (h *PushHandlers) RevokeToken(ctx context.Context, req *RevokeTokenRequest) (*RevokeTokenResponse, error) {
	if req == nil || req.TokenID == "" {
		return nil, velixerr.New(velixerr.CodeInvalid, "token_id required")
	}
	accountID := velixctx.AccountID(ctx)
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return h.tokens.Revoke(ctx, tx, req.TokenID, accountID)
	}); err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "revoke", err)
	}
	h.metrics.TokensRevoked.Inc()
	return &RevokeTokenResponse{}, nil
}

// ----- ListTokens ----------------------------------------------------------

type ListTokensRequest struct{}
type ListTokensResponse struct{ Tokens []Token }

func (h *PushHandlers) ListTokens(ctx context.Context, req *ListTokensRequest) (*ListTokensResponse, error) {
	accountID := velixctx.AccountID(ctx)
	if accountID == "" {
		return nil, velixerr.New(velixerr.CodeUnauthorized, "principal required")
	}
	var tokens []Token
	if err := h.tx.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		var err error
		tokens, err = h.tokens.List(ctx, tx, accountID)
		return err
	}); err != nil {
		return nil, velixerr.Wrap(velixerr.CodeInternal, "list", err)
	}
	return &ListTokensResponse{Tokens: tokens}, nil
}
