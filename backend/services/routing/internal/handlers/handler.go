package handlers

import (
	"context"
	"time"
)

// RoutingHandlers is the cohesive entry point for the routing service's
// gRPC implementations. Constructed via NewHandlers in the service main.
//
// Every dependency is an interface so tests can substitute fakes via
// the same mechanism Phase 5 uses on the Flutter side: explicit overrides.
type RoutingHandlers struct {
	auth      AuthExtractor
	tx        TxRunner
	envelopes EnvelopeStore
	idem      IdempotencyStore
	events    EventPublisher
	clock     Clock
	ids       IDGenerator
	codec     Codec
	log       Logger
	metrics   *Metrics
}

func NewHandlers(deps Deps) *RoutingHandlers {
	return &RoutingHandlers{
		auth:      deps.Auth,
		tx:        deps.TxRunner,
		envelopes: deps.Envelopes,
		idem:      deps.Idempotency,
		events:    deps.Events,
		clock:     deps.Clock,
		ids:       deps.IDs,
		codec:     deps.Codec,
		log:       deps.Log,
		metrics:   deps.Metrics,
	}
}

// Deps is the explicit dependency record. Defining it here makes the
// constructor a single seam to swap implementations.
type Deps struct {
	Auth        AuthExtractor
	TxRunner    TxRunner
	Envelopes   EnvelopeStore
	Idempotency IdempotencyStore
	Events      EventPublisher
	Clock       Clock
	IDs         IDGenerator
	Codec       Codec
	Log         Logger
	Metrics     *Metrics
}

// ----- Interfaces ----------------------------------------------------------

type AuthContext struct {
	AccountID string
	DeviceID  string
}

type AuthExtractor interface {
	MustFromContext(ctx context.Context) AuthContext
}

type Tx any

type TxRunner interface {
	RunSerializable(ctx context.Context, fn func(context.Context, Tx) error) error
}

type EnvelopeRow struct {
	ID                 string
	RecipientAccountID string
	RecipientDeviceID  string
	Ciphertext         []byte
	EnqueuedAt         time.Time
	TTLAt              time.Time
}

type EnvelopeStore interface {
	InsertBatch(ctx context.Context, tx Tx, rows []EnvelopeRow) error
}

type IdempotencyStore interface {
	Get(ctx context.Context, accountID, key string) (blob []byte, found bool, err error)
	Put(ctx context.Context, tx Tx, accountID, key string, blob []byte, expiresAt time.Time) error
}

type EventPublisher interface {
	Publish(ctx context.Context, subject string, payload any) error
}

type Clock interface {
	Now() time.Time
}

type IDGenerator interface {
	NewULID() (string, error)
}

type Codec interface {
	Marshal(v any) ([]byte, error)
	Unmarshal(data []byte, v any) error
}

type Logger interface {
	Info(ctx context.Context, msg string, keysAndValues ...any)
	Warn(ctx context.Context, msg string, keysAndValues ...any)
	Error(ctx context.Context, msg string, keysAndValues ...any)
}

// ----- Metrics ------------------------------------------------------------

type Metrics struct {
	EnvelopesEnqueued counter
	PublishFailures   counter
}

type counter interface {
	Inc()
	Add(float64)
}

// ----- DTOs (mirror events.proto) -----------------------------------------

type DeliverEnvelopeEventDTO struct {
	EventID            string
	EnvelopeID         string
	RecipientAccountID string
	RecipientDeviceID  string
	Ciphertext         []byte
	EnqueuedAt         time.Time
	TTLAt              time.Time
}
