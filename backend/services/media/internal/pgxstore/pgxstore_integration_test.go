//go:build integration

// Integration tests for the media pgx store. Run with the `integration`
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
	"github.com/velix/backend/services/media/internal/handlers"
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

func TestMediaLifecycle_Integration(t *testing.T) {
	pool, closeFn := testPool(t)
	defer closeFn()

	store := NewMediaStore()
	ctx := context.Background()
	now := time.Now().UTC()
	id := "01TESTMEDIA0000000000" + suffix()

	// Insert pending.
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.InsertPending(ctx, tx, handlers.MediaRow{
			ID: id, OwnerAccountID: "owner-int", ContentTypeClass: "image",
			SizeBytes: 2048, State: "pending", CreatedAt: now,
		})
	}); err != nil {
		t.Fatalf("insert pending: %v", err)
	}

	// Mark uploaded, then read back.
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.MarkUploaded(ctx, tx, id, make([]byte, 32), now)
	}); err != nil {
		t.Fatalf("mark uploaded: %v", err)
	}
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		row, err := store.GetByID(ctx, tx, id)
		if err != nil {
			return err
		}
		if row.State != "uploaded" {
			t.Fatalf("state = %q, want uploaded", row.State)
		}
		return nil
	}); err != nil {
		t.Fatalf("read: %v", err)
	}

	// Delete.
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.MarkDeleted(ctx, tx, id, now)
	}); err != nil {
		t.Fatalf("mark deleted: %v", err)
	}
}
