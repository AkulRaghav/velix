// Package velixhealth serves the liveness, readiness, and metrics endpoints
// that every Velix service exposes on its health port (default :8081).
//
// The Helm chart wires:
//   livenessProbe  -> GET /healthz   (process is up)
//   readinessProbe -> GET /readyz    (dependencies reachable)
//   scrape         -> GET /metrics   (Prometheus exposition)
//
// Readiness runs each registered ReadinessCheck with a short timeout; if any
// fails the endpoint returns 503 so Kubernetes stops routing traffic.
package velixhealth

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// ReadinessCheck reports whether a dependency is reachable. Implementations
// must respect the context deadline (e.g. pool.Ping(ctx)).
type ReadinessCheck struct {
	Name  string
	Check func(ctx context.Context) error
}

// Server is the health HTTP server.
type Server struct {
	mu       sync.RWMutex
	ready    bool
	checks   []ReadinessCheck
	metrics  http.Handler
	timeout  time.Duration
}

// New builds a health server. metricsHandler may be nil (then /metrics 404s).
func New(checks []ReadinessCheck, metricsHandler http.Handler) *Server {
	return &Server{
		checks:  checks,
		metrics: metricsHandler,
		timeout: 2 * time.Second,
	}
}

// SetReady marks the service ready (call once startup wiring completes).
func (s *Server) SetReady(ready bool) {
	s.mu.Lock()
	s.ready = ready
	s.mu.Unlock()
}

// Handler returns the http.Handler exposing /healthz, /readyz, /metrics.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/readyz", s.handleReadyz)
	if s.metrics != nil {
		mux.Handle("/metrics", s.metrics)
	}
	return mux
}

// ListenAndServe starts the health server on addr. Returns when the context
// is cancelled (graceful shutdown) or the server errors.
func (s *Server) ListenAndServe(ctx context.Context, addr string) error {
	srv := &http.Server{
		Addr:              addr,
		Handler:           s.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()
	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	case err := <-errCh:
		return err
	}
}

func (s *Server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (s *Server) handleReadyz(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	ready := s.ready
	checks := s.checks
	s.mu.RUnlock()

	if !ready {
		writeReadyz(w, http.StatusServiceUnavailable, "not_ready", "")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), s.timeout)
	defer cancel()
	for _, c := range checks {
		if err := c.Check(ctx); err != nil {
			writeReadyz(w, http.StatusServiceUnavailable, "dependency_down", c.Name)
			return
		}
	}
	writeReadyz(w, http.StatusOK, "ready", "")
}

func writeReadyz(w http.ResponseWriter, code int, status, failed string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if failed != "" {
		_, _ = fmt.Fprintf(w, `{"status":%q,"failed_check":%q}`, status, failed)
		return
	}
	_, _ = fmt.Fprintf(w, `{"status":%q}`, status)
}
