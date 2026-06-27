// Package velixratelimit provides a token-bucket rate limiter seam for
// gRPC services. It is designed to be plugged into the auth interceptor
// chain, enforcing per-account or per-IP request budgets.
//
// The default implementation uses an in-memory concurrent map. Production
// deployments swap this for a Redis-backed implementation via the Limiter
// interface.
package velixratelimit

import (
	"sync"
	"time"
)

// Limiter is the rate-limiting seam. Implementations must be safe for
// concurrent use.
type Limiter interface {
	// Allow checks whether the given key has budget remaining. It returns
	// true if the request is allowed, false if rate-limited.
	// The key is typically "account:<id>" or "ip:<addr>".
	Allow(key string) bool

	// Remaining returns the number of tokens left for the given key.
	Remaining(key string) int
}

// Config defines the rate limit parameters.
type Config struct {
	// Maximum number of requests in the window.
	Capacity int

	// Window duration. Tokens refill fully after this period.
	Window time.Duration
}

// bucket tracks a single key's token state.
type bucket struct {
	tokens    int
	lastReset time.Time
}

// InMemoryLimiter is a thread-safe, in-process token bucket limiter.
// Suitable for single-instance deployments and tests.
type InMemoryLimiter struct {
	mu      sync.Mutex
	buckets map[string]*bucket
	cfg     Config
	now     func() time.Time // injectable for testing
}

// NewInMemory creates a rate limiter with the given configuration.
func NewInMemory(cfg Config) *InMemoryLimiter {
	return &InMemoryLimiter{
		buckets: make(map[string]*bucket),
		cfg:     cfg,
		now:     time.Now,
	}
}

// Allow implements Limiter.
func (l *InMemoryLimiter) Allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	b, exists := l.buckets[key]

	if !exists {
		l.buckets[key] = &bucket{
			tokens:    l.cfg.Capacity - 1,
			lastReset: now,
		}
		return true
	}

	// Refill if window has elapsed
	if now.Sub(b.lastReset) >= l.cfg.Window {
		b.tokens = l.cfg.Capacity
		b.lastReset = now
	}

	if b.tokens > 0 {
		b.tokens--
		return true
	}

	return false
}

// Remaining implements Limiter.
func (l *InMemoryLimiter) Remaining(key string) int {
	l.mu.Lock()
	defer l.mu.Unlock()

	b, exists := l.buckets[key]
	if !exists {
		return l.cfg.Capacity
	}

	now := l.now()
	if now.Sub(b.lastReset) >= l.cfg.Window {
		return l.cfg.Capacity
	}

	return b.tokens
}

// DefaultPerAccount returns a standard config for per-account limits:
// 60 requests per minute.
func DefaultPerAccount() Config {
	return Config{Capacity: 60, Window: time.Minute}
}

// DefaultPerIP returns a standard config for per-IP limits:
// 120 requests per minute.
func DefaultPerIP() Config {
	return Config{Capacity: 120, Window: time.Minute}
}
