// Package adapters provides the push service Clock + IDGenerator.
package adapters

import (
	cryptorand "crypto/rand"
	"time"

	"github.com/oklog/ulid/v2"

	"github.com/velix/backend/services/push/internal/handlers"
)

type SystemClock struct{}

func (SystemClock) Now() time.Time { return time.Now().UTC() }

type ULIDGenerator struct{}

func NewULIDGenerator() *ULIDGenerator { return &ULIDGenerator{} }

func (ULIDGenerator) NewULID() (string, error) {
	id, err := ulid.New(ulid.Timestamp(time.Now().UTC()), cryptorand.Reader)
	if err != nil {
		return "", err
	}
	return id.String(), nil
}

var (
	_ handlers.Clock       = SystemClock{}
	_ handlers.IDGenerator = ULIDGenerator{}
)
