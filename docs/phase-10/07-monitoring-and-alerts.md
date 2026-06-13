# 07 — Monitoring & Alerts

The visible state of production. Phase 6 doc 10 specified the observability primitives; Phase 10 specifies the operational shape — dashboards, alert routes, runbooks, on-call posture.

## Pillars

1. **SLO-driven alerting.** We alert on burn rate, not absolute thresholds. A spike that doesn't threaten the SLO doesn't page.
2. **Every alert has a runbook.** No "we'll figure it out when it fires."
3. **No noisy alerts.** An alert that fires more than once a week without action is removed.
4. **Three severity tiers:** P0 (page), P1 (Slack channel), P2 (dashboard only).
5. **Aggregate, never per-user.** Following Phase 6 doc 10's PII discipline.

## SLOs (per service)

Restated from Phase 6 doc 10 with operational detail.

| Service | Availability | p99 latency | Error budget per 30 days |
|---|---|---|---|
| identity | 99.95% | 60 ms | 21.6 minutes |
| routing | 99.99% | 80 ms | 4.32 minutes |
| media | 99.9% | 200 ms | 43.2 minutes |
| push | 99.5% | n/a (depends on APNs/FCM) | 3.6 hours |
| call | 99.95% | 700 ms (LiveKit join) | 21.6 minutes |
| notifier | 99.5% (audit; non-customer-facing) | 1 s | 3.6 hours |
| ai_gateway | 99.5% | 600 ms first-token | 3.6 hours |

The 99.99% on routing is aggressive. We meet it via:
- Multi-AZ Postgres with sync replica.
- 3+ replicas of the routing service per cell.
- Sticky-hash routing so a single pod failure affects only that pod's connections (1/3 of cell traffic in steady state).
- LRU client-side reconnect with backoff.

## Burn-rate alerting

We use multi-window, multi-burn-rate alerts (Google SRE pattern):

```
critical (page):
  2% of error budget consumed in 1 hour
  AND
  5% of error budget consumed in 6 hours

warning (Slack):
  10% of error budget consumed in 24 hours
```

This catches both fast disasters (the 1-hour window) and slow burns (the 24-hour window). It does not page on a 5-minute spike that doesn't threaten the SLO.

## Per-service alert catalog

For each service, we ship a fixed set of alerts. Adding a new alert requires SRE review. Removing an alert requires team consensus.

### Universal (every service)

| Alert | Severity | Trigger | Runbook |
|---|---|---|---|
| `service_down` | P0 | replicas ready < 1 for 1 min | runbook/service-down |
| `error_rate_burn` | P0 | error budget burn > critical threshold | runbook/error-rate |
| `latency_burn` | P0 | latency budget burn > critical threshold | runbook/latency |
| `replication_lag` | P0 | Postgres replication > 30s | runbook/postgres-replication |
| `pg_pool_exhausted` | P0 | connection pool wait > 1s | runbook/pg-pool |
| `redis_cluster_degraded` | P0 | any redis node down | runbook/redis-failover |
| `nats_dlq_nonzero` | P1 | any DLQ has messages | runbook/nats-dlq |
| `cert_expiring` | P1 | TLS cert expires in < 14 days | runbook/cert-rotation |
| `disk_filling` | P1 | persistent volume > 80% | runbook/disk-pressure |
| `oom_kill` | P1 | container OOMKilled in last 5 min | runbook/oom |
| `restart_loop` | P1 | container restarted 3+ times in 10 min | runbook/restart-loop |

### identity-specific

| Alert | Severity | Trigger |
|---|---|---|
| `signin_error_rate` | P0 | sign-in error rate > 5% over 5 min |
| `prekey_inventory_low` | P1 | < 10% of accounts have one-time prekeys available |
| `token_signing_key_rotation_overdue` | P1 | rotation > 35 days |

### routing-specific

| Alert | Severity | Trigger |
|---|---|---|
| `socket_connect_rate_drop` | P0 | active connections drop > 50% in 1 min |
| `envelope_publish_failures_high` | P0 | NATS publish failure rate > 1% over 5 min |
| `unpublished_envelope_backlog` | P1 | reconciler queue depth > 1000 |
| `delivery_p99_high` | P0 | end-to-end p99 > 250 ms intra-region for 5 min |

### media-specific

| Alert | Severity | Trigger |
|---|---|---|
| `r2_4xx_rate` | P1 | 4xx response rate from R2 > 1% over 5 min |
| `r2_5xx_rate` | P0 | 5xx > 0.1% over 5 min |
| `presign_issuance_rate_drop` | P1 | issuance drops > 50% from baseline |

### push-specific

| Alert | Severity | Trigger |
|---|---|---|
| `apns_error_rate` | P1 | error rate > 5% over 5 min |
| `fcm_error_rate` | P1 | same |
| `push_dispatch_rate_drop` | P1 | dispatch rate drops > 50% from baseline |
| `push_token_unregistered_spike` | P1 | unregistered rate > 10x baseline |

### call-specific

| Alert | Severity | Trigger |
|---|---|---|
| `livekit_cluster_cpu_high` | P1 | any node > 80% CPU for 5 min |
| `call_join_failure_rate` | P0 | > 5% join failures over 5 min |
| `livekit_webhook_failures` | P1 | webhook delivery failures > 1% |

### ai_gateway-specific

| Alert | Severity | Trigger |
|---|---|---|
| `provider_error_rate` | P1 | provider error rate > 5% over 5 min (per provider) |
| `ohttp_relay_errors` | P0 | relay-side error rate > 1% |
| `quota_token_validation_failures` | P1 | > 1% of tokens invalid |
| `pii_leakage_check_failed` | P0 | telemetry scrubber detected PII pattern |

## Synthetic probes

Every minute, from a region OUTSIDE our cells (so we measure real network path):

| Probe | What it tests |
|---|---|
| `signin_probe` | sign in with a probe account; tear down |
| `send_message_probe` | send a probe message between probe accounts; verify delivery in 2 s |
| `media_presign_probe` | request a presigned upload URL; verify signature |
| `call_start_probe` | start + end a call between probe accounts |
| `ai_translate_probe` | invoke cloud translation with synthetic text |
| `home_screen_load_probe` | full app cold-start measurement |

Probe failures > 5% over 5 min → P0.

## Dashboards

Per service, one Grafana dashboard JSON checked into `ops/grafana/<service>.json`. Every dashboard has:

- **Top row:** RPS, error %, p50 / p95 / p99 latency.
- **Database row:** query rate, latency, replication lag.
- **Redis row:** op rate, latency, hit/miss.
- **NATS row:** publish/consume rates, lag, DLQ depth.
- **Service-specific row:** routing's connection count; identity's signin funnel; etc.
- **Resource row:** CPU, memory, restart counts.

A "Velix overview" dashboard aggregates the seven services into a single page for the on-call.

A "Customer-impacting" dashboard tracks external-facing SLIs:
- Cold start time (synthetic probe).
- End-to-end message delivery time.
- Call join time.
- Push delivery time.

## Alert routing

```
┌───────────────────────────────────┐
│   Prometheus / Mimir              │
│      ⇣ alert fires                │
│   Alertmanager                    │
└───────┬───────────────────────────┘
        │
        ├── P0 ──→ PagerDuty (on-call rotation) → SMS / phone
        ├── P0 ──→ #incidents (Slack)
        ├── P1 ──→ #alerts (Slack)
        └── P2 ──→ Grafana annotations only

Each P0 alert auto-creates an incident in PagerDuty with:
  - service name
  - alert name
  - severity
  - runbook link
  - dashboard link
  - last 30 minutes of recent logs (Loki query)
```

## On-call rotation

- Primary on-call: 1 engineer, 1-week rotation, follows the sun (3 timezones at scale).
- Secondary: 1 engineer, escalates from primary in 15 min.
- Manager: escalates from secondary in 30 min.

On-call has:
- PagerDuty alert.
- A laptop with `kubectl` configured (read-only by default; write requires dual-approval).
- Vault break-glass access (4-hour TTL; audit-logged).
- Slack access to #incidents.
- Documentation in `ops/runbooks/`.

## Runbooks (the contract for every alert)

Every alert links to a markdown runbook with:

1. What this alert means.
2. Likely causes.
3. Diagnostic steps (specific Grafana queries, kubectl commands, dashboards).
4. Mitigation steps in order of preference.
5. Escalation criteria.
6. Postmortem template link.

Example: `ops/runbooks/postgres-replication.md`:

```markdown
# Postgres replication lag

## What this means
The synchronous replica is more than 30 seconds behind the primary.

## Diagnostic
1. Check Grafana → Postgres → Replication panel.
2. Check primary's `pg_stat_replication` view via the read-only RDS console.
3. Verify network between primary AZ and replica AZ.

## Mitigation
1. If network: file ticket with cloud provider; increase replication-lag tolerance.
2. If replica overloaded: scale up replica node.
3. If primary overloaded by writes: enable rate limiting at edge layer.
4. If replication slot bloat: ALTER REPLICATION SLOT ... to drop stale slots.

## Escalate if
- Lag > 5 minutes for 10+ minutes.
- Primary write throughput dropping.

## Postmortem template
Link: docs/postmortems/template.md
```

Every runbook is reviewed quarterly during DR drills.

## Status page

Public-facing at `status.velix.app`. Driven by:
- Synthetic probe outcomes.
- Manual incident creation by the on-call.

Status posted within 5 minutes of confirmed customer-facing incidents.

## What we deliberately don't alert on

- Per-user issues (not customer-impacting at scale).
- Background queue depth fluctuations within normal ranges.
- Single-pod restarts (Kubernetes handles).
- Aggregate metrics dipping for < 1 minute (wait for the burn-rate window).
- SSL handshake errors from individual clients (we measure the SLI, not the per-client failure).

## What's NOT yet wired

These are Phase 10.5 work:

- Real Grafana dashboards (we ship JSON; team imports).
- Real PagerDuty configuration.
- Real Alertmanager rules (we ship the spec; team configures).
- SRE-level incident-response training.

These are not blockers for Phase 11 audit; they are first-week work post-Phase-10.

## Banned

- Alerts without runbooks.
- Alerts without dashboards.
- Per-user labels on metrics (high cardinality + privacy).
- Pager fatigue: any alert that fires regularly without action gets removed.
- Slack-only P0 alerts (P0 must page).
- Alerts that the on-call cannot mitigate.
- Production access via cleartext credentials.
