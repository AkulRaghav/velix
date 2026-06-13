// Package adapters provides production implementations of the identity
// handler's small dependency interfaces: Clock, IDGenerator, IdentityHasher,
// and SignatureVerifier. All cryptography uses the Go standard library
// (crypto/ed25519, crypto/sha256) — audited primitives, no custom schemes.
package adapters

import (
	"crypto/ed25519"
	"crypto/sha256"
	"time"

	"github.com/oklog/ulid/v2"
	cryptorand "crypto/rand"

	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/identity/internal/handlers"
)

// ----- Clock --------------------------------------------------------------

type SystemClock struct{}

func (SystemClock) Now() time.Time { return time.Now().UTC() }

// ----- IDGenerator --------------------------------------------------------

type ULIDGenerator struct{}

func NewULIDGenerator() *ULIDGenerator { return &ULIDGenerator{} }

func (ULIDGenerator) NewULID() (string, error) {
	id, err := ulid.New(ulid.Timestamp(time.Now().UTC()), cryptorand.Reader)
	if err != nil {
		return "", err
	}
	return id.String(), nil
}

// ----- IdentityHasher -----------------------------------------------------

// SHA256Hasher hashes identity public keys with SHA-256. The 32-byte digest
// keys the accounts.identity_pubkey_hash unique column.
type SHA256Hasher struct{}

func (SHA256Hasher) Hash(pubkey []byte) []byte {
	sum := sha256.Sum256(pubkey)
	return sum[:]
}

// ----- SignatureVerifier --------------------------------------------------

// Ed25519Verifier verifies attestation signatures using crypto/ed25519.
//
// The attestation message is sha256(device_pubkey || timestamp-bytes); the
// handler forwards the canonical concat and this verifier hashes it before
// verification, matching the client signing contract.
type Ed25519Verifier struct{}

func (Ed25519Verifier) VerifyEd25519(pubkey, message, sig []byte) error {
	if len(pubkey) != ed25519.PublicKeySize {
		return velixerr.New(velixerr.CodeUnauthorized, "bad public key size")
	}
	if len(sig) != ed25519.SignatureSize {
		return velixerr.New(velixerr.CodeUnauthorized, "bad signature size")
	}
	digest := sha256.Sum256(message)
	if !ed25519.Verify(ed25519.PublicKey(pubkey), digest[:], sig) {
		return velixerr.New(velixerr.CodeUnauthorized, "signature does not verify")
	}
	return nil
}

// Compile-time interface checks.
var (
	_ handlers.Clock             = SystemClock{}
	_ handlers.IDGenerator       = ULIDGenerator{}
	_ handlers.IdentityHasher    = SHA256Hasher{}
	_ handlers.SignatureVerifier = Ed25519Verifier{}
)
