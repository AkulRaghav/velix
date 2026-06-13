package handlers

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	"github.com/velix/backend/pkg/velixctx"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixsql"
)

// ----- Fakes --------------------------------------------------------------

type fakeTx struct{}

func (fakeTx) Exec(context.Context, string, ...any) (velixsql.CommandTag, error) {
	return fakeCommandTag{}, nil
}
func (fakeTx) Query(context.Context, string, ...any) (velixsql.Rows, error) {
	return nil, velixsql.ErrNoRows
}
func (fakeTx) QueryRow(context.Context, string, ...any) velixsql.Row { return fakeRow{} }

type fakeCommandTag struct{}

func (fakeCommandTag) RowsAffected() int64 { return 0 }

type fakeRow struct{}

func (fakeRow) Scan(...any) error { return velixsql.ErrNoRows }

type fakeTxRunner struct{}

func (*fakeTxRunner) Run(ctx context.Context, _ velixsql.Isolation, fn func(context.Context, velixsql.Tx) error) error {
	return fn(ctx, fakeTx{})
}

type fakeTokenStore struct {
	inserted []Token
	revoked  []string
}

func (f *fakeTokenStore) Insert(ctx context.Context, tx velixsql.Tx, t Token) error {
	f.inserted = append(f.inserted, t)
	return nil
}
func (f *fakeTokenStore) Revoke(ctx context.Context, tx velixsql.Tx, tokenID, accountID string) error {
	f.revoked = append(f.revoked, tokenID)
	return nil
}
func (f *fakeTokenStore) List(ctx context.Context, tx velixsql.Tx, accountID string) ([]Token, error) {
	return f.inserted, nil
}

type fakePub struct{}

func (fakePub) Publish(context.Context, string, []byte) error      { return nil }
func (fakePub) PublishAsync(context.Context, string, []byte) error { return nil }

type fakeClock struct{ t time.Time }

func (f fakeClock) Now() time.Time { return f.t }

type fakeIDs struct{ counter atomic.Int64 }

func (f *fakeIDs) NewULID() (string, error) {
	n := f.counter.Add(1)
	return "01HPUSH00000000000000000" + string("0123456789ABCDEFGHJKMNPQRSTVWXYZ"[n%32]), nil
}

type fakeCounter struct{}

func (fakeCounter) Inc()        {}
func (fakeCounter) Add(float64) {}

func newHandlers() (*PushHandlers, *fakeTokenStore) {
	store := &fakeTokenStore{}
	return &PushHandlers{
		tx: &fakeTxRunner{}, tokens: store, events: fakePub{},
		clock: fakeClock{t: time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)},
		ids:   &fakeIDs{}, log: nil,
		metrics: &Metrics{TokensRegistered: fakeCounter{}, TokensRevoked: fakeCounter{}},
	}, store
}

func userCtx() context.Context {
	return velixctx.WithPrincipal(context.Background(), "acc1", "dev1")
}

// ----- Tests --------------------------------------------------------------

func TestRegisterToken_HappyPath(t *testing.T) {
	h, store := newHandlers()
	resp, err := h.RegisterToken(userCtx(), &RegisterTokenRequest{
		IdempotencyKey: "k1", DeviceID: "dev1", Platform: "apns", Token: []byte("apns-token"),
	})
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.TokenID == "" {
		t.Fatal("token id must be set")
	}
	if len(store.inserted) != 1 {
		t.Fatalf("expected 1 token; got %d", len(store.inserted))
	}
}

func TestRegisterToken_RejectsBadPlatform(t *testing.T) {
	h, _ := newHandlers()
	_, err := h.RegisterToken(userCtx(), &RegisterTokenRequest{
		IdempotencyKey: "k1", DeviceID: "dev1", Platform: "telepathy", Token: []byte("x"),
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestRegisterToken_WebpushRequiresSubscription(t *testing.T) {
	h, _ := newHandlers()
	_, err := h.RegisterToken(userCtx(), &RegisterTokenRequest{
		IdempotencyKey: "k1", DeviceID: "dev1", Platform: "webpush",
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestRegisterToken_RequiresPrincipal(t *testing.T) {
	h, _ := newHandlers()
	_, err := h.RegisterToken(context.Background(), &RegisterTokenRequest{
		IdempotencyKey: "k1", DeviceID: "dev1", Platform: "fcm", Token: []byte("t"),
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeUnauthorized {
		t.Fatalf("got %q, want unauthenticated", got)
	}
}

func TestRevokeToken_HappyPath(t *testing.T) {
	h, store := newHandlers()
	if _, err := h.RevokeToken(userCtx(), &RevokeTokenRequest{TokenID: "tok1"}); err != nil {
		t.Fatalf("revoke: %v", err)
	}
	if len(store.revoked) != 1 || store.revoked[0] != "tok1" {
		t.Fatalf("expected tok1 revoked; got %v", store.revoked)
	}
}

func TestListTokens_RequiresPrincipal(t *testing.T) {
	h, _ := newHandlers()
	_, err := h.ListTokens(context.Background(), &ListTokensRequest{})
	if got := velixerr.CodeOf(err); got != velixerr.CodeUnauthorized {
		t.Fatalf("got %q, want unauthenticated", got)
	}
}
