# 11 — Failure & Retry

A taxonomy of failures and how each service handles them.

## Idempotency

Every mutating RPC accepts an `idempotency_key` (UUIDv7) from the client. The server stores `(account_id, key) → response_blob` with a 24h TTL. Replays return the cached response.

This is the foundation. Without it, retries are unsafe; with it, retries are free.

## Retry policies (client-side)

The Flutter client's sync queue (Phase 5 doc 04) retries with exponential backoff:

| Attempt | Delay |
|---|---|
| 1 | immediate |
| 2 | 1 s + jitter |
| 3 | 4 s + jitter |
| 4 | 16 s + jitter |
| 5 | 60 s + jitter |
| 6 | 5 min + jitter |
| 7+ | give up; user-facing failure |

Jitter is uniform ±25% of the base delay. This avoids thundering herds when a region recovers.

## Retry policies (server-side)

For internal RPC chains (e.g., routing → push), the calling service uses:

- Default: 3 retries, 100ms / 400ms / 1.6s, with jitter.
- gRPC-server-suggested-delay (via `Retry-After` header in trailing metadata) overrides defaults.

Some operations are NOT retried automatically:
- `SendEnvelope` — the client retries; the server publishes once and trusts the pipeline.
- `SignIn` — failures are user-facing, not retried.
- Any `INVALID_ARGUMENT`, `PERMISSION_DENIED`, `NOT_FOUND` — these are not retryable conditions.

## Circuit breakers

Each service has a circuit breaker per downstream:

```
state: closed (normal)
       open    (downstream unhealthy; reject immediately for 30s)
       half-open (single trial; success → closed, failure → open again)
```

Opens after 50% errors over a 10-second window with at least 20 requests.

When the breaker is open, the calling service:
- For optional downstreams (e.g., push): drops the request and continues.
- For required downstreams (e.g., DB): returns `UNAVAILABLE` immediately rather than queuing.

## Timeouts

Every call has an explicit timeout. Defaults:

| Call type | Timeout |
|---|---|
| In-region service-to-service RPC | 5 s |
| Cross-region (rare) | 15 s |
| Postgres read | 2 s |
| Postgres write | 5 s |
| Redis | 200 ms |
| NATS publish | 1 s |
| LiveKit JWT issuance | 1 s |
| Push API (APNs / FCM) | 8 s |

Timeouts cascade via gRPC's deadline propagation. A handler with a 5 s budget passes a 4.8 s deadline to its first downstream call.

## NATS DLQ handling

Messages that fail 6 times go to the per-stream DLQ:

- `velix.deliver.dlq` — alarming. A delivery that can't fan out indicates a bug.
- `velix.push.requested.dlq` — alarming. A push that fails 6× indicates upstream APNs/FCM degradation.
- `velix.account.deleted.dlq` — alarming, requires manual intervention (the account must be cleaned up).

Each DLQ has an alert on Prometheus that pages the on-call.

## Postgres replication lag

When the primary is lost, traffic fails over to a synchronous replica. We measure:
- `replication_lag_seconds` per replica.
- Alert at > 5 s sustained for 30 s (probably a network issue or a write-storm).
- Page at > 30 s sustained.

Reads that need strict consistency (e.g., account creation reading back) hit the primary. Reads that tolerate ≤ 1 s staleness hit replicas.

## Race conditions

Catalog of known races and their mitigations:

| Race | Mitigation |
|---|---|
| Two devices simultaneously try to claim the same handle | `INSERT ... ON CONFLICT` returns the conflict to the loser |
| Two writers race on `idempotency_keys` | UNIQUE constraint, ON CONFLICT DO NOTHING; loser reads the cached response |
| Two routing pods receive the same NATS message (rare) | Consumers are idempotent on `event_id` |
| Client sends two `SendEnvelope` with the same key | Server returns cached response |
| User device added twice via different existing devices | Identity rejects the duplicate via UNIQUE on `device_pubkey_hash` |
| Read-receipt fan-out arrives before original message acks (out-of-order) | Client orders by message ULID + sender's sequence; the receipt is silently buffered until the source message arrives |
| Token refresh race (two refreshes from the same device in the same window) | Refresh tokens are one-time use; second refresh receives an error and the client falls back to re-auth |

## At-least-once tolerance

The whole system is at-least-once. We do not promise exactly-once. The client deduplicates by message id before storing locally. Every NATS consumer is idempotent on `event_id`.

A duplicate message in the worst case manifests as the user briefly seeing a "delivered" state become "delivered again" — visually a no-op.

## Slow consumers

If a routing pod's outbound queue to a device is full (256 envelopes), it stops draining from NATS until space frees. NATS tracks unacked messages; `MaxAckPending=1000` allows enough buffering for a slow client without unbounded memory growth.

If `MaxAckPending` is hit, the pod considers the device "stuck" and forces a disconnect. The device reconnects and resumes.

## Backpressure end-to-end

```
client (offline)
  ←─── routing keeps envelopes in Postgres
       ←─── NATS holds delivery messages on the durable stream
            ←─── sender services see normal SendEnvelope success
```

The system is asymmetric: senders are decoupled from receivers. A receiver can be offline for hours without the sender feeling it. The sender's success depends only on Postgres write + NATS publish — both consistently fast.

## Disaster scenarios (RTO/RPO targets)

| Scenario | RTO | RPO |
|---|---|---|
| Single pod failure | < 30 s | 0 |
| Single AZ failure | < 5 min | 0 (synchronous replica) |
| Region failure | < 30 min | < 60 s |
| Postgres corruption | < 4 hr | < 5 min |
| Full account-DB loss | < 24 hr | < 5 min PITR |

## Tested

- Region failover drilled quarterly.
- Postgres restore drilled monthly.
- DLQ replay drilled monthly.
- Service-by-service kill-tests (chaos engineering) run weekly in staging.

## Banned

- Retries without idempotency keys.
- Retries beyond the policy table.
- Open-ended retries in worker loops (always bounded with a giveup).
- Circuit breakers that retry inside themselves (the caller retries).
- Catching all errors and continuing — every error class has a documented response.
- Suppressing errors in production logs.
- "Hopefully eventually consistent" — every eventual-consistency boundary is named and bounded.
- Distributed locks across services (we use single-service advisory locks where needed).
