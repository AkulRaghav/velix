//go:build integration

// Integration tests for the routing pgx stores. These run only with the
// `integration` build tag against a real Postgres reachable via VELIX_TEST_DSN
// (e.g. the infra/dev docker-compose stack with migrations applied):
//
//   docker compose -f infra/dev/docker-compose.yml up -d
//   ./infra/dev/migrate.sh
//   VELIX_TEST_DSN=postgres://velix:velix@localhost:5432/velix_routing?sslmode=disable \
//     go test -tags=integration ./internal/pgxstore/...
package pgxstore

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/velix/backend/services/routing/internal/handlers"
)

func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("VELIX_TEST_DSN")
	if dsn == "" {
		t.Skip("VELIX_TEST_DSN not set; skipping integration test")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	if err := pool.Ping(ctx); err != nil {
		t.Fatalf("ping: %v", err)
	}
	return pool
}

func TestEnvelopeStore_InsertBatch_Integration(t *testing.T) {
	pool := testPool(t)
	defer pool.Close()

	txr, envStore, idemStore := New(pool)
	ctx := context.Background()
	now := time.Now().UTC()

	rows := []handlers.EnvelopeRow{
		{ID: "01TESTENVELOPE0000000000A", RecipientAccountID: "acc-int", RecipientDeviceID: "dev1", Ciphertext: []byte("ct1"), EnqueuedAt: now, TTLAt: now.Add(time.Hour)},
		{ID: "01TESTENVELOPE0000000000B", RecipientAccountID: "acc-int", RecipientDeviceID: "dev2", Ciphertext: []byte("ct2"), EnqueuedAt: now, TTLAt: now.Add(time.Hour)},
	}

	if err := txr.RunSerializable(ctx, func(ctx context.Context, tx handlers.Tx) error {
		return envStore.InsertBatch(ctx, tx, rows)
	}); err != nil {
		t.Fatalf("insert batch: %v", err)
	}

	// Idempotency round-trip.
	if err := txr.RunSerializable(ctx, func(ctx context.Context, tx handlers.Tx) error {
		return idemStore.Put(ctx, tx, "acc-int", "key-int", []byte("blob"), now.Add(24*time.Hour))
	}); err != nil {
		t.Fatalf("idem put: %v", err)
	}
	blob, found, err := idemStore.Get(ctx, "acc-int", "key-int")
	if err != nil {
		t.Fatalf("idem get: %v", err)
	}
	if !found || string(blob) != "blob" {
		t.Fatalf("idem get: found=%v blob=%q", found, blob)
	}
}
