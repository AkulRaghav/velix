// Package velixobs is the observability seam: structured logging, metrics,
// tracing. Implementations live behind interfaces so we can swap zap/slog,
// Prometheus client, and OTel SDK without touching service handlers.
package velixobs

import "context"

// Logger is the structured-log interface. Every Velix service holds one.
//
// Field allowlist (from Phase 8 doc 14): we never log keys named body,
// content, prompt, query, plaintext, message, ciphertext, secret, token,
// password, private_key. The Filter helper enforces this at runtime.
type Logger interface {
	Info(ctx context.Context, msg string, kv ...any)
	Warn(ctx context.Context, msg string, kv ...any)
	Error(ctx context.Context, msg string, kv ...any)
	With(kv ...any) Logger
}

// Counter is a monotonically-increasing metric.
type Counter interface {
	Inc()
	Add(delta float64)
}

// Histogram observes a distribution (latency, sizes).
type Histogram interface {
	Observe(value float64)
}

// Gauge is a settable scalar.
type Gauge interface {
	Set(value float64)
	Inc()
	Dec()
	Add(delta float64)
}

// Meter is the metrics factory (one per service).
type Meter interface {
	Counter(name string, labels ...string) Counter
	Histogram(name string, labels ...string) Histogram
	Gauge(name string, labels ...string) Gauge
}

// Tracer is the trace seam. Implementations wrap OTel.
type Tracer interface {
	Start(ctx context.Context, name string) (context.Context, Span)
}

// Span is a single trace span.
type Span interface {
	SetAttribute(key string, value any)
	RecordError(err error)
	End()
}

// BannedLogKeys are PII-sensitive keys that the structured logger refuses
// to emit. The Filter middleware drops them with a `_redacted=true` marker.
var BannedLogKeys = []string{
	"body", "content", "prompt", "query", "plaintext",
	"message", "ciphertext", "secret", "token", "password", "private_key",
	"display_name", "email", "phone", "handle_input",
}

// Filter scrubs banned keys from a structured-log payload. It is exported
// so service handlers and tests can reuse the same scrub logic.
func Filter(kv []any) []any {
	out := make([]any, 0, len(kv))
	for i := 0; i < len(kv); i += 2 {
		if i+1 >= len(kv) {
			break
		}
		k, ok := kv[i].(string)
		if !ok {
			out = append(out, kv[i], kv[i+1])
			continue
		}
		if isBanned(k) {
			out = append(out, k, "[redacted]")
			continue
		}
		out = append(out, k, kv[i+1])
	}
	return out
}

func isBanned(k string) bool {
	for _, b := range BannedLogKeys {
		if k == b {
			return true
		}
	}
	return false
}
