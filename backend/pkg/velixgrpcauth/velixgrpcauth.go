// Package velixgrpcauth provides gRPC unary + stream interceptors that
// enforce the per-method auth posture documented in the service protos.
//
// Posture is looked up per fully-qualified method name:
//   PostureNone     -> no bearer required (CreateAccount, SignIn, challenge)
//   PostureClient   -> bearer verified; principal injected into the context
//   PostureInternal -> reserved for mTLS service identity (verified at the
//                      transport layer; the interceptor only asserts a bearer
//                      is NOT required)
//
// On a verified client call the principal is injected via velixctx.WithPrincipal
// so handlers read it with velixctx.AccountID / velixctx.DeviceID.
package velixgrpcauth

import (
	"context"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"github.com/velix/backend/pkg/velixauth"
	"github.com/velix/backend/pkg/velixctx"
)

// PostureFunc maps a fully-qualified gRPC method (e.g.
// "/velix.identity.v1.IdentityService/CreateAccount") to its auth posture.
// Methods not present default to PostureClient (secure by default).
type PostureFunc func(fullMethod string) velixauth.Posture

// StaticPostures builds a PostureFunc from an explicit map. Methods absent
// from the map default to PostureClient.
func StaticPostures(m map[string]velixauth.Posture) PostureFunc {
	return func(method string) velixauth.Posture {
		if p, ok := m[method]; ok {
			return p
		}
		return velixauth.PostureClient
	}
}

// UnaryInterceptor returns a grpc.UnaryServerInterceptor enforcing posture.
func UnaryInterceptor(v velixauth.Verifier, posture PostureFunc) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		newCtx, err := authorize(ctx, v, posture(info.FullMethod))
		if err != nil {
			return nil, err
		}
		return handler(newCtx, req)
	}
}

// StreamInterceptor returns a grpc.StreamServerInterceptor enforcing posture.
func StreamInterceptor(v velixauth.Verifier, posture PostureFunc) grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		newCtx, err := authorize(ss.Context(), v, posture(info.FullMethod))
		if err != nil {
			return err
		}
		return handler(srv, &wrappedStream{ServerStream: ss, ctx: newCtx})
	}
}

// authorize applies the posture: PostureNone passes through; PostureClient
// requires a verified bearer and injects the principal.
func authorize(ctx context.Context, v velixauth.Verifier, p velixauth.Posture) (context.Context, error) {
	if p == velixauth.PostureNone || p == velixauth.PostureInternal {
		return ctx, nil
	}
	bearer, err := bearerFromMetadata(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	principal, err := v.Verify(ctx, bearer)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid bearer")
	}
	return velixctx.WithPrincipal(ctx, principal.AccountID, principal.DeviceID), nil
}

// bearerFromMetadata extracts the token from the "authorization: Bearer <t>"
// gRPC metadata header.
func bearerFromMetadata(ctx context.Context) (string, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return "", errMissingBearer
	}
	vals := md.Get("authorization")
	if len(vals) == 0 {
		return "", errMissingBearer
	}
	const prefix = "Bearer "
	h := vals[0]
	if len(h) <= len(prefix) || !strings.EqualFold(h[:len(prefix)], prefix) {
		return "", errMalformedBearer
	}
	return h[len(prefix):], nil
}

type authError string

func (e authError) Error() string { return string(e) }

const (
	errMissingBearer   = authError("missing bearer token")
	errMalformedBearer = authError("malformed authorization header")
)

// wrappedStream overrides Context() so downstream handlers see the injected
// principal.
type wrappedStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (w *wrappedStream) Context() context.Context { return w.ctx }
