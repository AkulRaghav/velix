package adapters

import (
	"context"

	"github.com/velix/backend/pkg/velixauth"
	"github.com/velix/backend/services/identity/internal/tokens"
)

// BearerVerifier adapts the token Issuer's access-token verification to the
// velixauth.Verifier interface consumed by the gRPC auth interceptor.
type BearerVerifier struct {
	issuer *tokens.Issuer
}

func NewBearerVerifier(issuer *tokens.Issuer) *BearerVerifier {
	return &BearerVerifier{issuer: issuer}
}

func (b *BearerVerifier) Verify(ctx context.Context, bearer string) (velixauth.Principal, error) {
	accountID, deviceID, expiresAt, err := b.issuer.Verify(ctx, bearer)
	if err != nil {
		return velixauth.Principal{}, err
	}
	return velixauth.Principal{
		AccountID: accountID,
		DeviceID:  deviceID,
		ExpiresAt: expiresAt,
	}, nil
}

var _ velixauth.Verifier = (*BearerVerifier)(nil)
