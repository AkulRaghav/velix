package velixtoken

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"testing"
	"time"

	"github.com/velix/backend/pkg/velixauth"
)

// mintToken reproduces the identity service's token format so the test
// asserts cross-service compatibility.
func mintToken(key []byte, acc, dev string, exp time.Time) string {
	payload, _ := json.Marshal(claims{AccountID: acc, DeviceID: dev, ExpiresAt: exp.Unix()})
	mac := hmac.New(sha256.New, key)
	mac.Write(payload)
	b64 := base64.RawURLEncoding
	return b64.EncodeToString(payload) + "." + b64.EncodeToString(mac.Sum(nil))
}

func TestVerify_AcceptsValidToken(t *testing.T) {
	key := []byte("shared-signing-key-at-least-32-bytes!!")
	v := NewVerifier(key)
	tok := mintToken(key, "acc1", "dev1", time.Now().Add(time.Hour))

	p, err := v.Verify(context.Background(), tok)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if p.AccountID != "acc1" || p.DeviceID != "dev1" {
		t.Fatalf("principal mismatch: %+v", p)
	}
}

func TestVerify_RejectsWrongKey(t *testing.T) {
	tok := mintToken([]byte("key-A-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"), "acc1", "dev1", time.Now().Add(time.Hour))
	v := NewVerifier([]byte("key-B-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"))
	if _, err := v.Verify(context.Background(), tok); err == nil {
		t.Fatal("expected error for wrong key")
	}
}

func TestVerify_RejectsExpired(t *testing.T) {
	key := []byte("shared-signing-key-at-least-32-bytes!!")
	v := NewVerifier(key)
	tok := mintToken(key, "acc1", "dev1", time.Now().Add(-time.Minute))
	_, err := v.Verify(context.Background(), tok)
	if err != velixauth.ErrExpired {
		t.Fatalf("got %v, want ErrExpired", err)
	}
}

func TestVerify_RejectsMalformed(t *testing.T) {
	v := NewVerifier([]byte("k"))
	for _, bad := range []string{"", "no-dot", "a.b.c", "@@@.###"} {
		if _, err := v.Verify(context.Background(), bad); err == nil {
			t.Fatalf("expected error for %q", bad)
		}
	}
}
