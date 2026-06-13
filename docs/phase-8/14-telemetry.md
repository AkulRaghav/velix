# 14 — AI Telemetry

What we count. What we never log.

## Counters

Per feature, content-free aggregate metrics emitted via OTel (Phase 6 doc 10).

```
velix_ai_invocations_total{feature, on_device|cloud, outcome=success|error|cancelled|consent_declined}
velix_ai_latency_seconds{feature, on_device|cloud}        histogram
velix_ai_quota_remaining{tier}                            gauge (per Velix as a whole; not per user)
velix_ai_consent_shown_total{feature}
velix_ai_consent_accepted_total{feature}
velix_ai_consent_declined_total{feature}
velix_ai_redaction_markers_total{marker_kind}             counts how often we redact each kind
velix_ai_provider_dispatched_total{provider, status}
velix_ai_model_loaded_total{model_id, version}
velix_ai_model_inference_failures_total{model_id, reason}
velix_ai_relay_errors_total{stage}
```

That is the complete catalog. Adding a new metric requires architectural review.

## Forbidden metrics

These would be useful for product analysis but are forbidden because they enable correlation:

- Per-user invocation counts.
- Per-conversation invocation counts.
- Time-of-day heatmaps (correlable with user activity patterns).
- Per-locale invocation counts at high granularity (we use 4-locale buckets: NA, EU, APAC, other).
- Length distribution of inputs (could fingerprint conversation activity).

## Logs

Structured JSON, but at AI-event level, with explicit field allowlist. The logger refuses fields outside the allowlist.

```json
{
  "ts": "...",
  "level": "info",
  "service": "ai_gateway",
  "version": "1.0.3",
  "event": "request_received",
  "feature": "translate",
  "outcome": "success",
  "latency_ms": 412
}
```

Allowed fields: `ts, level, service, version, event, feature, outcome, latency_ms, model_id, provider`.

Forbidden fields (compile-time-checked): `account_id, device_id, user_id, conversation_id, message_id, body, prompt, content, query, request_text, response_text, ip, email, phone, handle`.

The logger has a structural test: invoke with each forbidden field; expect a panic in debug, drop in production with a counter increment.

## Trace propagation across the relay

OpenTelemetry trace IDs do not flow from client through the OHTTP relay to the gateway. Carrying a trace ID would let the relay correlate per-request via the trace ID.

Instead:

- Client emits a client-side trace.
- Gateway emits a gateway-side trace, anchored by the OHTTP request.
- The two traces are NOT linked. We can debug a client-side issue or a gateway-side issue, but not a single end-to-end flow without sampling other signals.

This is a deliberate observability sacrifice for privacy.

## Sampling

- Errors: 100%.
- Successes: 1% sampled (we have aggregate counters; per-success traces aren't useful).
- Latency outliers (p99): 100% within a 5-minute window for diagnosis.

Sampling is configured server-side via OTel's tail sampler.

## What gets aggregated daily

A nightly aggregator produces a public dashboard at `velix.app/transparency/ai`:

- Total cloud AI invocations (no per-user breakdown).
- Total on-device AI invocations.
- Per-feature usage as a percentage.
- Average latency.
- Provider distribution.
- Quota utilization (system-wide).

Published quarterly. We've committed to transparency about scale (our public commitment under "no surveillance"); we don't have per-user data to misuse.

## Audit hooks

CI tests for the telemetry contract:

- Run a synthetic AI invocation flow.
- Capture all logger and metrics output.
- Assert no forbidden field appears anywhere.
- Assert the counter cardinality is bounded (e.g., `feature` has a closed set; new values fail the test).

A red-team-style "leakage hunt": craft requests with PII embedded in the redactable fields (already redacted), in headers, in error responses; verify the telemetry pipeline never surfaces them.

## Banned

- Logging request body content.
- Logging response body content.
- Logging headers besides the allowlist.
- Logging IP addresses (only the relay sees them; we don't surface them).
- Logging quota tokens.
- Using a high-cardinality label like `account_id` in any metric.
- Custom metrics not in the catalog.
- Sending traces that link client to gateway through the relay.
- Sentry integration for AI events that captures content.
- Any kind of prompt-response store for "improvement" without explicit user consent.
