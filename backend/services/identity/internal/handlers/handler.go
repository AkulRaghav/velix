// Package handlers implements the IdentityService RPCs.
//
// Wires the proto contract in proto/velix/identity/v1/identity.proto.
// Constructed via NewHandlers in cmd/identity-server/main.go.
package handlers

import (
	"context"
	"time"

	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/pkg/velixobs"
	"github.com/velix/backend/pkg/velixsql"
)

// Deps is the explicit dependency record.
type Deps struct {
	TxRunner  velixsql.TxRunner
	Accounts  AccountStore
	Devices   DeviceStore
	Prekeys   PrekeyStore
	Sessions  SessionStore
	Tokens    TokenIssuer
	Clock     Clock
	IDs       IDGenerator
	Hasher    IdentityHasher
	Sigs      SignatureVerifier
	Log       velixobs.Logger
	Metrics   *Metrics
}

type IdentityHandlers struct {
	tx       velixsql.TxRunner
	accounts AccountStore
	devices  DeviceStore
	prekeys  PrekeyStore
	sessions SessionStore
	tokens   TokenIssuer
	clock    Clock
	ids      IDGenerator
	hasher   IdentityHasher
	sigs     SignatureVerifier
	log      velixobs.Logger
	metrics  *Metrics
}

func NewHandlers(d Deps) *IdentityHandlers {
	return &IdentityHandlers{
		tx:       d.TxRunner,
		accounts: d.Accounts,
		devices:  d.Devices,
		prekeys:  d.Prekeys,
		sessions: d.Sessions,
		tokens:   d.Tokens,
		clock:    d.Clock,
		ids:      d.IDs,
		hasher:   d.Hasher,
		sigs:     d.Sigs,
		log:      d.Log,
		metrics:  d.Metrics,
	}
}

// ----- Domain types --------------------------------------------------------

type Account struct {
	ID                 string
	IdentityPubkeyHash []byte
	Locale             string
	Status             string
	CreatedAt          time.Time
}

type Device struct {
	ID         string
	AccountID  string
	Name       string
	Platform   string
	PairedAt   time.Time
	LastSeenAt time.Time
	Status     string
}

type TokenPair struct {
	AccessToken        string
	RefreshToken       string
	AccessExpiresAt    time.Time
	RefreshExpiresAt   time.Time
}

type PrekeyBundle struct {
	IdentityPublicKey      []byte
	SignedPrekey           []byte
	SignedPrekeySignature  []byte
	OneTimePrekey          []byte // may be empty
}

// ----- Stores --------------------------------------------------------------

type AccountStore interface {
	InsertAccount(ctx context.Context, tx velixsql.Tx, a Account, identityPubkey []byte) error
	GetAccountByID(ctx context.Context, tx velixsql.Tx, id string) (Account, error)
	UpdateLocale(ctx context.Context, tx velixsql.Tx, id, locale string) error
	ReserveHandle(ctx context.Context, tx velixsql.Tx, accountID, handle string) error
	UpdateProfile(ctx context.Context, tx velixsql.Tx, accountID, displayNameHash, handle string) (Account, error)
}

type DeviceStore interface {
	InsertDevice(ctx context.Context, tx velixsql.Tx, d Device, devicePubkey, attestationSig []byte) error
	GetDeviceByID(ctx context.Context, tx velixsql.Tx, id string) (Device, error)
	ListDevicesByAccount(ctx context.Context, tx velixsql.Tx, accountID string) ([]Device, error)
	RevokeDevice(ctx context.Context, tx velixsql.Tx, deviceID, reason string) error
}

type PrekeyStore interface {
	UpsertSignedPrekey(ctx context.Context, tx velixsql.Tx, accountID, deviceID string, signedPrekey, signature []byte, signedAt time.Time) error
	InsertOneTimePrekeys(ctx context.Context, tx velixsql.Tx, accountID, deviceID string, prekeys [][]byte) error
	ConsumeOneTimePrekey(ctx context.Context, tx velixsql.Tx, accountID, deviceID string) ([]byte, error) // may return nil
	GetSignedPrekey(ctx context.Context, tx velixsql.Tx, accountID, deviceID string) ([]byte, []byte, error)
	GetIdentityPublicKey(ctx context.Context, tx velixsql.Tx, accountID string) ([]byte, error)
}

type SessionStore interface {
	InsertSession(ctx context.Context, tx velixsql.Tx, sessionID, accountID, deviceID string, refreshTokenHash []byte, expiresAt time.Time) error
	RevokeSession(ctx context.Context, tx velixsql.Tx, sessionID string) error
	GetActiveSessionByRefreshHash(ctx context.Context, tx velixsql.Tx, hash []byte) (sessionID, accountID, deviceID string, expiresAt time.Time, err error)
	RotateRefreshToken(ctx context.Context, tx velixsql.Tx, sessionID string, newHash []byte, newExpiresAt time.Time) error
}

// ----- Adapters ------------------------------------------------------------

type Clock interface {
	Now() time.Time
}

type IDGenerator interface {
	NewULID() (string, error)
}

type IdentityHasher interface {
	// HashIdentityPubkey returns a 32-byte BLAKE3 hash. Used as account_id
	// suffix and the unique key on accounts.identity_pubkey_hash.
	Hash(pubkey []byte) []byte
}

type SignatureVerifier interface {
	// VerifyEd25519 returns nil iff sig is a valid Ed25519 signature
	// over message under pubkey. Returns velixerr with CodeUnauthorized
	// otherwise.
	VerifyEd25519(pubkey, message, sig []byte) error
}

type TokenIssuer interface {
	// Issue mints a new access + refresh token pair. The refresh token is
	// returned in plaintext; only its hash is persisted.
	Issue(ctx context.Context, accountID, deviceID string) (TokenPair, []byte, error)
	// Verify validates an access token; returns the principal claims.
	Verify(ctx context.Context, accessToken string) (accountID, deviceID string, expiresAt time.Time, err error)
	// HashRefresh canonicalizes a refresh token to its persisted hash.
	HashRefresh(refresh string) []byte
}

// ----- Metrics -------------------------------------------------------------

type Metrics struct {
	AccountsCreated     velixobs.Counter
	DevicesPaired       velixobs.Counter
	PrekeysPublished    velixobs.Counter
	PrekeyConsumed      velixobs.Counter
	SignInLatencyMillis velixobs.Histogram
}

// ----- Helpers -------------------------------------------------------------

func errInvalid(msg string) error {
	return velixerr.New(velixerr.CodeInvalid, msg)
}
