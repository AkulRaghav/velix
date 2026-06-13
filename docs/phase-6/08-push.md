# 08 — Push Notifications

The push service exists for one reason: tickle a device into reconnecting when it has an offline message. We do **not** rely on push to deliver content. The content is in `routing`'s `message_envelope` table; push is the doorbell.

## Architecture

```
routing  →  velix.push.requested  (NATS)  →  push  →  APNs / FCM
```

The push service consumes from NATS, encrypts the payload (already encrypted by routing — see below), and dispatches via APNs (iOS, macOS) or FCM (Android, web).

## Payload contents

What APNs/FCM see in transit:

```json
{
  "aps": {
    "alert": "",        // empty; the device decrypts the real content
    "mutable-content": 1,
    "content-available": 1
  },
  "v": {
    "rt": "<routing_token_b64>",   // HMAC(seed, message_id), unique per push
    "ev": "<encrypted_payload_b64>"
  }
}
```

The actual notification text the user sees on the lock screen is rendered by the device's notification service extension after decrypting `ev` locally. Until that decrypts:

- iOS shows "Velix"
- Android shows "New message"

This is the bargain: we sacrifice rich preview for privacy, by default. Users who want rich preview can opt in (Phase 7 follow-up; Phase 6 is the encrypted-payload-only baseline).

## Routing token

Per-device `push_routing_seed` (32 bytes, in Postgres `push_routing_seed`). For each push, the service computes:

```
routing_token = HMAC-SHA256(seed, message_id) [first 16 bytes]
```

The seed rotates on every push (the next push uses a new seed). This defeats long-term tracking by APNs / FCM intermediaries.

## Encrypted payload

The `ev` field is what the routing service produced — already encrypted to the recipient device. The push service does NOT encrypt; it only forwards. The push service's view of the bytes is purely opaque.

The encryption uses a per-device push key derived from the device's master key (Phase 7). The push service does not have access to that key.

## Token lifecycle

```
Client (Phase 5):
  Acquires APNs/FCM token.
  Calls push.RegisterToken(device_id, platform, token).
    → push service inserts into push_token; binds to device_id.

Token rotates (platform-driven):
  Client detects new token via system callback.
  Calls push.RegisterToken with the new token.
    → push service updates the row.

Token invalidated (uninstall, OS reset):
  Platform feedback (APNs response 410 / FCM unregistered).
  push service marks token deleted.
```

We do not garbage-collect aggressively. A token that 410s twice is retired.

## Dispatch path

```
push consumer reads velix.push.requested:
  1. Verify event_id not in dedupe Redis (within last 60s).
  2. Look up push_token by device_id.
     If none: log push_token_missing; ack.
  3. Compute routing_token (rotating seed).
  4. Update seed (atomic via Postgres UPDATE ... RETURNING).
  5. Build platform-specific payload.
  6. POST to APNs (HTTP/2) or FCM (HTTP/1.1).
  7. Handle response:
       200 / OK → metric, ack
       410 / Unregistered → mark token deleted, ack
       429 → exponential backoff retry up to 6
       5xx → exponential backoff retry up to 6
       4xx other → log and ack (don't retry permanent errors)
  8. Publish velix.push.delivered.
```

## Concurrency

A single push pod handles ~5,000 pushes/sec via:
- HTTP/2 connection pool to APNs (16 connections).
- HTTP/1.1 pool to FCM (32 connections).
- Worker goroutines = 256.

Push throughput is bounded by upstream APNs/FCM rate limits more than our own.

## Rate limiting

Per-device dedupe (Redis) prevents APNs/FCM from receiving duplicates. Per-account rate limiting prevents one chatty contact from spamming push:

- Max 60 pushes/minute per device.
- Beyond that, pushes are dropped (the message is still delivered when the device reconnects; only the push doorbell is throttled).

## Silent push (background data)

iOS: `content-available: 1` triggers a background fetch. We use this to drive the device's `velix_data` sync queue to drain even when the user hasn't opened the app.

Android: data-only messages are the default; the device handles them in a Service.

## Voice / video call ringing

Calls use a different push class:

- iOS: VoIP push via PushKit (CallKit-integrated). Wakes the app even from killed state.
- Android: high-priority FCM with `delivery: priority=10`.

Call pushes carry a `kind: "call"` field that the device's notification handler routes to CallKit / Telecom UI.

## Failure handling

| Failure | Response |
|---|---|
| Token unregistered (410) | Mark deleted; do not retry. |
| Token invalid format | Log; ack. (Bug, not transient.) |
| APNs/FCM 5xx | Exponential backoff up to 6 retries. |
| APNs/FCM 429 | Honor `Retry-After`. |
| Provider down (timeout) | Circuit-break for 30 s; queue grows on NATS. |

## Monitoring

```
velix_push_dispatched_total{platform, outcome}
velix_push_dispatched_seconds{platform}        histogram
velix_push_token_unregistered_total{platform}
```

Alert: dispatch success rate < 95% for 5 minutes pages on-call.

## Banned

- Sending plaintext message bodies in pushes.
- Using FCM topics (we route per-device).
- Logging the push token plaintext.
- Sharing push tokens between services.
- Long-lived dedupe windows (we use 60 s; longer makes legitimate retries fail).
- Per-account push fanout server-side. Push is per-device; routing knows the per-device list.
- Serving push from a SaaS provider that decrypts the payload (Velix's encryption is end-to-end; SaaS providers like OneSignal would defeat this).
