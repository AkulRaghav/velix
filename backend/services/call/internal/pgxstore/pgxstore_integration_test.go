//go:build integration

// Integration tests for the call pgx store. Run with the `integration` build
// tag against a migrated Postgres reachable via VELIX_TEST_DSN.
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
	"github.com/velix/backend/services/call/internal/handlers"
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

func TestCallLifecycle_Integration(t *testing.T) {
	pool, closeFn := testPool(t)
	defer closeFn()

	store := NewCallStore()
	ctx := context.Background()
	now := time.Now().UTC()
	id := "01TESTCALL00000000000" + suffix()

	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.InsertCall(ctx, tx, handlers.CallRow{
			ID: id, ConversationID: "conv-int", Mode: "video", SecurityMode: "e2ee",
			StartedBy: "acc-int", StartedAt: now, State: "live",
		})
	}); err != nil {
		t.Fatalf("insert: %v", err)
	}

	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		row, err := store.GetByID(ctx, tx, id)
		if err != nil {
			return err
		}
		if row.State != "live" || row.Mode != "video" {
			t.Fatalf("call mismatch: %+v", row)
		}
		return nil
	}); err != nil {
		t.Fatalf("read: %v", err)
	}

	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.MarkEnded(ctx, tx, id, now.Add(time.Minute))
	}); err != nil {
		t.Fatalf("mark ended: %v", err)
	}
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		row, err := store.GetByID(ctx, tx, id)
		if err != nil {
			return err
		}
		if row.State != "ended" || row.EndedAt == nil {
			t.Fatalf("expected ended state with timestamp; got %+v", row)
		}
		return nil
	}); err != nil {
		t.Fatalf("read after end: %v", err)
	}
}
