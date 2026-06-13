// Command notifier-server runs the NotifierService.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"

	"google.golang.org/grpc"

	notifierv1 "github.com/velix/backend/proto/gen/go/velix/notifier/v1"
	"github.com/velix/backend/pkg/velixauth"
	"github.com/velix/backend/pkg/velixgrpcauth"
	"github.com/velix/backend/pkg/velixhealth"
	"github.com/velix/backend/pkg/velixnatsjs"
	"github.com/velix/backend/pkg/velixtoken"
	"github.com/velix/backend/pkg/velixobsslog"
	"github.com/velix/backend/pkg/velixsqlpgx"
	"github.com/velix/backend/services/notifier/internal/adapters"
	"github.com/velix/backend/services/notifier/internal/grpcserver"
	"github.com/velix/backend/services/notifier/internal/handlers"
	"github.com/velix/backend/services/notifier/internal/pgxstore"
)

type Config struct {
	Addr     string
	HealthAddr string
	DSN      string
	NATSURL  string
	LogLevel string
}

func loadConfig() Config {
	return Config{
		Addr:     env("VELIX_ADDR", ":8080"),
		HealthAddr: env("VELIX_HEALTH_ADDR", ":8081"),
		DSN:      env("VELIX_DSN", ""),
		NATSURL:  env("VELIX_NATS_URL", ""),
		LogLevel: env("VELIX_LOG_LEVEL", "info"),
	}
}

func env(k, def string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return def
}

// gitRevision is injected at build time via -ldflags "-X main.gitRevision=...".
var gitRevision = "dev"

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if err := run(ctx, loadConfig()); err != nil {
		fmt.Fprintln(os.Stderr, "notifier-server fatal:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, cfg Config) error {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	log := velixobsslog.NewLogger(logger)
	meter := velixobsslog.NewMeter()

	if cfg.DSN == "" {
		return errors.New("VELIX_DSN is required")
	}
	if cfg.NATSURL == "" {
		return errors.New("VELIX_NATS_URL is required")
	}

	pool, err := velixsqlpgx.Connect(ctx, cfg.DSN)
	if err != nil {
		return fmt.Errorf("pgx connect: %w", err)
	}
	defer pool.Close()

	pub, nc, err := velixnatsjs.Connect(ctx, cfg.NATSURL, "", nil)
	if err != nil {
		return err
	}
	defer nc.Close()

	h := handlers.NewHandlers(handlers.Deps{
		TxRunner:   pool,
		Deliveries: pgxstore.NewDeliveryStore(),
		APNs:       adapters.NewAPNsClient(false),
		FCM:        adapters.NewFCMClient(false),
		WebPush:    adapters.NewWebPushClient(false),
		Tokens:     adapters.NewTokenLookup(false),
		Events:     pub,
		Clock:      adapters.SystemClock{},
		IDs:        adapters.NewULIDGenerator(),
		Log:        log,
		Metrics: &handlers.Metrics{
			PushesEnqueued: meter.Counter("notifier_pushes_enqueued"),
			PushesSent:     meter.Counter("notifier_pushes_sent"),
			PushesFailed:   meter.Counter("notifier_pushes_failed"),
		},
	})

	srv := grpc.NewServer(
		grpc.UnaryInterceptor(velixgrpcauth.UnaryInterceptor(
			velixtoken.NewVerifier(nil), // unused: all methods are PostureInternal (mTLS)
			velixgrpcauth.StaticPostures(map[string]velixauth.Posture{
				notifierv1.NotifierService_EnqueuePush_FullMethodName:   velixauth.PostureInternal,
				notifierv1.NotifierService_GetPushStatus_FullMethodName: velixauth.PostureInternal,
			}),
		)),
	)
	notifierv1.RegisterNotifierServiceServer(srv, grpcserver.New(h))

	lis, err := net.Listen("tcp", cfg.Addr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", cfg.Addr, err)
	}
	health := velixhealth.New([]velixhealth.ReadinessCheck{
		{Name: "postgres", Check: pool.Ping},
	}, nil)
	health.SetReady(true)
	healthErr := make(chan error, 1)
	go func() { healthErr <- health.ListenAndServe(ctx, cfg.HealthAddr) }()
	serveErr := make(chan error, 1)
	go func() {
		log.Info(ctx, "notifier-server listening", "addr", cfg.Addr, "health", cfg.HealthAddr, "revision", gitRevision)
		serveErr <- srv.Serve(lis)
	}()
	select {
	case <-ctx.Done():
		srv.GracefulStop()
		return nil
	case err := <-serveErr:
		return err
	case err := <-healthErr:
		return err
	}
}
