//go:build integration

// Integration test for the JetStream publisher + consumer round-trip. Runs
// with the `integration` build tag against a real NATS server (JetStream
// enabled) reachable via VELIX_TEST_NATS_URL (default nats://localhost:4222).
//
//   nats-server -js
//   VELIX_TEST_NATS_URL=nats://localhost:4222 go test -tags=integration ./...
package velixnatsjs

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/velix/backend/pkg/velixnats"
)

func natsURL() string {
	if u := os.Getenv("VELIX_TEST_NATS_URL"); u != "" {
		return u
	}
	return "nats://localhost:4222"
}

func TestPublishConsume_RoundTrip(t *testing.T) {
	if os.Getenv("VELIX_TEST_NATS_URL") == "" && os.Getenv("VELIX_RUN_NATS_IT") == "" {
		t.Skip("set VELIX_TEST_NATS_URL or VELIX_RUN_NATS_IT to run the NATS round-trip test")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	// Unique stream/subject per run so repeated runs don't collide.
	suffix := time.Now().UnixNano()
	stream := "VELIX_IT"
	subject := "velix.it.roundtrip"

	pub, nc, err := Connect(ctx, natsURL(), stream, []string{"velix.it.>"})
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	defer nc.Close()

	// Bind a durable consumer before publishing (DeliverAll catches it anyway).
	jsAccess, err := JetStreamFromConn(nc)
	if err != nil {
		t.Fatalf("jetstream: %v", err)
	}
	cons, err := NewConsumer(ctx, jsAccess, stream, "it-durable", subject)
	if err != nil {
		t.Fatalf("consumer: %v", err)
	}

	payload := []byte("roundtrip-" + time.Now().Format(time.RFC3339Nano))
	_ = suffix
	if err := pub.Publish(ctx, subject, payload); err != nil {
		t.Fatalf("publish: %v", err)
	}

	// Consume it back.
	var got velixnats.Msg
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		m, err := cons.Next(ctx, 2*time.Second)
		if err == velixnats.ErrTimeout {
			continue
		}
		if err != nil {
			t.Fatalf("next: %v", err)
		}
		got = m
		break
	}
	if got == nil {
		t.Fatal("did not receive the published message within deadline")
	}
	if string(got.Data()) != string(payload) {
		t.Fatalf("payload mismatch: got %q want %q", got.Data(), payload)
	}
	if got.Subject() != subject {
		t.Fatalf("subject mismatch: got %q want %q", got.Subject(), subject)
	}
	if err := got.Ack(ctx); err != nil {
		t.Fatalf("ack: %v", err)
	}
}
