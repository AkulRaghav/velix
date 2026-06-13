package velixhealth

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func do(t *testing.T, h http.Handler, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	h.ServeHTTP(rec, req)
	return rec
}

func TestHealthz_AlwaysOK(t *testing.T) {
	s := New(nil, nil)
	rec := do(t, s.Handler(), "/healthz")
	if rec.Code != http.StatusOK {
		t.Fatalf("healthz code = %d, want 200", rec.Code)
	}
}

func TestReadyz_NotReadyUntilFlagged(t *testing.T) {
	s := New(nil, nil)
	if rec := do(t, s.Handler(), "/readyz"); rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("readyz before ready = %d, want 503", rec.Code)
	}
	s.SetReady(true)
	if rec := do(t, s.Handler(), "/readyz"); rec.Code != http.StatusOK {
		t.Fatalf("readyz after ready = %d, want 200", rec.Code)
	}
}

func TestReadyz_FailsWhenDependencyDown(t *testing.T) {
	s := New([]ReadinessCheck{
		{Name: "postgres", Check: func(context.Context) error { return nil }},
		{Name: "nats", Check: func(context.Context) error { return errors.New("down") }},
	}, nil)
	s.SetReady(true)
	rec := do(t, s.Handler(), "/readyz")
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("readyz with down dep = %d, want 503", rec.Code)
	}
	if body := rec.Body.String(); body == "" || !contains(body, "nats") {
		t.Fatalf("expected failed_check nats in body; got %q", body)
	}
}

func TestReadyz_PassesWhenAllUp(t *testing.T) {
	s := New([]ReadinessCheck{
		{Name: "postgres", Check: func(context.Context) error { return nil }},
	}, nil)
	s.SetReady(true)
	if rec := do(t, s.Handler(), "/readyz"); rec.Code != http.StatusOK {
		t.Fatalf("readyz all up = %d, want 200", rec.Code)
	}
}

func TestMetrics_ServedWhenHandlerSet(t *testing.T) {
	mh := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("# metrics"))
	})
	s := New(nil, mh)
	if rec := do(t, s.Handler(), "/metrics"); rec.Code != http.StatusOK {
		t.Fatalf("metrics code = %d, want 200", rec.Code)
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
