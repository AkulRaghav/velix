package handlers

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/velix/backend/pkg/velixctx"
	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixobs"
	"github.com/velix/backend/pkg/velixsql"
)

// ----- Fakes (mirrors of the routing service test fakes) -------------------

type fakeTx struct{}

// fakeTx satisfies velixsql.Tx (which embeds velixsql.Conn). The handler
// business logic never calls these directly in unit tests — it talks to the
// store fakes — so trivial implementations suffice.
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

type fakeTxRunner struct{ commitErr error }

func (f *fakeTxRunner) Run(ctx context.Context, _ velixsql.Isolation, fn func(context.Context, velixsql.Tx) error) error {
	if err := fn(ctx, fakeTx{}); err != nil {
		return err
	}
	return f.commitErr
}

type fakeAccounts struct {
	accounts        map[string]Account
	insertErr       error
	handleConflict  bool
}

func newFakeAccounts() *fakeAccounts { return &fakeAccounts{accounts: map[string]Account{}} }

func (f *fakeAccounts) InsertAccount(ctx context.Context, tx velixsql.Tx, a Account, _ []byte) error {
	if f.insertErr != nil {
		return f.insertErr
	}
	f.accounts[a.ID] = a
	return nil
}
func (f *fakeAccounts) GetAccountByID(ctx context.Context, tx velixsql.Tx, id string) (Account, error) {
	a, ok := f.accounts[id]
	if !ok {
		return Account{}, errors.New("not found")
	}
	return a, nil
}
func (f *fakeAccounts) UpdateLocale(ctx context.Context, tx velixsql.Tx, id, locale string) error {
	return nil
}
func (f *fakeAccounts) ReserveHandle(ctx context.Context, tx velixsql.Tx, accountID, handle string) error {
	if f.handleConflict {
		return errors.New("handle taken")
	}
	return nil
}
func (f *fakeAccounts) UpdateProfile(ctx context.Context, tx velixsql.Tx, accountID, displayNameHash, handle string) (Account, error) {
	return f.accounts[accountID], nil
}

type fakeDevices struct{ devices []Device }

func (f *fakeDevices) InsertDevice(ctx context.Context, tx velixsql.Tx, d Device, _, _ []byte) error {
	f.devices = append(f.devices, d)
	return nil
}
func (f *fakeDevices) GetDeviceByID(ctx context.Context, tx velixsql.Tx, id string) (Device, error) {
	for _, d := range f.devices {
		if d.ID == id {
			return d, nil
		}
	}
	return Device{}, errors.New("not found")
}
func (f *fakeDevices) ListDevicesByAccount(ctx context.Context, tx velixsql.Tx, accountID string) ([]Device, error) {
	out := []Device{}
	for _, d := range f.devices {
		if d.AccountID == accountID {
			out = append(out, d)
		}
	}
	return out, nil
}
func (f *fakeDevices) RevokeDevice(ctx context.Context, tx velixsql.Tx, deviceID, reason string) error {
	for i := range f.devices {
		if f.devices[i].ID == deviceID {
			f.devices[i].Status = "revoked"
			return nil
		}
	}
	return errors.New("not found")
}

type fakePrekeys struct {
	signed map[string][2][]byte
	otpks  map[string][][]byte
	idPub  map[string][]byte
}

func newFakePrekeys() *fakePrekeys {
	return &fakePrekeys{
		signed: map[string][2][]byte{},
		otpks:  map[string][][]byte{},
		idPub:  map[string][]byte{},
	}
}

func (f *fakePrekeys) UpsertSignedPrekey(ctx context.Context, tx velixsql.Tx, accountID, deviceID string, signedPrekey, signature []byte, _ time.Time) error {
	f.signed[accountID+":"+deviceID] = [2][]byte{signedPrekey, signature}
	return nil
}
func (f *fakePrekeys) InsertOneTimePrekeys(ctx context.Context, tx velixsql.Tx, accountID, deviceID string, prekeys [][]byte) error {
	f.otpks[accountID+":"+deviceID] = append(f.otpks[accountID+":"+deviceID], prekeys...)
	return nil
}
func (f *fakePrekeys) ConsumeOneTimePrekey(ctx context.Context, tx velixsql.Tx, accountID, deviceID string) ([]byte, error) {
	key := accountID + ":" + deviceID
	stack := f.otpks[key]
	if len(stack) == 0 {
		return nil, nil
	}
	out := stack[0]
	f.otpks[key] = stack[1:]
	return out, nil
}
func (f *fakePrekeys) GetSignedPrekey(ctx context.Context, tx velixsql.Tx, accountID, deviceID string) ([]byte, []byte, error) {
	pair, ok := f.signed[accountID+":"+deviceID]
	if !ok {
		return nil, nil, errors.New("missing")
	}
	return pair[0], pair[1], nil
}
func (f *fakePrekeys) GetIdentityPublicKey(ctx context.Context, tx velixsql.Tx, accountID string) ([]byte, error) {
	v, ok := f.idPub[accountID]
	if !ok {
		return nil, errors.New("missing")
	}
	return v, nil
}

type fakeSessions struct{ sessions map[string]struct{ accountID, deviceID string } }

func newFakeSessions() *fakeSessions {
	return &fakeSessions{sessions: map[string]struct{ accountID, deviceID string }{}}
}
func (f *fakeSessions) InsertSession(ctx context.Context, tx velixsql.Tx, sessionID, accountID, deviceID string, _ []byte, _ time.Time) error {
	f.sessions[sessionID] = struct{ accountID, deviceID string }{accountID, deviceID}
	return nil
}
func (f *fakeSessions) RevokeSession(ctx context.Context, tx velixsql.Tx, sessionID string) error {
	delete(f.sessions, sessionID)
	return nil
}
func (f *fakeSessions) GetActiveSessionByRefreshHash(ctx context.Context, tx velixsql.Tx, hash []byte) (string, string, string, time.Time, error) {
	return "", "", "", time.Time{}, errors.New("not found")
}
func (f *fakeSessions) RotateRefreshToken(ctx context.Context, tx velixsql.Tx, sessionID string, newHash []byte, newExpiresAt time.Time) error {
	return nil
}

type fakeTokens struct{}

func (fakeTokens) Issue(ctx context.Context, accountID, deviceID string) (TokenPair, []byte, error) {
	return TokenPair{
		AccessToken:      "access",
		RefreshToken:     "refresh",
		AccessExpiresAt:  time.Now().Add(15 * time.Minute),
		RefreshExpiresAt: time.Now().Add(90 * 24 * time.Hour),
	}, []byte{1, 2, 3}, nil
}
func (fakeTokens) Verify(ctx context.Context, accessToken string) (string, string, time.Time, error) {
	return "", "", time.Time{}, errors.New("not implemented")
}
func (fakeTokens) HashRefresh(refresh string) []byte { return []byte(refresh) }

type fakeClock struct{ t time.Time }

func (f fakeClock) Now() time.Time { return f.t }

type fakeIDs struct{ counter atomic.Int64 }

func (f *fakeIDs) NewULID() (string, error) {
	n := f.counter.Add(1)
	return "01HID000000000000000000" + ulidSuffix(n), nil
}

func ulidSuffix(n int64) string {
	const a = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
	if n < 0 {
		n = -n
	}
	return string(a[n%32]) + string(a[(n/32)%32])
}

type fakeHasher struct{}

func (fakeHasher) Hash(pubkey []byte) []byte {
	out := make([]byte, 32)
	copy(out, pubkey)
	return out
}

type acceptingSigs struct{}

func (acceptingSigs) VerifyEd25519(pubkey, message, sig []byte) error {
	if len(pubkey) != 32 || len(sig) != 64 {
		return velixerr.New(velixerr.CodeUnauthorized, "bad key/sig size")
	}
	return nil
}

type rejectingSigs struct{}

func (rejectingSigs) VerifyEd25519(_, _, _ []byte) error {
	return velixerr.New(velixerr.CodeUnauthorized, "rejected")
}

type silentLog struct{}

func (silentLog) Info(context.Context, string, ...any)  {}
func (silentLog) Warn(context.Context, string, ...any)  {}
func (silentLog) Error(context.Context, string, ...any) {}
func (silentLog) With(...any) velixobs.Logger           { return silentLog{} }

type fakeCounter struct{ n atomic.Int64 }

func (c *fakeCounter) Inc()         { c.n.Add(1) }
func (c *fakeCounter) Add(d float64) { c.n.Add(int64(d)) }

type fakeHistogram struct{}

func (fakeHistogram) Observe(float64) {}

func newHandlers(t *testing.T) (*IdentityHandlers, *fakeAccounts, *fakeDevices, *fakePrekeys) {
	t.Helper()
	accs := newFakeAccounts()
	devs := &fakeDevices{}
	pks := newFakePrekeys()
	sess := newFakeSessions()

	// In-test logger is an anonymous adapter — production wiring uses
	// velixobs.Logger directly. We avoid the interface here for brevity.
	h := &IdentityHandlers{
		tx:       &fakeTxRunner{},
		accounts: accs,
		devices:  devs,
		prekeys:  pks,
		sessions: sess,
		tokens:   fakeTokens{},
		clock:    fakeClock{t: time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)},
		ids:      &fakeIDs{},
		hasher:   fakeHasher{},
		sigs:     acceptingSigs{},
		log:      nil, // skeleton tests don't exercise the logger
		metrics: &Metrics{
			AccountsCreated:     &fakeCounter{},
			DevicesPaired:       &fakeCounter{},
			PrekeysPublished:    &fakeCounter{},
			PrekeyConsumed:      &fakeCounter{},
			SignInLatencyMillis: fakeHistogram{},
		},
	}
	return h, accs, devs, pks
}

// ----- Tests ---------------------------------------------------------------

func TestCreateAccount_HappyPath(t *testing.T) {
	h, accs, devs, _ := newHandlers(t)
	now := time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC)
	req := &CreateAccountRequest{
		IdempotencyKey:       "k1",
		IdentityPublicKey:    make([]byte, 32),
		DevicePublicKey:      make([]byte, 32),
		AttestationSignature: make([]byte, 64),
		SignedAt:             now,
		Handle:               "alice",
		DeviceName:           "iphone-14",
		DevicePlatform:       "ios",
		Locale:               "en",
	}
	resp, err := h.CreateAccount(context.Background(), req)
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if resp.Account.ID == "" || resp.Device.ID == "" {
		t.Fatal("ids must be set")
	}
	if len(accs.accounts) != 1 || len(devs.devices) != 1 {
		t.Fatalf("expected 1 account + 1 device; got %d/%d", len(accs.accounts), len(devs.devices))
	}
}

func TestCreateAccount_RejectsBadSignature(t *testing.T) {
	h, _, _, _ := newHandlers(t)
	h.sigs = rejectingSigs{}
	req := &CreateAccountRequest{
		IdempotencyKey:       "k1",
		IdentityPublicKey:    make([]byte, 32),
		DevicePublicKey:      make([]byte, 32),
		AttestationSignature: make([]byte, 64),
		SignedAt:             time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC),
	}
	_, err := h.CreateAccount(context.Background(), req)
	if err == nil {
		t.Fatal("expected error from rejected signature")
	}
	if got := velixerr.CodeOf(err); got != velixerr.CodeUnauthorized {
		t.Fatalf("got %q, want unauthenticated", got)
	}
}

func TestCreateAccount_RejectsBadKeySize(t *testing.T) {
	h, _, _, _ := newHandlers(t)
	cases := []struct {
		name string
		req  *CreateAccountRequest
	}{
		{"identity-too-short", &CreateAccountRequest{
			IdempotencyKey: "k1",
			IdentityPublicKey: make([]byte, 31),
			DevicePublicKey: make([]byte, 32),
			AttestationSignature: make([]byte, 64),
			SignedAt: time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC),
		}},
		{"sig-too-short", &CreateAccountRequest{
			IdempotencyKey: "k1",
			IdentityPublicKey: make([]byte, 32),
			DevicePublicKey: make([]byte, 32),
			AttestationSignature: make([]byte, 60),
			SignedAt: time.Date(2026, 5, 28, 12, 0, 0, 0, time.UTC),
		}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := h.CreateAccount(context.Background(), c.req)
			if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
				t.Fatalf("got %q, want invalid", got)
			}
		})
	}
}

func TestCreateAccount_RejectsStaleTimestamp(t *testing.T) {
	h, _, _, _ := newHandlers(t)
	stale := h.clock.Now().Add(-10 * time.Minute)
	_, err := h.CreateAccount(context.Background(), &CreateAccountRequest{
		IdempotencyKey: "k1",
		IdentityPublicKey: make([]byte, 32),
		DevicePublicKey: make([]byte, 32),
		AttestationSignature: make([]byte, 64),
		SignedAt: stale,
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeInvalid {
		t.Fatalf("got %q, want invalid", got)
	}
}

func TestPublishPrekeys_RequiresPrincipal(t *testing.T) {
	h, _, _, _ := newHandlers(t)
	_, err := h.PublishPrekeys(context.Background(), &PublishPrekeysRequest{
		SignedPrekey:          make([]byte, 32),
		SignedPrekeySignature: make([]byte, 64),
		SignedAt:              h.clock.Now(),
	})
	if got := velixerr.CodeOf(err); got != velixerr.CodeUnauthorized {
		t.Fatalf("got %q, want unauthenticated", got)
	}
}

func TestPublishPrekeys_HappyPath(t *testing.T) {
	h, _, _, pks := newHandlers(t)
	pks.idPub["acc1"] = make([]byte, 32)
	ctx := velixctx.WithPrincipal(context.Background(), "acc1", "dev1")
	otpks := [][]byte{make([]byte, 32), make([]byte, 32), make([]byte, 32)}
	_, err := h.PublishPrekeys(ctx, &PublishPrekeysRequest{
		SignedPrekey:          make([]byte, 32),
		SignedPrekeySignature: make([]byte, 64),
		SignedAt:              h.clock.Now(),
		OneTimePrekeys:        otpks,
	})
	if err != nil {
		t.Fatalf("publish: %v", err)
	}
	if len(pks.otpks["acc1:dev1"]) != 3 {
		t.Fatalf("expected 3 OTPKs; got %d", len(pks.otpks["acc1:dev1"]))
	}
}

func TestFetchPrekeyBundle_HappyPath(t *testing.T) {
	h, _, _, pks := newHandlers(t)
	pks.idPub["acc1"] = make([]byte, 32)
	pks.signed["acc1:dev1"] = [2][]byte{make([]byte, 32), make([]byte, 64)}
	pks.otpks["acc1:dev1"] = [][]byte{make([]byte, 32)}

	bundle, err := h.FetchPrekeyBundle(context.Background(), &FetchPrekeyBundleRequest{
		AccountID: "acc1", DeviceID: "dev1",
	})
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if bundle.OneTimePrekey == nil {
		t.Fatal("expected one-time prekey to be returned")
	}
}
