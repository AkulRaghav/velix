# 00 — Backend Architecture Overview

## Position

The Velix backend is the **minimum** infrastructure required to route ciphertext between cryptographic identities, hold offline messages durably, deliver push, broker LiveKit sessions, and serve media. It is deliberately **not** a place where rich business logic lives. Application logic that requires plaintext access lives in the client; the backend's superpower is that it knows as little as possible.

Six services. Each a single binary. Each owns its data. Cross-service traffic is gRPC (sync) or NATS (async), never shared databases.

## Stack (locked, Phase 0)

| Layer | Choice | Why |
|---|---|---|
| Language | **Go 1.22+** | goroutine-cheap concurrency, fast cold starts, easy ops |
| RPC | **gRPC** with **buf** for build | strict typed contracts; codegen for client and server; reflection for tools |
| Wire format | **Protobuf** | for both gRPC and NATS payloads |
| HTTP edge | **Connect** (over gRPC, with HTTP/JSON fallback for browsers) | one toolchain, one schema |
| Async spine | **NATS JetStream** | lower operational weight than Kafka for messaging fanout |
| Persistence | **PostgreSQL 16** with **pgx/v5** | boring, scalable, audited |
| Hot state | **Redis 7** (cluster mode) | presence, rate limits, token allowlist |
| SFU | **LiveKit** self-hosted | per-region clusters, E2EE via Insertable Streams ≤ 8 |
| Object storage | **Cloudflare R2** (S3-compatible) | egress economics |
| Secrets | **HashiCorp Vault** | service-token issuance + per-service KMS |
| Telemetry | **OpenTelemetry** → **Grafana / Tempo / Loki / Prometheus** | vendor-neutral |
| Container runtime | **Kubernetes** (EKS or GKE) | mature; per-service deploy |
| Migrations | **goose** (Go-native) | reversible, testable |
| Test | Go `testing` + **testcontainers-go** for Postgres / Redis / NATS integration | hermetic |

We do not use:
- gRPC-Gateway as a translation layer (Connect handles HTTP/JSON natively).
- Kafka (operational complexity not justified at our scale).
- Redis-as-message-broker (NATS does this better).
- An ORM. pgx + sqlc.
- Service mesh (Istio, Linkerd) at 1.0. mTLS via cert-manager + envoy is overkill for six services.

## Top-level shape

```
                     ┌──────────────────┐
                     │   Flutter app    │
                     │  (Phase 5)       │
                     └────┬─────────────┘
                          │ HTTP/3 + gRPC
                          │ TLS 1.3
                  ┌───────▼─────────┐
                  │   edge (envoy)  │   stateless; TLS termination, IP rate limit,
                  │                 │   connection routing, anycast
                  └───────┬─────────┘
                          │ mTLS, gRPC
        ┌─────────────────┼─────────────────┬──────────────┬─────────┐
        │                 │                 │              │         │
   ┌────▼────┐      ┌─────▼─────┐     ┌─────▼─────┐  ┌─────▼────┐ ┌──▼───┐
   │ identity│      │  routing  │     │   media   │  │  push    │ │ call │
   │         │      │           │     │           │  │          │ │      │
   └────┬────┘      └─────┬─────┘     └─────┬─────┘  └────┬─────┘ └──┬───┘
        │                 │                 │              │         │
        │            ┌────┴───┐              │              │         │
        │            │ socket │              │              │         │
        │            │ termin.│              │              │         │
        │            └────┬───┘              │              │         │
        │                 │                  │              │         │
   ┌────▼─────────────────▼──────────────────▼──────────────▼─────────▼──┐
   │                                                                     │
   │   Postgres 16   ·   Redis 7 (cluster)   ·   NATS JetStream          │
   │                                                                     │
   └─────────────────────────────────────────────────────────────────────┘
                                                                       │
                                                                       │
                                                                ┌──────▼──────┐
                                                                │  LiveKit    │
                                                                │  per region │
                                                                └─────────────┘

                                                                ┌─────────────┐
                                                                │ Cloudflare  │
                                                                │  R2         │
                                                                └─────────────┘
```

The edge is the single entry point. It's stateless, anycast-routed, terminates TLS, and forwards requests over mTLS to the appropriate service based on the gRPC method name. It holds no state, makes no decisions about content, and is one of the cheapest things in our cluster to operate.

## Module layout

```
backend/
  proto/                              ← .proto files (the single source of truth)
    velix/identity/v1/*.proto
    velix/routing/v1/*.proto
    velix/media/v1/*.proto
    velix/push/v1/*.proto
    velix/call/v1/*.proto
    velix/notifier/v1/*.proto
    velix/events/v1/*.proto           ← NATS event payloads
  buf.yaml
  buf.gen.yaml                        ← codegen config

  services/
    identity/
      cmd/identity/main.go
      internal/                       ← unexported; per-service Go code
      migrations/                     ← goose .sql files
      Dockerfile
      go.mod
    routing/
    media/
    push/
    call/
    notifier/

  pkg/                                ← shared utilities (NOT business logic)
    velixctx/                         ← request-context plumbing (auth, span)
    velixerr/                         ← gRPC error mapping
    velixobs/                         ← OTel + structured logging
    velixsql/                         ← pgx helpers
    velixnats/                        ← NATS helpers
    velixauth/                        ← internal service-token verification
    velixtest/                        ← test fixtures, fakes

  ops/
    helm/                             ← per-service Helm charts
    terraform/                        ← per-region infra
    grafana/                          ← dashboards (JSON)
```

Each service is its own Go module, with its own `go.mod`. Cross-service code reuse goes through `pkg/`, which contains *only* infrastructure helpers, never business logic.

## Bootstrap & lifecycle (per service)

Every service follows the same shape:

```go
func main() {
    cfg := config.Load()                   // env-driven; 12-factor
    logger := velixobs.NewLogger(cfg)
    tracer := velixobs.NewTracer(cfg)

    db, err := velixsql.Open(ctx, cfg.PostgresDSN)
    redis, err := velixredis.Open(ctx, cfg.RedisAddrs)
    nats, err := velixnats.Open(ctx, cfg.NatsAddr)

    svc := newService(db, redis, nats)     // pure constructor

    grpcSrv := grpc.NewServer(serverOpts(cfg)...)
    velixv1.RegisterIdentityServiceServer(grpcSrv, svc)

    // Graceful shutdown.
    ctx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
    defer stop()
    go grpcSrv.Serve(lis)
    <-ctx.Done()
    grpcSrv.GracefulStop()
}
```

Configuration is environment-driven. Twelve-factor. No conditional code paths based on environment beyond log level and rate-limit defaults.

## Performance targets

| Metric | Target | Rationale |
|---|---|---|
| Edge → service p99 latency | ≤ 5 ms | Stateless edge over mTLS within the same VPC |
| identity.SignIn p99 | ≤ 60 ms | One Postgres read + token sign |
| routing.SendMessage p99 | ≤ 80 ms | One Postgres write + NATS publish |
| routing socket message delivery p99 | ≤ 250 ms (intra-region) | client-to-client end-to-end |
| Push delivery p95 (network-dependent) | ≤ 4 s | APNs/FCM SLA territory |
| Database write p99 | ≤ 50 ms | pgx prepared statements; sane indexes |
| Database read p99 | ≤ 20 ms | covered indexes for hot paths |
| LiveKit join p95 | ≤ 700 ms | Per-region routing; pre-warmed JWT issuance |

Verified by k6 load tests in CI on representative traffic shapes.

## Security baseline

Restated up-front; details in Phase 6 doc 09:

- mTLS between every internal service.
- All inbound external traffic is HTTPS-only, TLS 1.3, HSTS preloaded.
- All credentials short-lived. Service-to-service tokens rotate every 24h.
- Postgres connections use TLS + scram-sha-256 + per-service roles.
- Redis ACLs per service.
- All secrets in Vault. No secrets in env files committed to git.
- Every gRPC server has request size limits, timeout per RPC, and connection-draining shutdown.
- Every gRPC server has a structured-logging interceptor that scrubs PII.
- Every external endpoint has rate limiting at the edge.

## Observability baseline

- OpenTelemetry tracing on every RPC, propagated through NATS payloads.
- Structured JSON logs to stdout (consumed by Loki).
- Prometheus metrics on every service: RED metrics + service-specific counters.
- A single dashboard per service, pre-built in Grafana.
- Alert rules for: error rate, p99 latency, queue depth, replication lag.

## Banned at the architecture level

- A "shared business library" that becomes the everything-bag.
- Distributed transactions (XA, two-phase commit).
- ORMs (we use sqlc).
- Sidecar proxies for logic (envoy is for TLS only).
- Cross-region synchronous calls in the hot path.
- Putting plaintext message content into any service's storage.
- Adding a seventh service before justifying it against the criteria in `01-service-boundaries.md`.

## Audit hooks

CI on every PR:
- `buf lint` + `buf breaking` against the previous proto release.
- `gosec` for security scanning.
- `staticcheck` + `golangci-lint` strict.
- Race detector on tests (`go test -race`).
- testcontainers integration tests against Postgres / Redis / NATS.
- k6 smoke load tests on PRs that touch RPC handlers.
