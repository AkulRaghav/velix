// Command alpha-server runs the Velix Alpha HTTP/JSON server.
//
// One binary. Standard library only. In-memory state with JSON snapshot
// on graceful shutdown.
//
// Run:
//
//	go run ./cmd/alpha-server
//
// Override addr or state path:
//
//	VELIX_ADDR=:9000 VELIX_STATE_PATH=./state.json go run ./cmd/alpha-server
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/velix/backend/alpha/internal/api"
	"github.com/velix/backend/alpha/internal/store"
)

func main() {
	addr := envOr("VELIX_ADDR", ":8080")
	statePath := envOr("VELIX_STATE_PATH", "velix-alpha-state.json")

	logger := log.New(os.Stdout, "[alpha] ", log.LstdFlags|log.Lmicroseconds)

	st := store.New()
	if err := st.Load(statePath); err != nil {
		logger.Fatalf("load state: %v", err)
	}
	logger.Printf("loaded state from %s", statePath)

	srv := &api.Server{Store: st, Logger: logger}

	hs := &http.Server{
		Addr:              addr,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	go func() {
		logger.Printf("listening on %s", addr)
		if err := hs.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Fatalf("http: %v", err)
		}
	}()

	<-ctx.Done()
	logger.Printf("shutting down")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()

	if err := hs.Shutdown(shutdownCtx); err != nil {
		logger.Printf("shutdown: %v", err)
	}
	if err := st.Save(statePath); err != nil {
		logger.Printf("save state: %v", err)
	} else {
		logger.Printf("saved state to %s", statePath)
	}
}

func envOr(k, def string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return def
}
