// Package velixnats is the messaging seam.
//
// Velix uses NATS JetStream for past-tense events. The Publisher interface
// is the single way services emit; the Consumer interface is the single way
// they subscribe.
//
// Subjects and stream layout are in docs/phase-6/05-event-bus.md.
package velixnats

import (
	"context"
	"time"
)

// Publisher emits NATS messages on a subject. The implementation in
// production wires nats.go's JetStream publisher with at-least-once
// semantics + ack windows.
type Publisher interface {
	// Publish blocks until the broker acks (or the context cancels).
	Publish(ctx context.Context, subject string, payload []byte) error

	// PublishAsync returns immediately; ack arrives via a background
	// channel. The caller is responsible for the failure-handling
	// reconciler (see docs/phase-6/11-failure-and-retry.md).
	PublishAsync(ctx context.Context, subject string, payload []byte) error
}

// Consumer is a durable subscription with explicit ack.
type Consumer interface {
	// Next returns the next message; blocks up to maxWait. Returning
	// (nil, ErrTimeout) is a normal idle.
	Next(ctx context.Context, maxWait time.Duration) (Msg, error)
}

// Msg is a single delivered message.
type Msg interface {
	Subject() string
	Data() []byte
	Ack(ctx context.Context) error
	Nak(ctx context.Context, delay time.Duration) error
	Term(ctx context.Context) error // fatal: do not redeliver
}

// SubjectBuilder constructs valid Velix NATS subjects. Subjects are dot-
// separated and the first segment is always "velix".
//
// Examples:
//   velix.deliver.<account>.<device>
//   velix.account.created
//   velix.media.uploaded
//   velix.push.requested
type SubjectBuilder struct{}

// Deliver is the per-device delivery subject.
func (SubjectBuilder) Deliver(accountID, deviceID string) string {
	return "velix.deliver." + accountID + "." + deviceID
}

// AccountCreated, AccountDeleted, etc.
func (SubjectBuilder) AccountCreated() string  { return "velix.account.created" }
func (SubjectBuilder) AccountDeleted() string  { return "velix.account.deleted" }
func (SubjectBuilder) AccountSuspended() string { return "velix.account.suspended" }
func (SubjectBuilder) DevicePaired() string    { return "velix.device.paired" }
func (SubjectBuilder) DeviceRevoked() string   { return "velix.device.revoked" }
func (SubjectBuilder) MessageRead() string     { return "velix.message.read" }
func (SubjectBuilder) MessageDelivered() string { return "velix.message.delivered" }
func (SubjectBuilder) MediaUploaded() string   { return "velix.media.uploaded" }
func (SubjectBuilder) PushRequested() string   { return "velix.push.requested" }
func (SubjectBuilder) PushDelivered() string   { return "velix.push.delivered" }
func (SubjectBuilder) CallStarted() string     { return "velix.call.started" }
func (SubjectBuilder) CallEnded() string       { return "velix.call.ended" }

// ErrTimeout indicates Next() timed out without a message.
type errTimeout struct{}

func (errTimeout) Error() string { return "velixnats: timeout" }

// ErrTimeout is the sentinel returned by Next() on idle timeout.
var ErrTimeout error = errTimeout{}
