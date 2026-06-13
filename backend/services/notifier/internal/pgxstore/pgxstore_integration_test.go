//go:build integration

// Integration tests for the notifier pgx store. Run with the `integration`
// build tag against a migrated Postgres reachable via VELIX_TEST_DSN.
package pgxstore

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/pkg/velixsqlpgx"
	"github.com/velix/backend/services/notifier/internal/handlers"
)

func testPool(t *testing.T) (*velixsqlpgx.Pool, func()) {
	t.Helper()
	dsn := os.Getenv("VELIX_TEST_DSN")
	if dsn == "" {
		t.Skip("VELIX_TEST_DSN not set; skipping integration test")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	raw, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	if err := raw.Ping(ctx); err != nil {
		t.Fatalf("ping: %v", err)
	}
	return velixsqlpgx.NewPool(raw), raw.Close
}

func suffix() string {
	b := make([]byte, 4)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func TestDeliveryLifecycle_Integration(t *testing.T) {
	pool, closeFn := testPool(t)
	defer closeFn()

	store := NewDeliveryStore()
	ctx := context.Background()
	now := time.Now().UTC()
	id := "01TESTDELIVERY00000000" + suffix()
	eventID := "evt-int-" + suffix()

	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.Insert(ctx, tx, handlers.Delivery{
			ID: id, EventID: eventID, DeviceID: "dev-int", Platform: "apns",
			State: "queued", UpdatedAt: now,
		})
	}); err != nil {
		t.Fatalf("insert: %v", err)
	}

	// Idempotency lookup by event id.
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		d, found, err := store.GetByEventID(ctx, tx, eventID)
		if err != nil {
			return err
		}
		if !found || d.ID != id {
			t.Fatalf("GetByEventID: found=%v id=%s", found, d.ID)
		}
		return nil
	}); err != nil {
		t.Fatalf("get by event: %v", err)
	}

	// Mark sent and confirm.
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.MarkSent(ctx, tx, id, now.Add(time.Second))
	}); err != nil {
		t.Fatalf("mark sent: %v", err)
	}
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		d, err := store.GetByID(ctx, tx, id)
		if err != nil {
			return err
		}
		if d.State != "sent" {
			t.Fatalf("state = %q, want sent", d.State)
		}
		return nil
	}); err != nil {
		t.Fatalf("read: %v", err)
	}
}
