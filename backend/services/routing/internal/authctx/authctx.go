// Package authctx provides the routing handler's AuthExtractor. In production
// a gRPC interceptor validates the bearer token and stores the resolved
// account/device on the context; MustFromContext recovers it.
package authctx

import (
	"context"

	"github.com/velix/backend/services/routing/internal/handlers"
)

type ctxKey struct{}

// With returns a copy of ctx carrying the authenticated identity. Called by
// the auth interceptor after it validates the bearer token.
func With(ctx context.Context, accountID, deviceID string) context.Context {
	return context.WithValue(ctx, ctxKey{}, handlers.AuthContext{
		AccountID: accountID,
		DeviceID:  deviceID,
	})
}

// Extractor recovers the authenticated identity placed on the context by the
// interceptor.
type Extractor struct{}

func New() Extractor { return Extractor{} }

func (Extractor) MustFromContext(ctx context.Context) handlers.AuthContext {
	if v, ok := ctx.Value(ctxKey{}).(handlers.AuthContext); ok {
		return v
	}
	// An unauthenticated call reaching a handler is a wiring bug: the auth
	// interceptor must run first. Return a zero value; handlers treat empty
	// account ids as a hard failure on the write path.
	return handlers.AuthContext{}
}

var _ handlers.AuthExtractor = Extractor{}
