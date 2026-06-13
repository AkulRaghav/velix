# 06 — NATS Subjects & Events

NATS JetStream is the asynchronous spine. Every cross-service event flows here. Subjects are typed via Protobuf payloads in `proto/velix/events/v1/`.

## Subject grammar

```
velix.<domain>.<verb-past-tense>
velix.deliver.<account_id>.<device_id>          ← per-device delivery (high cardinality)
```

Past tense for events. We do not emit `velix.message.send` (that's a command); we emit `velix.message.delivered` (event of fact).

## The complete subject map

### Account / device lifecycle

| Subject | Publisher | Subscribers | Stream |
|---|---|---|---|
| `velix.account.created` | identity | notifier | `lifecycle` |
| `velix.account.suspended` | identity (rare) | routing (drop sockets), push (clear tokens), notifier | `lifecycle` |
| `velix.account.deleted` | identity | routing, push, media (purge), notifier | `lifecycle` |
| `velix.device.paired` | identity | routing (presence init), push (token slot), notifier | `lifecycle` |
| `velix.device.revoked` | identity | routing (drop socket), push (clear token), notifier | `lifecycle` |

### Message routing

| Subject | Publisher | Subscribers | Stream |
|---|---|---|---|
| `velix.deliver.<account_id>.<device_id>` | routing (sender pod) | routing (recipient pod) | `delivery` |
| `velix.message.delivered` | routing (recipient pod, on ack) | notifier | `audit` |
| `velix.message.read` | routing (recipient pod) | notifier | `audit` |
| `velix.push.requested` | routing (when recipient device offline) | push | `push_queue` |

### Media

| Subject | Publisher | Subscribers | Stream |
|---|---|---|---|
| `velix.media.uploaded` | media | notifier (audit) | `audit` |
| `velix.media.deletion-requested` | media | media internal worker | `media_deletion` |

### Call

| Subject | Publisher | Subscribers | Stream |
|---|---|---|---|
| `velix.call.started` | call | notifier, push (call ringing) | `call_lifecycle` |
| `velix.call.ended` | call | notifier | `call_lifecycle` |
| `velix.call.participant-joined` | call | notifier | `call_lifecycle` |
| `velix.call.participant-left` | call | notifier | `call_lifecycle` |

### Push

| Subject | Publisher | Subscribers | Stream |
|---|---|---|---|
| `velix.push.delivered` | push | notifier | `audit` |
| `velix.push.failed` | push | notifier (telemetry) | `audit` |

## JetStream configuration

| Stream | Subjects | Retention | Replication |
|---|---|---|---|
| `delivery` | `velix.deliver.>` | 30 days | 3 |
| `lifecycle` | `velix.account.*`, `velix.device.*` | 365 days | 3 |
| `push_queue` | `velix.push.requested` | 7 days | 3 |
| `media_deletion` | `velix.media.deletion-requested` | 30 days | 3 |
| `call_lifecycle` | `velix.call.*` | 30 days | 3 |
| `audit` | `velix.*.delivered`, `velix.*.read`, `velix.media.uploaded`, `velix.push.*` | 7 days | 3 |

The `delivery` stream is the largest and most performance-critical. It is partitioned across 8 consumers per region (one per routing pod replica) using NATS's `Push` consumer with `MaxAckPending=1000`.

## Payload format

Every NATS payload is Protobuf-encoded. The schema lives in `proto/velix/events/v1/`. Example:

```proto
syntax = "proto3";
package velix.events.v1;

message DevicePairedEvent {
  string event_id    = 1;             // ULID for dedup
  string account_id  = 2;
  string device_id   = 3;
  google.protobuf.Timestamp at = 4;
}

message MessageDeliveredEvent {
  string event_id     = 1;
  string envelope_id  = 2;
  string device_id    = 3;
  google.protobuf.Timestamp at = 4;
}

message PushRequest {
  string event_id      = 1;
  string device_id     = 2;
  bytes  encrypted_payload = 3;       // already-encrypted by routing
  string routing_token = 4;           // HMAC of message_id with per-device push seed
  google.protobuf.Timestamp expires_at = 5;
}
```

## Headers

Every NATS message carries headers:

- `Content-Type: application/protobuf`
- `Velix-Event-Type: <fqn>` (e.g., `velix.events.v1.DevicePairedEvent`)
- `Velix-Trace-Id: <otel-trace-id>` (for tracing across the async boundary)
- `Velix-Idempotency-Key: <event_id>` (for consumer-side dedup)

## Idempotent consumers

Every consumer must be idempotent on `event_id`. Mechanisms:

- For database writes: `INSERT ... ON CONFLICT DO NOTHING` keyed on event_id.
- For pure side-effects (e.g., push send): a Redis dedup key `dedupe:<service>:<event_id>` with TTL 1h.

A consumer that processes the same event twice **must produce no observable side effect on the second invocation**.

## At-least-once delivery

JetStream gives at-least-once. We do not pretend otherwise. The idempotent-consumer rule above is the contract that makes at-least-once safe.

We do not use exactly-once semantics (NATS supports them with caveats; the operational complexity isn't worth it for our scale).

## Backpressure & ack policies

Per-consumer:

- `MaxAckPending`: 1000 for delivery; 100 for everything else.
- `AckWait`: 30 s — if the consumer doesn't ack within 30 s, NATS re-delivers.
- `MaxDeliver`: 6 — after 6 failed deliveries, the message is dead-lettered to a per-stream `<stream>.dlq`.

Dead-lettered messages are alerted-on (Phase 6 doc 10) and inspected manually.

## Cross-region

NATS streams are mirrored cross-region for disaster recovery. They are NOT used for cross-region live messaging — that's solved by sticky cells per Phase 1 doc 06. Mirroring's purpose is purely DR.

## Tracing across NATS

Every publisher injects the OTel trace-id and span-id into the message headers. Every consumer extracts and continues the trace. A single message's life shows up as one Tempo trace from `routing.SendEnvelope` → NATS publish → recipient routing pod → `EnvelopeDelivery` to client.

This is invaluable for debugging "the message arrived 12 seconds late" type issues.

## Banned

- Subject names without `velix.` prefix.
- Verbs as subjects (use past-tense events).
- Wildcard subscriptions in production code outside the routing service's `velix.deliver.>`.
- Putting user content (decryptable bodies) in event payloads.
- Using NATS as the system of record. The DB is. NATS is the message bus.
- Mixing protobuf and JSON payloads on the same subject.
- Using `Pull` consumers in the hot path (`Push` is faster).
- Subjects with high-cardinality tokens beyond `<account>.<device>` (we do not subject-by-message-id).
