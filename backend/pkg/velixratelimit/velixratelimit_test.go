package velixratelimit

import (
	"testing"
	"time"
)

func TestAllow_UnderLimit(t *testing.T) {
	lim := NewInMemory(Config{Capacity: 5, Window: time.Second})
	for i := 0; i < 5; i++ {
		if !lim.Allow("user:1") {
			t.Fatalf("request %d should be allowed", i+1)
		}
	}
}

func TestAllow_OverLimit(t *testing.T) {
	lim := NewInMemory(Config{Capacity: 3, Window: time.Minute})
	for i := 0; i < 3; i++ {
		lim.Allow("user:1")
	}
	if lim.Allow("user:1") {
		t.Fatal("4th request should be denied")
	}
}

func TestAllow_RefillsAfterWindow(t *testing.T) {
	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	lim := NewInMemory(Config{Capacity: 2, Window: time.Second})
	lim.now = func() time.Time { return now }

	lim.Allow("k")
	lim.Allow("k")
	if lim.Allow("k") {
		t.Fatal("should be denied before window")
	}

	// Advance past the window
	now = now.Add(2 * time.Second)
	if !lim.Allow("k") {
		t.Fatal("should be allowed after window refill")
	}
}

func TestAllow_IndependentKeys(t *testing.T) {
	lim := NewInMemory(Config{Capacity: 1, Window: time.Second})
	if !lim.Allow("a") {
		t.Fatal("key a should be allowed")
	}
	if !lim.Allow("b") {
		t.Fatal("key b should be allowed (independent)")
	}
	if lim.Allow("a") {
		t.Fatal("key a should be denied (exhausted)")
	}
}

func TestRemaining(t *testing.T) {
	lim := NewInMemory(Config{Capacity: 10, Window: time.Minute})
	if r := lim.Remaining("new"); r != 10 {
		t.Fatalf("new key should have full capacity, got %d", r)
	}
	lim.Allow("x")
	lim.Allow("x")
	lim.Allow("x")
	if r := lim.Remaining("x"); r != 7 {
		t.Fatalf("after 3 requests, remaining should be 7, got %d", r)
	}
}
