//go:build integration

// Integration tests for the identity pgx stores. Run with the `integration`
// build tag against a migrated Postgres reachable via VELIX_TEST_DSN.
package pgxstore

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/velix/backend/pkg/velixsql"
	"github.com/velix/backend/pkg/velixsqlpgx"
	"github.com/velix/backend/services/identity/internal/handlers"
)

func testRunner(t *testing.T) (*velixsqlpgx.Pool, func()) {
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

func TestAccountDeviceSession_Integration(t *testing.T) {
	pool, closeFn := testRunner(t)
	defer closeFn()

	accounts := NewAccountStore()
	devices := NewDeviceStore()
	sessions := NewSessionStore()
	ctx := context.Background()
	now := time.Now().UTC()

	accID := "01TESTACCOUNT0000000000" + randSuffix()
	devID := "01TESTDEVICE00000000000" + randSuffix()

	err := pool.Run(ctx, velixsql.IsoSerializable, func(ctx context.Context, tx velixsql.Tx) error {
		if err := accounts.InsertAccount(ctx, tx, handlers.Account{
			ID: accID, IdentityPubkeyHash: []byte(accID), Locale: "en", Status: "active", CreatedAt: now,
		}, nil); err != nil {
			return err
		}
		if err := devices.InsertDevice(ctx, tx, handlers.Device{
			ID: devID, AccountID: accID, Name: "test", Platform: "ios",
			PairedAt: now, LastSeenAt: now, Status: "active",
		}, []byte("devpub-"+devID), []byte("attestation")); err != nil {
			return err
		}
		return sessions.InsertSession(ctx, tx, "01TESTSESSION0000000000"+randSuffix(),
			accID, devID, []byte("refresh-hash"), now.Add(24*time.Hour))
	})
	if err != nil {
		t.Fatalf("tx: %v", err)
	}

	// Read the account back.
	err = pool.Run(ctx, velixsql.IsoReadCommitted, func(ctx context.Context, tx velixsql.Tx) error {
		got, err := accounts.GetAccountByID(ctx, tx, accID)
		if err != nil {
			return err
		}
		if got.ID != accID || got.Locale != "en" {
			t.Fatalf("account mismatch: %+v", got)
		}
		devs, err := devices.ListDevicesByAccount(ctx, tx, accID)
		if err != nil {
			return err
		}
		if len(devs) != 1 {
			t.Fatalf("expected 1 device; got %d", len(devs))
		}
		return nil
	})
	if err != nil {
		t.Fatalf("read tx: %v", err)
	}
}

func TestPrekeys_Integration(t *testing.T) {
	pool, closeFn := testRunner(t)
	defer closeFn()

	accounts := NewAccountStore()
	devices := NewDeviceStore()
	prekeys := NewPrekeyStore()
	ctx := context.Background()
	now := time.Now().UTC()

	accID := "01TESTPKACCOUNT00000000" + randSuffix()
	devID := "01TESTPKDEVICE000000000" + randSuffix()

	err := pool.Run(ctx, velixsql.IsoSerializable, func(ctx context.Context, tx velixsql.Tx) error {
		if err := accounts.InsertAccount(ctx, tx, handlers.Account{
			ID: accID, IdentityPubkeyHash: []byte(accID), Locale: "en", Status: "active", CreatedAt: now,
		}, nil); err != nil {
			return err
		}
		if err := devices.InsertDevice(ctx, tx, handlers.Device{
			ID: devID, AccountID: accID, Name: "t", Platform: "ios", PairedAt: now, LastSeenAt: now, Status: "active",
		}, []byte("devpub-"+devID), []byte("att")); err != nil {
			return err
		}
		signed := make([]byte, 32)
		sig := make([]byte, 64)
		if err := prekeys.UpsertSignedPrekey(ctx, tx, accID, devID, signed, sig, now); err != nil {
			return err
		}
		return prekeys.InsertOneTimePrekeys(ctx, tx, accID, devID, [][]byte{make([]byte, 32), make([]byte, 32)})
	})
	if err != nil {
		t.Fatalf("tx: %v", err)
	}

	// Consume one OTPK; second consume should still find one; third returns nil.
	consumed := 0
	for i := 0; i < 3; i++ {
		err = pool.Run(ctx, velixsql.IsoSerializable, func(ctx context.Context, tx velixsql.Tx) error {
			otpk, err := prekeys.ConsumeOneTimePrekey(ctx, tx, accID, devID)
			if err != nil {
				return err
			}
			if otpk != nil {
				consumed++
			}
			return nil
		})
		if err != nil {
			t.Fatalf("consume %d: %v", i, err)
		}
	}
	if consumed != 2 {
		t.Fatalf("expected to consume 2 OTPKs; got %d", consumed)
	}
}
