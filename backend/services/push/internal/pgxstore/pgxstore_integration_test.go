//go:build integration

// Integration tests for the push pgx store. Run with the `integration` build
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
	"github.com/velix/backend/services/push/internal/handlers"
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

func TestTokenStore_Integration(t *testing.T) {
	pool, closeFn := testPool(t)
	defer closeFn()

	store := NewTokenStore()
	ctx := context.Background()
	now := time.Now().UTC()
	accID := "acc-int-" + suffix()
	tokID := "01TESTPUSHTOKEN000000" + suffix()

	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.Insert(ctx, tx, handlers.Token{
			ID: tokID, AccountID: accID, DeviceID: "dev1", Platform: "apns",
			Token: []byte("apns-token"), RegisteredAt: now, LastUsedAt: now, Status: "active",
		})
	}); err != nil {
		t.Fatalf("insert: %v", err)
	}

	// List shows the active token.
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		toks, err := store.List(ctx, tx, accID)
		if err != nil {
			return err
		}
		if len(toks) != 1 || toks[0].ID != tokID {
			t.Fatalf("expected 1 token %s; got %+v", tokID, toks)
		}
		return nil
	}); err != nil {
		t.Fatalf("list: %v", err)
	}

	// Revoke removes it from the active list.
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		return store.Revoke(ctx, tx, tokID, accID)
	}); err != nil {
		t.Fatalf("revoke: %v", err)
	}
	if err := pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		toks, err := store.List(ctx, tx, accID)
		if err != nil {
			return err
		}
		if len(toks) != 0 {
			t.Fatalf("expected 0 active tokens after revoke; got %d", len(toks))
		}
		return nil
	}); err != nil {
		t.Fatalf("list after revoke: %v", err)
	}
}
