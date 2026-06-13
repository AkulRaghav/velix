// Package natspub implements the routing handler's EventPublisher over NATS
// JetStream. Each envelope-delivery event is published to a per-recipient
// subject; the JetStream stream `VELIX_DELIVER` retains them for replay by
// the delivery fan-out workers.
package natspub

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"

	"github.com/velix/backend/services/routing/internal/handlers"
)

// Publisher publishes events to JetStream.
type Publisher struct {
	js jetstream.JetStream
}

// New connects nothing; it wraps an already-established JetStream context.
func New(js jetstream.JetStream) *Publisher { return &Publisher{js: js} }

// Connect dials NATS and returns a Publisher plus the underlying connection
// (so the caller can close it on shutdown).
func Connect(ctx context.Context, url string) (*Publisher, *nats.Conn, error) {
	nc, err := nats.Connect(url,
		nats.MaxReconnects(-1),
		nats.Name("velix-routing"),
	)
	if err != nil {
		return nil, nil, fmt.Errorf("nats connect: %w", err)
	}
	js, err := jetstream.New(nc)
	if err != nil {
		nc.Close()
		return nil, nil, fmt.Errorf("jetstream: %w", err)
	}
	// Ensure the delivery stream exists. Subjects: velix.deliver.>
	_, err = js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
		Name:     "VELIX_DELIVER",
		Subjects: []string{"velix.deliver.>"},
		Storage:  jetstream.FileStorage,
	})
	if err != nil {
		nc.Close()
		return nil, nil, fmt.Errorf("create stream: %w", err)
	}
	return &Publisher{js: js}, nc, nil
}

// Publish serializes the payload as JSON and publishes to the subject.
func (p *Publisher) Publish(ctx context.Context, subject string, payload any) error {
	data, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal event: %w", err)
	}
	if _, err := p.js.Publish(ctx, subject, data); err != nil {
		return fmt.Errorf("js publish %s: %w", subject, err)
	}
	return nil
}

var _ handlers.EventPublisher = (*Publisher)(nil)
