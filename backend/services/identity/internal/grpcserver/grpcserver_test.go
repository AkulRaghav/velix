package grpcserver

import (
	"context"
	"net"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"
	"google.golang.org/protobuf/types/known/timestamppb"

	identityv1 "github.com/velix/backend/proto/gen/go/velix/identity/v1"
	"github.com/velix/backend/services/identity/internal/adapters"
	"github.com/velix/backend/services/identity/internal/handlers"
	"github.com/velix/backend/pkg/velixsql"
)

// ----- In-memory fakes ----------------------------------------------------

type memTx struct{}

func (memTx) Exec(context.Context, string, ...any) (velixsql.CommandTag, error) {
	return memTag{}, nil
}
func (memTx) Query(context.Context, string, ...any) (velixsql.Rows, error) {
	return nil, velixsql.ErrNoRows
}
func (memTx) QueryRow(context.Context, string, ...any) velixsql.Row { return memRow{} }

type memTag struct{}

func (memTag) RowsAffected() int64 { return 0 }

type memRow struct{}

func (memRow) Scan(...any) error { return velixsql.ErrNoRows }

type memTxRunner struct{}

func (memTxRunner) Run(ctx context.Context, _ velixsql.Isolation, fn func(context.Context, velixsql.Tx) error) error {
	return fn(ctx, memTx{})
}

type memAccounts struct{ n int }

func (m *memAccounts) InsertAccount(context.Context, velixsql.Tx, handlers.Account, []byte) error {
	m.n++
	return nil
}
func (memAccounts) GetAccountByID(context.Context, velixsql.Tx, string) (handlers.Account, error) {
	return handlers.Account{}, nil
}
func (memAccounts) UpdateLocale(context.Context, velixsql.Tx, string, string) error { return nil }
func (memAccounts) ReserveHandle(context.Context, velixsql.Tx, string, string) error { return nil }
func (memAccounts) UpdateProfile(context.Context, velixsql.Tx, string, string, string) (handlers.Account, error) {
	return handlers.Account{}, nil
}

type memDevices struct{}

func (memDevices) InsertDevice(context.Context, velixsql.Tx, handlers.Device, []byte, []byte) error {
	return nil
}
func (memDevices) GetDeviceByID(context.Context, velixsql.Tx, string) (handlers.Device, error) {
	return handlers.Device{}, nil
}
func (memDevices) ListDevicesByAccount(context.Context, velixsql.Tx, string) ([]handlers.Device, error) {
	return nil, nil
}
func (memDevices) RevokeDevice(context.Context, velixsql.Tx, string, string) error { return nil }

type memPrekeys struct{}

func (memPrekeys) UpsertSignedPrekey(context.Context, velixsql.Tx, string, string, []byte, []byte, time.Time) error {
	return nil
}
func (memPrekeys) InsertOneTimePrekeys(context.Context, velixsql.Tx, string, string, [][]byte) error {
	return nil
}
func (memPrekeys) ConsumeOneTimePrekey(context.Context, velixsql.Tx, string, string) ([]byte, error) {
	return nil, nil
}
func (memPrekeys) GetSignedPrekey(context.Context, velixsql.Tx, string, string) ([]byte, []byte, error) {
	return make([]byte, 32), make([]byte, 64), nil
}
func (memPrekeys) GetIdentityPublicKey(context.Context, velixsql.Tx, string) ([]byte, error) {
	return make([]byte, 32), nil
}

type memSessions struct{}

func (memSessions) InsertSession(context.Context, velixsql.Tx, string, string, string, []byte, time.Time) error {
	return nil
}
func (memSessions) RevokeSession(context.Context, velixsql.Tx, string) error { return nil }
func (memSessions) GetActiveSessionByRefreshHash(context.Context, velixsql.Tx, []byte) (string, string, string, time.Time, error) {
	return "", "", "", time.Time{}, velixsql.ErrNoRows
}
func (memSessions) RotateRefreshToken(context.Context, velixsql.Tx, string, []byte, time.Time) error {
	return nil
}

// acceptingSigs accepts any well-formed key/sig so CreateAccount can succeed.
type acceptingSigs struct{}

func (acceptingSigs) VerifyEd25519(pubkey, _, sig []byte) error {
	if len(pubkey) != 32 || len(sig) != 64 {
		return errBadSize
	}
	return nil
}

var errBadSize = status.Error(codes.Unauthenticated, "bad size")

type fakeCounter struct{}

func (fakeCounter) Inc()        {}
func (fakeCounter) Add(float64) {}

type fakeHist struct{}

func (fakeHist) Observe(float64) {}

func newTestHandlers() *handlers.IdentityHandlers {
	return handlers.NewHandlers(handlers.Deps{
		TxRunner: memTxRunner{},
		Accounts: &memAccounts{},
		Devices:  memDevices{},
		Prekeys:  memPrekeys{},
		Sessions: memSessions{},
		Tokens:   tokenStub{},
		Clock:    adapters.SystemClock{},
		IDs:      adapters.NewULIDGenerator(),
		Hasher:   adapters.SHA256Hasher{},
		Sigs:     acceptingSigs{},
		Log:      nil,
		Metrics: &handlers.Metrics{
			AccountsCreated:  fakeCounter{},
			DevicesPaired:    fakeCounter{},
			PrekeysPublished: fakeCounter{},
			PrekeyConsumed:   fakeCounter{},
			SignInLatencyMillis: fakeHist{},
		},
	})
}

type tokenStub struct{}

func (tokenStub) Issue(context.Context, string, string) (handlers.TokenPair, []byte, error) {
	return handlers.TokenPair{
		AccessToken: "a", RefreshToken: "r",
		AccessExpiresAt: time.Now().Add(time.Hour), RefreshExpiresAt: time.Now().Add(24 * time.Hour),
	}, []byte{1}, nil
}
func (tokenStub) Verify(context.Context, string) (string, string, time.Time, error) {
	return "", "", time.Time{}, nil
}
func (tokenStub) HashRefresh(string) []byte { return []byte{1} }

func dialBufconn(t *testing.T) identityv1.IdentityServiceClient {
	t.Helper()
	lis := bufconn.Listen(1024 * 1024)
	srv := grpc.NewServer()
	identityv1.RegisterIdentityServiceServer(srv, New(newTestHandlers()))
	go func() { _ = srv.Serve(lis) }()
	t.Cleanup(srv.Stop)

	conn, err := grpc.NewClient(
		"passthrough:///bufnet",
		grpc.WithContextDialer(func(ctx context.Context, _ string) (net.Conn, error) {
			return lis.DialContext(ctx)
		}),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	return identityv1.NewIdentityServiceClient(conn)
}

// ----- Tests --------------------------------------------------------------

func TestCreateAccount_OverGRPC(t *testing.T) {
	client := dialBufconn(t)
	resp, err := client.CreateAccount(context.Background(), &identityv1.CreateAccountRequest{
		IdempotencyKey:       "k1",
		IdentityPublicKey:    make([]byte, 32),
		DevicePublicKey:      make([]byte, 32),
		AttestationSignature: make([]byte, 64),
		SignedAt:             timestamppb.New(time.Now()),
		Handle:               "alice",
		Locale:               "en",
	})
	if err != nil {
		t.Fatalf("CreateAccount rpc: %v", err)
	}
	if resp.GetAccount().GetId() == "" || resp.GetTokens().GetAccessToken() == "" {
		t.Fatalf("incomplete response: %+v", resp)
	}
}

func TestCreateAccount_OverGRPC_BadKeySize(t *testing.T) {
	client := dialBufconn(t)
	_, err := client.CreateAccount(context.Background(), &identityv1.CreateAccountRequest{
		IdempotencyKey:       "k1",
		IdentityPublicKey:    make([]byte, 16), // wrong
		DevicePublicKey:      make([]byte, 32),
		AttestationSignature: make([]byte, 64),
		SignedAt:             timestamppb.New(time.Now()),
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("got %v, want InvalidArgument", status.Code(err))
	}
}

func TestFetchPrekeyBundle_OverGRPC(t *testing.T) {
	client := dialBufconn(t)
	resp, err := client.FetchPrekeyBundle(context.Background(), &identityv1.FetchPrekeyBundleRequest{
		AccountId: "acc1", DeviceId: "dev1",
	})
	if err != nil {
		t.Fatalf("FetchPrekeyBundle rpc: %v", err)
	}
	if len(resp.GetSignedPrekey()) != 32 {
		t.Fatalf("signed prekey len = %d, want 32", len(resp.GetSignedPrekey()))
	}
}
