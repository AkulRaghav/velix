// Package velixauth is the auth seam.
//
// Bearer extraction, token verification, principal materialization. Each
// service wires this into its gRPC interceptor chain.
//
// Auth postures (per docs/phase-6/02-service-contract.md):
//   AUTH_NONE     - signature-verified RPCs (CreateAccount, SignIn)
//   AUTH_CLIENT   - bearer-verified user RPCs
//   AUTH_INTERNAL - mTLS service identity, no bearer
package velixauth

import (
	"context"
	"errors"
	"time"

	"github.com/velix/backend/pkg/velixctx"
)

// Posture is the auth posture per RPC.
type Posture int

const (
	PostureNone Posture = iota
	PostureClient
	PostureInternal
)

// Verifier verifies a bearer token and returns the principal.
type Verifier interface {
	Verify(ctx context.Context, bearer string) (Principal, error)
}

// Principal is the materialized identity from a verified bearer.
type Principal struct {
	AccountID  string
	DeviceID   string
	SessionID  string
	IssuedAt   time.Time
	ExpiresAt  time.Time
	// Scopes are coarse capability flags ("send", "media", "call", ...).
	Scopes []string
}

// HasScope reports whether the principal carries the given scope.
func (p Principal) HasScope(s string) bool {
	for _, x := range p.Scopes {
		if x == s {
			return true
		}
	}
	return false
}

// Common errors. Wrap with velixerr at handler edges.
var (
	ErrMissingBearer = errors.New("velixauth: missing bearer")
	ErrInvalidBearer = errors.New("velixauth: invalid bearer")
	ErrExpired       = errors.New("velixauth: token expired")
	ErrRevoked       = errors.New("velixauth: token revoked")
)

// Inject puts the principal on the context. The interceptor calls this
// after verification; handlers read it via velixctx.AccountID/DeviceID.
func Inject(ctx context.Context, p Principal) context.Context {
	return velixctx.WithPrincipal(ctx, p.AccountID, p.DeviceID)
}

// MTLSIdentity is the service identity carried in the peer certificate's
// SAN URI when AUTH_INTERNAL is in effect.
type MTLSIdentity struct {
	SPIFFEID string  // e.g., spiffe://velix/services/routing
	Service  string  // "routing"
	Cell     string  // "us-east-1"
}
