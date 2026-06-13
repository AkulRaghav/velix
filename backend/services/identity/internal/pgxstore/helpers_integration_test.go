//go:build integration

package pgxstore

import (
	"crypto/rand"
	"encoding/hex"
)

// randSuffix returns a short random hex string to keep integration-test rows
// unique across repeated runs against a persistent database.
func randSuffix() string {
	b := make([]byte, 4)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
