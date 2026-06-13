package tokens

import (
	"context"
	"testing"

	"github.com/velix/backend/pkg/velixerr"
)

func TestIssueAndVerify_RoundTrip(t *testing.T) {
	iss := New([]byte("test-signing-key-at-least-32-bytes-long!!"))
	pair, refreshHash, err := iss.Issue(context.Background(), "acc1", "dev1")
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	if pair.AccessToken == "" || pair.RefreshToken == "" {
		t.Fatal("tokens must be non-empty")
	}
	if len(refreshHash) != 32 {
		t.Fatalf("refresh hash len = %d, want 32", len(refreshHash))
	}

	acc, dev, _, err := iss.Verify(context.Background(), pair.AccessToken)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if acc != "acc1" || dev != "dev1" {
		t.Fatalf("claims mismatch: acc=%q dev=%q", acc, dev)
	}
}

func TestVerify_RejectsTamperedToken(t *testing.T) {
	iss := New([]byte("test-signing-key-at-least-32-bytes-long!!"))
	pair, _, err := iss.Issue(context.Background(), "acc1", "dev1")
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	tampered := pair.AccessToken + "x"
	_, _, _, err = iss.Verify(context.Background(), tampered)
	if got := velixerr.CodeOf(err); got != velixerr.CodeUnauthorized {
		t.Fatalf("got %q, want unauthenticated", got)
	}
}

func TestVerify_RejectsWrongKey(t *testing.T) {
	a := New([]byte("signing-key-AAAAAAAAAAAAAAAAAAAAAAAAAAAAA"))
	b := New([]byte("signing-key-BBBBBBBBBBBBBBBBBBBBBBBBBBBBB"))
	pair, _, err := a.Issue(context.Background(), "acc1", "dev1")
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	_, _, _, err = b.Verify(context.Background(), pair.AccessToken)
	if got := velixerr.CodeOf(err); got != velixerr.CodeUnauthorized {
		t.Fatalf("got %q, want unauthenticated", got)
	}
}

func TestHashRefresh_IsStable(t *testing.T) {
	iss := New([]byte("k"))
	h1 := iss.HashRefresh("token-abc")
	h2 := iss.HashRefresh("token-abc")
	if string(h1) != string(h2) {
		t.Fatal("hash must be deterministic")
	}
	if string(iss.HashRefresh("other")) == string(h1) {
		t.Fatal("different inputs must hash differently")
	}
}
