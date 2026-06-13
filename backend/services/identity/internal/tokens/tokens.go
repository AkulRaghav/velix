// Package tokens implements handlers.TokenIssuer using HMAC-SHA256-signed
// opaque tokens. The signing key is supplied at construction (from Vault in
// production). Access tokens carry account/device/expiry claims; refresh
// tokens are random opaque strings whose SHA-256 hash is persisted.
package tokens

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"strings"
	"time"

	"github.com/velix/backend/pkg/velixerr"
	"github.com/velix/backend/services/identity/internal/handlers"
)

const (
	accessTokenTTL  = 15 * time.Minute
	refreshTokenTTL = 30 * 24 * time.Hour
)

// Issuer mints and verifies tokens.
type Issuer struct {
	key   []byte
	clock func() time.Time
}

// New builds an Issuer from a signing key (≥ 32 bytes recommended).
func New(signingKey []byte) *Issuer {
	return &Issuer{key: signingKey, clock: func() time.Time { return time.Now().UTC() }}
}

type claims struct {
	AccountID string `json:"acc"`
	DeviceID  string `json:"did"`
	ExpiresAt int64  `json:"exp"`
}

func (i *Issuer) sign(payload []byte) []byte {
	mac := hmac.New(sha256.New, i.key)
	mac.Write(payload)
	return mac.Sum(nil)
}

// Issue mints an access + refresh pair.
func (i *Issuer) Issue(
	_ context.Context, accountID, deviceID string,
) (handlers.TokenPair, []byte, error) {
	now := i.clock()
	accessExp := now.Add(accessTokenTTL)
	refreshExp := now.Add(refreshTokenTTL)

	cl := claims{AccountID: accountID, DeviceID: deviceID, ExpiresAt: accessExp.Unix()}
	payload, err := json.Marshal(cl)
	if err != nil {
		return handlers.TokenPair{}, nil, velixerr.Wrap(velixerr.CodeInternal, "marshal claims", err)
	}
	b64 := base64.RawURLEncoding
	access := b64.EncodeToString(payload) + "." + b64.EncodeToString(i.sign(payload))

	refreshRaw := make([]byte, 32)
	if _, err := rand.Read(refreshRaw); err != nil {
		return handlers.TokenPair{}, nil, velixerr.Wrap(velixerr.CodeInternal, "refresh entropy", err)
	}
	refresh := b64.EncodeToString(refreshRaw)

	return handlers.TokenPair{
		AccessToken:      access,
		RefreshToken:     refresh,
		AccessExpiresAt:  accessExp,
		RefreshExpiresAt: refreshExp,
	}, i.HashRefresh(refresh), nil
}

// Verify validates an access token's signature and expiry.
func (i *Issuer) Verify(
	_ context.Context, accessToken string,
) (string, string, time.Time, error) {
	parts := strings.Split(accessToken, ".")
	if len(parts) != 2 {
		return "", "", time.Time{}, velixerr.New(velixerr.CodeUnauthorized, "malformed token")
	}
	b64 := base64.RawURLEncoding
	payload, err := b64.DecodeString(parts[0])
	if err != nil {
		return "", "", time.Time{}, velixerr.New(velixerr.CodeUnauthorized, "bad token payload")
	}
	sig, err := b64.DecodeString(parts[1])
	if err != nil {
		return "", "", time.Time{}, velixerr.New(velixerr.CodeUnauthorized, "bad token signature")
	}
	if !hmac.Equal(sig, i.sign(payload)) {
		return "", "", time.Time{}, velixerr.New(velixerr.CodeUnauthorized, "token signature invalid")
	}
	var cl claims
	if err := json.Unmarshal(payload, &cl); err != nil {
		return "", "", time.Time{}, velixerr.New(velixerr.CodeUnauthorized, "bad claims")
	}
	exp := time.Unix(cl.ExpiresAt, 0).UTC()
	if i.clock().After(exp) {
		return "", "", time.Time{}, velixerr.New(velixerr.CodeUnauthorized, "token expired")
	}
	return cl.AccountID, cl.DeviceID, exp, nil
}

// HashRefresh returns the SHA-256 of the refresh token for persistence.
func (i *Issuer) HashRefresh(refresh string) []byte {
	sum := sha256.Sum256([]byte(refresh))
	return sum[:]
}

var _ handlers.TokenIssuer = (*Issuer)(nil)
