# Phase 6 — Backend Architecture

Status: in progress. Gates Phase 7.

## What ships

The production backend architecture. Six Go services. gRPC and NATS contracts. Postgres schemas. Redis topology. LiveKit integration. Observability baseline. Reference Go scaffolding for the routing service (the hot path) and concrete handler stubs for the other five.

## Locked posture

- **Stack.** Go 1.22+, gRPC + Connect, Postgres 16, Redis 7, NATS JetStream, LiveKit. No ORM. sqlc + pgx.
- **Six services.** identity, routing, media, push, call, notifier. No more, no less. Each owns its data.
- **Contract-first.** `.proto` files are the single source of truth. Buf-driven codegen.
- **Server knows minimum.** Routing routes ciphertext envelopes; media stores ciphertext. The server cannot read user content under any circumstances.
- **mTLS internal, OIDC external.** Service-to-service tokens are short-lived (24h, rotated). Client tokens are short-lived (15 min, refresh).
- **Eventual consistency where reasonable, strict ordering where required** (per-conversation message order is preserved).

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [Architecture Overview](./00-architecture-overview.md) | Stack, layout, perf targets, security baseline |
| 01 | [Service Boundaries](./01-service-boundaries.md) | Six services, what each owns, what's banned |
| 02 | [API Contracts](./02-api-contracts.md) | gRPC `.proto` design, error model, versioning |
| 03 | [Realtime Messaging](./03-realtime-messaging.md) | Socket termination, fanout, ordering, retries |
| 04 | [Persistence](./04-persistence.md) | Postgres schemas, indexes, migrations, sharding |
| 05 | [Hot State (Redis)](./05-hot-state.md) | Presence, typing, rate limits, dedup |
| 06 | [NATS Subjects & Events](./06-nats-subjects-and-events.md) | Subject map, payload shape, retention |
| 07 | [LiveKit Integration](./07-livekit.md) | JWT issuance, room lifecycle, E2EE bounds |
| 08 | [Push Notifications](./08-push.md) | APNs / FCM dispatch, encrypted payloads, token rotation |
| 09 | [Security & Auth](./09-security-and-auth.md) | mTLS, OIDC, secrets, threat model |
| 10 | [Observability](./10-observability.md) | OTel, RED metrics, dashboards, alerts |
| 11 | [Failure & Retry](./11-failure-and-retry.md) | Idempotency, retries, circuit breakers, backoff |
| 12 | [Phase 6 Audit](./12-phase-6-audit.md) | Self-review, gating Phase 7 |

## Reference implementation

```
backend/
  proto/                       ← .proto contracts
  buf.yaml + buf.gen.yaml      ← codegen
  services/
    identity/                  ← scaffold
    routing/                   ← reference implementation (the hot path)
    media/                     ← scaffold
    push/                      ← scaffold
    call/                      ← scaffold
    notifier/                  ← scaffold
  pkg/                         ← shared infrastructure helpers
  go.work                      ← workspace
```

Phase 6 ships the *contracts* and the *routing reference* fully. The other five services have buildable stubs with handler signatures, internal package layout, migration scaffolds, and configuration. Filling them in is the team's first sprint after Phase 6 sign-off; the contract-first design means each fill-in is mechanical.

## Reading order

If you have ten minutes: 00 → 01 → 12.
If you're implementing a service: 02 → 03 (or 07/08 for call/push) → 04 → 09 → 10.
If you're auditing: 12 → 09 → 11 → 04 → 03.
