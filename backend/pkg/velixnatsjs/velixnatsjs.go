// Package velixnatsjs is the NATS JetStream implementation of the velixnats
// Publisher seam. Services depend on velixnats.Publisher; main.go wires this.
package velixnatsjs

import (
	"context"
	"fmt"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"

	"github.com/velix/backend/pkg/velixnats"
)

// Publisher publishes to JetStream. Synchronous Publish waits for the broker
// ack; PublishAsync returns once enqueued in the async buffer.
type Publisher struct {
	js jetstream.JetStream
}

// New wraps an established JetStream context.
func New(js jetstream.JetStream) *Publisher { return &Publisher{js: js} }

// Connect dials NATS, creates/updates the VELIX stream, and returns the
// publisher plus the connection for shutdown.
func Connect(ctx context.Context, url, streamName string, subjects []string) (*Publisher, *nats.Conn, error) {
	nc, err := nats.Connect(url, nats.MaxReconnects(-1), nats.Name("velix"))
	if err != nil {
		return nil, nil, fmt.Errorf("nats connect: %w", err)
	}
	js, err := jetstream.New(nc)
	if err != nil {
		nc.Close()
		return nil, nil, fmt.Errorf("jetstream: %w", err)
	}
	if streamName != "" {
		if _, err := js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
			Name:     streamName,
			Subjects: subjects,
			Storage:  jetstream.FileStorage,
		}); err != nil {
			nc.Close()
			return nil, nil, fmt.Errorf("create stream: %w", err)
		}
	}
	return &Publisher{js: js}, nc, nil
}

func (p *Publisher) Publish(ctx context.Context, subject string, payload []byte) error {
	if _, err := p.js.Publish(ctx, subject, payload); err != nil {
		return fmt.Errorf("js publish %s: %w", subject, err)
	}
	return nil
}

func (p *Publisher) PublishAsync(ctx context.Context, subject string, payload []byte) error {
	if _, err := p.js.PublishAsync(subject, payload); err != nil {
		return fmt.Errorf("js publish async %s: %w", subject, err)
	}
	return nil
}

var _ velixnats.Publisher = (*Publisher)(nil)
