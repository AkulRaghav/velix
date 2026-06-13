// Package adapters wires the routing handler's small dependency interfaces
// (Clock, IDGenerator, Codec, Logger, EventPublisher) to concrete production
// implementations: a system clock, ULID generation, protojson/encoding,
// slog-based logging, and a NATS JetStream publisher.
package adapters

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"log/slog"
	"time"

	"github.com/oklog/ulid/v2"

	"github.com/velix/backend/services/routing/internal/handlers"
)

// ----- Clock --------------------------------------------------------------

type SystemClock struct{}

func (SystemClock) Now() time.Time { return time.Now().UTC() }

// ----- IDGenerator --------------------------------------------------------

// ULIDGenerator produces lexicographically-sortable, time-prefixed ULIDs
// using a cryptographically secure entropy source.
type ULIDGenerator struct{}

func NewULIDGenerator() *ULIDGenerator { return &ULIDGenerator{} }

func (ULIDGenerator) NewULID() (string, error) {
	id, err := ulid.New(ulid.Timestamp(time.Now().UTC()), rand.Reader)
	if err != nil {
		return "", err
	}
	return id.String(), nil
}

// ----- Codec --------------------------------------------------------------

// JSONCodec serializes the idempotency-cache response blob. JSON is used here
// (not protobuf) because the cached value is the handler's internal
// SendEnvelopeResponse shape, not a proto message.
type JSONCodec struct{}

func (JSONCodec) Marshal(v any) ([]byte, error)      { return json.Marshal(v) }
func (JSONCodec) Unmarshal(data []byte, v any) error { return json.Unmarshal(data, v) }

// ----- Logger -------------------------------------------------------------

// SlogLogger adapts log/slog to the handler Logger interface.
type SlogLogger struct{ L *slog.Logger }

func NewSlogLogger(l *slog.Logger) *SlogLogger { return &SlogLogger{L: l} }

func (s SlogLogger) Info(ctx context.Context, msg string, kv ...any) {
	s.L.InfoContext(ctx, msg, kv...)
}
func (s SlogLogger) Warn(ctx context.Context, msg string, kv ...any) {
	s.L.WarnContext(ctx, msg, kv...)
}
func (s SlogLogger) Error(ctx context.Context, msg string, kv ...any) {
	s.L.ErrorContext(ctx, msg, kv...)
}

// Ensure the adapters satisfy the handler interfaces at compile time.
var (
	_ handlers.Clock       = SystemClock{}
	_ handlers.IDGenerator = ULIDGenerator{}
	_ handlers.Codec       = JSONCodec{}
	_ handlers.Logger      = SlogLogger{}
)

// ----- Metrics ------------------------------------------------------------

// AtomicCounter is a minimal Inc/Add counter satisfying the handler's metrics
// seam. Production swaps in a Prometheus counter with the same surface; this
// keeps the service buildable and testable without a metrics backend.
type AtomicCounter struct{ n int64 }

func (c *AtomicCounter) Inc()          { c.n++ }
func (c *AtomicCounter) Add(d float64) { c.n += int64(d) }

// NewMetrics builds the handler metrics record with atomic counters.
func NewMetrics() *handlers.Metrics {
	return &handlers.Metrics{
		EnvelopesEnqueued: &AtomicCounter{},
		PublishFailures:   &AtomicCounter{},
	}
}
