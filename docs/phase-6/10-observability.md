# 10 — Observability

We are vendor-neutral by design. OpenTelemetry produces traces, metrics, and logs; the storage and dashboards are Grafana / Tempo / Loki / Prometheus. If we ever migrate, we migrate the storage, not the instrumentation.

## Three pillars

### Traces (Tempo)

Every gRPC RPC, every Postgres query, every NATS publish/consume, every Redis call is a span.

- Sampler: 100% on errors; 10% on success in production; 100% in staging.
- Span attributes:
  - `service.name`, `service.version`, `service.instance.id`
  - `velix.account_id` (only when the call is account-bound)
  - `velix.device_id` (only when device-bound)
  - `velix.idempotency_key` (when present)
  - **Never**: ciphertext, plaintext, message bodies, handle plaintext, token contents.
- Trace propagation across gRPC: standard W3C `traceparent` header.
- Trace propagation across NATS: `Velix-Trace-Id` header (W3C-compatible).

### Metrics (Prometheus)

Each service exposes `:9100/metrics`. Standard RED metrics + service-specific.

**Core metrics (every service):**

```
velix_grpc_requests_total{service, method, status}
velix_grpc_request_duration_seconds{service, method}     histogram
velix_grpc_in_flight{service, method}                    gauge

velix_pg_query_duration_seconds{service, name}           histogram
velix_pg_query_errors_total{service, name, code}

velix_redis_op_duration_seconds{service, op}             histogram
velix_redis_op_errors_total{service, op, code}

velix_nats_publish_total{service, subject, status}
velix_nats_consume_duration_seconds{service, subject}    histogram
velix_nats_consume_errors_total{service, subject, code}
```

**routing-specific:**

```
velix_routing_envelope_enqueued_total
velix_routing_envelope_delivered_total{state="acked"|"timeout"|"dlq"}
velix_routing_socket_active                              gauge
velix_routing_socket_lifetime_seconds                    histogram
velix_routing_send_to_deliver_seconds                    histogram (end-to-end, sampled by trace)
```

**identity-specific:**

```
velix_identity_signin_total{outcome}
velix_identity_token_refresh_total{outcome}
velix_identity_account_created_total
```

**push-specific:**

```
velix_push_dispatched_total{platform="apns"|"fcm", outcome}
velix_push_token_invalid_total{platform}
```

**call-specific:**

```
velix_call_session_started_total
velix_call_session_duration_seconds                      histogram
velix_call_participant_count                             histogram
```

### Logs (Loki)

Structured JSON, one event per log line. Format:

```json
{
  "ts": "2026-05-28T12:34:56.789Z",
  "level": "info",
  "service": "routing",
  "version": "1.0.3",
  "instance": "routing-7d9f-xz2",
  "trace_id": "0123abcd...",
  "span_id": "ef89...",
  "msg": "envelope enqueued",
  "envelope_id": "01HBCD...",
  "recipient_device_id": "01H..."
}
```

Levels: `debug`, `info`, `warn`, `error`. Production runs at `info` (errors and warnings always logged; debug only in staging).

**PII scrubbing rules** (enforced in the logger):
- Drop fields named `body`, `ciphertext`, `plaintext`, `token`, `password`.
- Hash fields named `email`, `phone` (HMAC-SHA-256 with a per-release salt).
- Redact field values matching regex for JWT, Authorization header, etc.

A scrubber lints every log line in transit; if a known PII pattern leaks, we drop the line and emit a `velix_logs_pii_dropped_total` counter.

## Dashboards (one per service)

Each service ships a Grafana dashboard JSON in `ops/grafana/<service>.json`. Each dashboard has:

- **Top row**: requests/sec, error %, p50/p95/p99 latency.
- **Database row**: query rate, query latency, replication lag.
- **Redis row**: op rate, op latency, hit/miss ratio (where applicable).
- **NATS row**: subjects published, consume lag, DLQ depth.
- **Service-specific row**: routing's connections graph; identity's sign-in funnel; etc.

A "system overview" dashboard aggregates the six.

## Alert rules

Per service, a Prometheus rule file in `ops/prom/rules/<service>.yaml`. Critical alerts page; warnings go to a Slack channel.

| Alert | Severity | Trigger |
|---|---|---|
| Service error rate > 5% | page | sustained for 2 min |
| Service p99 latency > 2× target | page | sustained for 5 min |
| DB replication lag > 30s | page | sustained for 1 min |
| DLQ depth > 0 on any stream | page | non-zero |
| Push success rate < 95% | warn | sustained for 5 min |
| Postgres connection pool exhaustion | page | any 30-s window |
| Redis cluster degraded | page | any |
| LiveKit cluster CPU > 80% | warn | sustained for 5 min |
| Cert expiring within 14 days | warn | daily |

## SLOs

Per service, a published SLO. Burn-rate alerts page when the error budget is being consumed too fast.

| Service | Availability SLO | Latency SLO (p99) |
|---|---|---|
| identity | 99.95% | 60 ms |
| routing | 99.99% (the hot path) | 80 ms |
| media | 99.9% | 200 ms |
| push | 99.5% (depends on APNs/FCM) | n/a |
| call | 99.95% | 700 ms (LiveKit join) |
| notifier | 99.5% (audit; non-customer-facing) | 1 s |

## Synthetic probes

Every minute:
- Sign in with a probe account; tear down session.
- Send a probe message between two probe devices; verify delivery within 2 s.
- Issue a media presigned URL; verify the presign roundtrip.
- Start and end a probe call; verify the LiveKit JWT issues.

Probes' results emit `velix_synthetic_probe_total{name, outcome}`. A failure rate > 5% over 5 minutes pages.

## Tracing the hot path

A typical end-to-end trace for a sent message:

```
1. Edge envoy receives the gRPC SendEnvelope call.
2. Span: edge.grpc → routing.grpc.SendEnvelope
3. Span: pg.insert message_envelope
4. Span: nats.publish velix.deliver.<account>.<device>
5. (separate trace continues via NATS header propagation)
   Span: nats.consume velix.deliver.<account>.<device>
6. Span: socket.write to recipient device
```

This shows up as a single Tempo trace with all six spans. Average end-to-end span time visible at a glance.

## Cost discipline

- Trace sampling at 10% on success (production) means storage cost is bounded.
- Logs at info level produce ~1 KB / sec / pod; rotation to S3 after 7 days.
- Metrics retention: 30 days hot, 1 year aggregated.
- Budget: ≤ $0.05 / MAU / month for observability.

## Banned

- `fmt.Println` in production code.
- Non-structured logs.
- Logging request/response bodies.
- Pulling in `print` libraries that bypass our logger.
- Sampling out trace errors (errors are always sampled).
- Custom dashboards in Grafana that aren't checked into source.
- Alert rules without a runbook link.
- Metrics whose names break the prometheus naming convention (`<namespace>_<noun>_<unit>`).
- High-cardinality labels (we never use account_id as a label).
