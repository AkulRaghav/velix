// Package velixobsslog is a concrete velixobs implementation.
//
// Logging is backed by log/slog with the velixobs PII-key filter applied to
// every record. Metrics use lightweight atomic counters/histograms/gauges so
// services build and run without a metrics backend; the same surface is later
// swapped for a Prometheus-backed Meter without touching handlers.
package velixobsslog

import (
	"context"
	"log/slog"
	"sync"
	"sync/atomic"

	"github.com/velix/backend/pkg/velixobs"
)

// ----- Logger -------------------------------------------------------------

// Logger adapts log/slog to velixobs.Logger and applies the PII filter.
type Logger struct {
	l    *slog.Logger
	base []any
}

// NewLogger builds a Logger from a slog.Logger.
func NewLogger(l *slog.Logger) *Logger { return &Logger{l: l} }

func (g *Logger) merged(kv []any) []any {
	all := make([]any, 0, len(g.base)+len(kv))
	all = append(all, g.base...)
	all = append(all, kv...)
	return velixobs.Filter(all)
}

func (g *Logger) Info(ctx context.Context, msg string, kv ...any) {
	g.l.InfoContext(ctx, msg, g.merged(kv)...)
}
func (g *Logger) Warn(ctx context.Context, msg string, kv ...any) {
	g.l.WarnContext(ctx, msg, g.merged(kv)...)
}
func (g *Logger) Error(ctx context.Context, msg string, kv ...any) {
	g.l.ErrorContext(ctx, msg, g.merged(kv)...)
}
func (g *Logger) With(kv ...any) velixobs.Logger {
	next := make([]any, 0, len(g.base)+len(kv))
	next = append(next, g.base...)
	next = append(next, kv...)
	return &Logger{l: g.l, base: next}
}

// ----- Metrics ------------------------------------------------------------

type counter struct{ n atomic.Int64 }

func (c *counter) Inc()            { c.n.Add(1) }
func (c *counter) Add(d float64)   { c.n.Add(int64(d)) }
func (c *counter) Value() int64    { return c.n.Load() }

type histogram struct {
	mu    sync.Mutex
	count int64
	sum   float64
}

func (h *histogram) Observe(v float64) {
	h.mu.Lock()
	h.count++
	h.sum += v
	h.mu.Unlock()
}

type gauge struct{ v atomic.Int64 }

func (g *gauge) Set(v float64)  { g.v.Store(int64(v)) }
func (g *gauge) Inc()           { g.v.Add(1) }
func (g *gauge) Dec()           { g.v.Add(-1) }
func (g *gauge) Add(d float64)  { g.v.Add(int64(d)) }

// Meter is an in-process metrics factory satisfying velixobs.Meter.
type Meter struct {
	mu         sync.Mutex
	counters   map[string]*counter
	histograms map[string]*histogram
	gauges     map[string]*gauge
}

func NewMeter() *Meter {
	return &Meter{
		counters:   map[string]*counter{},
		histograms: map[string]*histogram{},
		gauges:     map[string]*gauge{},
	}
}

func (m *Meter) Counter(name string, _ ...string) velixobs.Counter {
	m.mu.Lock()
	defer m.mu.Unlock()
	if c, ok := m.counters[name]; ok {
		return c
	}
	c := &counter{}
	m.counters[name] = c
	return c
}

func (m *Meter) Histogram(name string, _ ...string) velixobs.Histogram {
	m.mu.Lock()
	defer m.mu.Unlock()
	if h, ok := m.histograms[name]; ok {
		return h
	}
	h := &histogram{}
	m.histograms[name] = h
	return h
}

func (m *Meter) Gauge(name string, _ ...string) velixobs.Gauge {
	m.mu.Lock()
	defer m.mu.Unlock()
	if g, ok := m.gauges[name]; ok {
		return g
	}
	g := &gauge{}
	m.gauges[name] = g
	return g
}

// Compile-time interface checks.
var (
	_ velixobs.Logger    = (*Logger)(nil)
	_ velixobs.Meter     = (*Meter)(nil)
	_ velixobs.Counter   = (*counter)(nil)
	_ velixobs.Histogram = (*histogram)(nil)
	_ velixobs.Gauge     = (*gauge)(nil)
)
