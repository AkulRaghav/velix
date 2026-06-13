// Package velixtoken verifies the HMAC-SHA256 access tokens minted by the
// identity service, exposed as a velixauth.Verifier so every service can
// enforce the AUTH_CLIENT posture with only the shared signing key.
//
// Token format (must match identity/internal/tokens):
//   base64url(payloadJSON) "." base64url(HMAC-SHA256(key, payloadJSON))
// where payloadJSON is {"acc":...,"did":...,"exp":unixSeconds}.
package velixtoken

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/velix/backend/pkg/velixauth"
)

// Verifier validates access tokens with the shared signing key.
type Verifier struct {
	key   []byte
	clock func() time.Time
}

// NewVerifier builds a Verifier from the shared signing key.
func NewVerifier(signingKey []byte) *Verifier {
	return &Verifier{key: signingKey, clock: func() time.Time { return time.Now().UTC() }}
}

type claims struct {
	AccountID string `json:"acc"`
	DeviceID  string `json:"did"`
	ExpiresAt int64  `json:"exp"`
}

var errInvalid = errors.New("invalid token")

// Verify implements velixauth.Verifier.
func (v *Verifier) Verify(_ context.Context, accessToken string) (velixauth.Principal, error) {
	parts := strings.Split(accessToken, ".")
	if len(parts) != 2 {
		return velixauth.Principal{}, errInvalid
	}
	b64 := base64.RawURLEncoding
	payload, err := b64.DecodeString(parts[0])
	if err != nil {
		return velixauth.Principal{}, errInvalid
	}
	sig, err := b64.DecodeString(parts[1])
	if err != nil {
		return velixauth.Principal{}, errInvalid
	}
	mac := hmac.New(sha256.New, v.key)
	mac.Write(payload)
	if !hmac.Equal(sig, mac.Sum(nil)) {
		return velixauth.Principal{}, errInvalid
	}
	var cl claims
	if err := json.Unmarshal(payload, &cl); err != nil {
		return velixauth.Principal{}, errInvalid
	}
	exp := time.Unix(cl.ExpiresAt, 0).UTC()
	if v.clock().After(exp) {
		return velixauth.Principal{}, velixauth.ErrExpired
	}
	return velixauth.Principal{
		AccountID: cl.AccountID,
		DeviceID:  cl.DeviceID,
		ExpiresAt: exp,
	}, nil
}

var _ velixauth.Verifier = (*Verifier)(nil)
