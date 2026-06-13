# 08 — Logging & Errors

Phase 6 doc 10 specified the observability primitives. Phase 10 specifies the operational shape of logs, the Sentry integration for crash reports, and the PII-scrubbing contract that survives every layer.

## Logs

### Format

Structured JSON. One event per line. Stable schema.

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

### Levels

| Level | Use |
|---|---|
| `error` | Real errors that need human attention. |
| `warn` | Anomalies; the system continues. |
| `info` | Significant events: startup, deploy, shutdown. Not per-request. |
| `debug` | Verbose; enabled via runtime flag for incident diagnosis. Off in production. |

We do **not** log at `info` for every request (Phase 6 doc 10). The trace-and-metric pair is the per-request signal; logs are for events of consequence.

### PII scrubbing — defense in depth

Three layers ensure no PII leaks:

1. **Logger field allowlist.** The logger in each service refuses fields named:
   ```
   body, content, plaintext, ciphertext, password, passphrase, token,
   secret, key, pem, cipher, prompt, query, request_text, response_text,
   email, phone, handle
   ```
   In production: drops the field, increments `velix_logs_pii_dropped_total`.
   In debug: panics — this is a CI failure to flag.

2. **Field allowlist (compile-time).** A custom Go vet check + Dart static analyzer rule allows only:
   ```
   ts, level, service, version, instance, trace_id, span_id, msg,
   error_kind, error_code, request_id, idempotency_key, account_id,
   device_id, conversation_id, message_id, envelope_id, media_id,
   call_id, space_id, story_id, notification_id, error, latency_ms,
   feature, outcome, model_id, provider, kind, count
   ```
   Anything outside the allowlist requires a code-review override comment that survives audit.

3. **Sink scrubber.** The Loki shipper (Promtail) runs a regex-based scrubber as a final safety net:
   - JWT-shaped tokens → `<jwt>`
   - Email patterns → `<email>`
   - Phone patterns → `<phone>`
   - 16+ digit sequences → `<digits>`
   - Base64-shaped 32+ byte strings → `<b64>`

If the scrubber fires in production, we log a counter (no content) and emit a P1 alert.

### Storage

- **Loki** as the backing store. 7 days hot retention; 90 days cold (S3-backed); 1 year archive in Glacier-equivalent.
- **Per-service Loki labels:** `service`, `version`, `cell`, `level`. Cardinality is bounded.
- **Forbidden Loki labels:** `account_id`, `device_id`, `request_id`. Tags with these explode index cost.

### Querying

Engineers use Grafana → Logs to query Loki. Common queries are saved as buttons on the per-service dashboard:

- "Errors in last hour"
- "5xx in last 24 hours"
- "Slow requests (latency > 500ms)"
- "Sentry crash IDs in last 24 hours"

Engineers do not have raw Loki API access; they go through Grafana's RBAC.

## Errors

### Sentry integration

Self-hosted Sentry. Per-service DSN. Captures:

- Uncaught exceptions in any goroutine / Dart isolate.
- Crashed processes (Go's `recover`-and-rethrow + Dart's `FlutterError.onError` + `runZonedGuarded`).
- Flutter framework errors via `FlutterError.onError`.
- Manual `captureException` calls.

Sentry events are **scrubbed at the SDK** before leaving the device/server:

```dart
// apps/velix_app/lib/src/observability/sentry_init.dart
SentryFlutter.init((options) {
  options.dsn = '...';
  options.beforeSend = (event, hint) {
    // Drop the request body, headers, and any field matching the PII allowlist.
    return _scrub(event);
  };
  options.tracesSampleRate = 0.05;          // 5% performance tracing
  options.attachStacktrace = true;
  options.sendDefaultPii = false;            // Sentry default; we re-emphasize
  options.maxBreadcrumbs = 50;
});
```

Server-side similar: every Go service's Sentry SDK has a `BeforeSend` hook that strips PII.

### Breadcrumbs

200-entry ring buffer per session. Examples:

- `route.push: /chats/abc123`
- `provider.dispose: messagesProvider(...)`
- `gateway.timeout: send_message`

Breadcrumbs:
- Carry no PII.
- Include the trace_id of the active span.
- Are attached to any error report.
- Flush on app background / process shutdown.

### Error grouping

Sentry groups by stack trace fingerprint. Each unique error gets an issue ID. We watch:

- New issues (alert).
- Issues with rising frequency (alert).
- Issues with > 100 occurrences (alert).

A new issue triggers Slack `#errors` and Sentry-side ticket creation.

### Error retention

- Sentry DB: 30 days.
- Long-term archive: aggregated counts only (no per-event retention beyond 30 days).
- Customer support cannot query Sentry for "show me User X's errors" — Sentry is identity-blind via the PII scrubber.

## Crash reporting

Per platform:

| Platform | Crash mechanism |
|---|---|
| iOS | Sentry's iOS SDK + standard `os_signpost` |
| Android | Sentry's Android SDK + Crashlytics-equivalent ANR detection |
| Backend Go | `recover()` in HTTP/gRPC handlers; Sentry SDK |
| Backend Rust (cryptocore) | `panic = "abort"` in release; the host process catches |

Crash reports include:
- The error and stack trace (scrubbed).
- The app version.
- The OS version (no device fingerprint).
- The user's coarse country (IP-derived; no IP itself).

We do NOT include:
- The user's account_id.
- The user's display name.
- Recent message content.
- Open conversation IDs.

## Tracing

OTel-based. Phase 6 doc 10 specifies. Operationally:

- Sample 100% on errors.
- Sample 5% on success in production.
- Sample 100% in staging.
- Trace propagation across NATS via `Velix-Trace-Id` header.
- Propagation across OHTTP relay: deliberately broken (Phase 8 doc 14).

## Correlation across pillars

For an incident:

```
1. Alert fires: identity p99 latency burn.
2. On-call opens Grafana dashboard.
3. Sees latency spike at 14:32 UTC.
4. Clicks the "View errors" button → Sentry issues for that service for the time window.
5. Clicks "View traces" → Tempo traces sampled around 14:32.
6. Picks a slow trace; correlates to the underlying DB query.
7. Investigates.
```

Trace IDs are the cross-cutting key. They appear in logs, traces, and breadcrumbs.

## What logs we deliberately don't keep

- Per-request access logs. We have metrics for that.
- Per-message envelope routing logs. The trace covers it.
- Per-user activity logs. PII concern.
- Verbose database query logs. Slow-query log is the signal.

## What gets aggregated daily for the public

A nightly aggregator produces:

- Service uptime %.
- p50 / p95 / p99 latency per service.
- Total messages delivered.
- Total cloud AI invocations.
- Total push notifications dispatched.

Published quarterly at `velix.app/transparency`. Per Phase 7's commitment posture.

## Operational runbook for log-related incidents

| Incident | Runbook |
|---|---|
| Logs missing for a service | runbook/logs-missing |
| PII pattern detected in logs | runbook/pii-leak |
| Loki disk filling | runbook/loki-disk |
| Sentry rate-limit hit | runbook/sentry-rate-limit |
| Trace sampling broken | runbook/tracing-broken |

## Banned

- Logging request body content.
- Logging response body content.
- Logging headers besides the allowlist.
- Logging IP addresses (only the relay sees them; we don't surface them).
- Logging quota tokens.
- Using a high-cardinality label like `account_id` in any metric.
- Custom metrics not in the catalog (Phase 6 doc 10).
- Sending traces that link client to gateway through the relay.
- Sentry integration that captures content.
- Any kind of prompt-response store for "improvement" without explicit user consent.
