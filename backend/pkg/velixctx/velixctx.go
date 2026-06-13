// Package velixctx carries cross-cutting request metadata through
// context.Context. Every Velix Go service uses this package for the
// request id, tenant cell, principal, and structured log enrichment.
package velixctx

import (
	"context"
	"time"
)

// Key types are unexported so external packages cannot collide with our keys.
type ctxKey int

const (
	keyRequestID ctxKey = iota + 1
	keyAccountID
	keyDeviceID
	keyCell
	keyDeadline
	keyService
)

// WithRequestID stores the request id (typically the gRPC request-id header).
func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, keyRequestID, id)
}

// RequestID returns the request id, or "" if absent.
func RequestID(ctx context.Context) string {
	v, _ := ctx.Value(keyRequestID).(string)
	return v
}

// WithPrincipal stores the authenticated principal extracted from the bearer.
func WithPrincipal(ctx context.Context, accountID, deviceID string) context.Context {
	ctx = context.WithValue(ctx, keyAccountID, accountID)
	ctx = context.WithValue(ctx, keyDeviceID, deviceID)
	return ctx
}

// AccountID returns the principal account id, or "" if anonymous.
func AccountID(ctx context.Context) string {
	v, _ := ctx.Value(keyAccountID).(string)
	return v
}

// DeviceID returns the principal device id, or "" if anonymous.
func DeviceID(ctx context.Context) string {
	v, _ := ctx.Value(keyDeviceID).(string)
	return v
}

// WithCell stores the cell identifier ("us-east-1", "eu-west-1", etc.).
func WithCell(ctx context.Context, cell string) context.Context {
	return context.WithValue(ctx, keyCell, cell)
}

// Cell returns the cell identifier, or "" if absent.
func Cell(ctx context.Context) string {
	v, _ := ctx.Value(keyCell).(string)
	return v
}

// WithService stores the service name ("routing", "identity", ...).
func WithService(ctx context.Context, name string) context.Context {
	return context.WithValue(ctx, keyService, name)
}

// Service returns the service name, or "" if absent.
func Service(ctx context.Context) string {
	v, _ := ctx.Value(keyService).(string)
	return v
}

// WithSoftDeadline attaches a "soft" deadline that handlers can advisory-
// check without cancelling the context. We use this to abort early on the
// hot path while still allowing background fan-out to complete.
func WithSoftDeadline(ctx context.Context, t time.Time) context.Context {
	return context.WithValue(ctx, keyDeadline, t)
}

// SoftDeadline returns the attached soft deadline, if any.
func SoftDeadline(ctx context.Context) (time.Time, bool) {
	v, ok := ctx.Value(keyDeadline).(time.Time)
	return v, ok
}
