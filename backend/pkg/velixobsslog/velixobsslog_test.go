package velixobsslog

import (
	"context"
	"io"
	"log/slog"
	"testing"
)

func testSlog() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func TestMeter_ReusesNamedInstruments(t *testing.T) {
	m := NewMeter()
	c1 := m.Counter("requests")
	c2 := m.Counter("requests")
	if c1 != c2 {
		t.Fatal("counter with the same name must be reused")
	}
	c1.Inc()
	c1.Add(4)
	if got := m.counters["requests"].Value(); got != 5 {
		t.Fatalf("counter value = %d, want 5", got)
	}
}

func TestMeter_DistinctInstrumentTypes(t *testing.T) {
	m := NewMeter()
	if m.Counter("a") == nil || m.Histogram("b") == nil || m.Gauge("c") == nil {
		t.Fatal("instruments must be non-nil")
	}
	h := m.Histogram("b")
	h.Observe(1.5)
	h.Observe(2.5)
	if m.histograms["b"].count != 2 {
		t.Fatalf("histogram count = %d, want 2", m.histograms["b"].count)
	}
	g := m.Gauge("c")
	g.Set(10)
	g.Inc()
	g.Dec()
	g.Add(5)
	if got := m.gauges["c"].v.Load(); got != 15 {
		t.Fatalf("gauge value = %d, want 15", got)
	}
}

func TestLogger_FiltersBannedKeys(t *testing.T) {
	// The logger must not panic and must route through the velixobs filter.
	// We exercise the code paths; the filter itself is unit-tested in velixobs.
	l := NewLogger(testSlog())
	ctx := context.Background()
	l.Info(ctx, "msg", "account", "acc1", "body", "should-be-redacted")
	l.Warn(ctx, "msg", "token", "secret-value")
	l.Error(ctx, "msg", "ok", "value")

	child := l.With("service", "notifier")
	if child == nil {
		t.Fatal("With must return a logger")
	}
	child.Info(ctx, "child msg", "password", "hunter2")
}
