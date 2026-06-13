package velixnatsjs

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"

	"github.com/velix/backend/pkg/velixnats"
)

// JetStreamFromConn returns a JetStream context for an existing connection.
// Used to build a Consumer alongside a Publisher created via Connect.
func JetStreamFromConn(nc *nats.Conn) (jetstream.JetStream, error) {
	return jetstream.New(nc)
}

// Consumer is a durable JetStream pull consumer implementing velixnats.Consumer.
type Consumer struct {
	cons jetstream.Consumer
}

// NewConsumer creates (or binds to) a durable consumer on the given stream
// filtered to the given subject. The durable name makes the consumer survive
// reconnects so delivery resumes where it left off.
func NewConsumer(ctx context.Context, js jetstream.JetStream, stream, durable, filterSubject string) (*Consumer, error) {
	cons, err := js.CreateOrUpdateConsumer(ctx, stream, jetstream.ConsumerConfig{
		Durable:       durable,
		FilterSubject: filterSubject,
		AckPolicy:     jetstream.AckExplicitPolicy,
		DeliverPolicy: jetstream.DeliverAllPolicy,
	})
	if err != nil {
		return nil, fmt.Errorf("create consumer: %w", err)
	}
	return &Consumer{cons: cons}, nil
}

// Next fetches the next message, blocking up to maxWait. Returns
// (nil, velixnats.ErrTimeout) when idle.
func (c *Consumer) Next(ctx context.Context, maxWait time.Duration) (velixnats.Msg, error) {
	batch, err := c.cons.Fetch(1, jetstream.FetchMaxWait(maxWait))
	if err != nil {
		return nil, fmt.Errorf("fetch: %w", err)
	}
	for m := range batch.Messages() {
		return &msg{m: m}, nil
	}
	if err := batch.Error(); err != nil && !errors.Is(err, context.DeadlineExceeded) {
		return nil, err
	}
	return nil, velixnats.ErrTimeout
}

// msg adapts a jetstream.Msg to velixnats.Msg.
type msg struct {
	m jetstream.Msg
}

func (m *msg) Subject() string { return m.m.Subject() }
func (m *msg) Data() []byte    { return m.m.Data() }

func (m *msg) Ack(_ context.Context) error  { return m.m.Ack() }
func (m *msg) Nak(_ context.Context, delay time.Duration) error {
	return m.m.NakWithDelay(delay)
}
func (m *msg) Term(_ context.Context) error { return m.m.Term() }

var (
	_ velixnats.Consumer = (*Consumer)(nil)
	_ velixnats.Msg      = (*msg)(nil)
)
