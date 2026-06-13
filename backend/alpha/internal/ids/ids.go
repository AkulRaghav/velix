// Package ids generates short, sortable, opaque identifiers for the alpha.
//
// We use a 14-byte time-prefixed random id encoded with Crockford-base32-ish.
// Real production uses ULIDs; alpha-grade is fine here.
package ids

import (
	"crypto/rand"
	"strings"
	"time"
)

const alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

// New returns a new id like "01H8E3KX...".
func New() string {
	now := uint64(time.Now().UnixMilli())
	tsBytes := []byte{
		byte(now >> 40), byte(now >> 32), byte(now >> 24),
		byte(now >> 16), byte(now >> 8), byte(now),
	}
	rnd := make([]byte, 10)
	if _, err := rand.Read(rnd); err != nil {
		// fallback: time-only id; alpha-grade tolerable
		nano := uint64(time.Now().UnixNano())
		for i := range rnd {
			rnd[i] = byte(nano >> uint(i*7))
		}
	}
	all := append(tsBytes, rnd...)
	return encodeBase32(all)
}

func encodeBase32(b []byte) string {
	var sb strings.Builder
	sb.Grow((len(b) * 8) / 5)
	var buf, bits uint64
	for _, v := range b {
		buf = (buf << 8) | uint64(v)
		bits += 8
		for bits >= 5 {
			bits -= 5
			sb.WriteByte(alphabet[(buf>>bits)&0x1f])
		}
	}
	if bits > 0 {
		sb.WriteByte(alphabet[(buf<<(5-bits))&0x1f])
	}
	return sb.String()
}

// NewToken returns an opaque, URL-safe random token (32 bytes encoded).
func NewToken() string {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		// fallback
		nano := uint64(time.Now().UnixNano())
		for i := range b {
			b[i] = byte(nano >> uint(i%8))
		}
	}
	return encodeBase32(b[:])
}
