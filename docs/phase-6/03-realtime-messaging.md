# 03 — Realtime Messaging

The hot path. The single most important service to get right because it owns:
- Per-device persistent socket termination
- Inbound message envelope ingestion
- Outbound delivery to the connected device
- Presence updates (typing, online)
- Read-receipt fanout
- Triggering push when devices are offline

## Wire shape

Clients open a single bidirectional gRPC stream to `routing.Subscribe`. The stream multiplexes all of:

| Inbound from server | Outbound from client |
|---|---|
| `EnvelopeDelivery` (a new ciphertext envelope addressed to this device) | `Ack` (the device has stored the envelope) |
| `PresenceUpdate` (a peer in a watched conversation came online / went offline / typing) | `Ping` (heartbeat, every 25s) |
| `ReadReceipt` (a peer device read a message we sent) | `Subscribe` (start watching presence on a conversation) |
| `Pong` (heartbeat response) | `Unsubscribe` |

Independently, the client may call `routing.SendEnvelope` for each outbound message via a separate unary RPC. We do not pipe outbound messages through the `Subscribe` stream because:
- Send is a write that needs durable confirmation; a stream-level error vs. RPC-level error is different.
- It allows clients to send while the subscribe stream is reconnecting.

## Heartbeat

Every 25 seconds the server sends a ping. Clients reply within 10 seconds. Clients that go silent for 35 seconds have their socket dropped; presence is removed; offline-queued envelopes await reconnect.

This timing is tuned to survive carrier NAT timeouts (typically 30s for TCP) without firing redundant heartbeats on healthy connections.

## Topology

```
┌──────────┐
│ Flutter  │
│ device A │
└────┬─────┘
     │ HTTP/3 + gRPC stream (mTLS to edge, plaintext within VPC)
┌────▼──────────┐
│ edge (envoy)  │  ─── consistent-hashes by device_id to the routing pod
└────┬──────────┘
     │
┌────▼─────────────────────────────────────────┐
│ routing pod  (one of many)                   │
│   ├─ socket multiplexer (per-pod)            │
│   ├─ per-device socket goroutine             │
│   └─ outbound writer goroutine               │
└────┬─────────────────────────────────────────┘
     │ subscribes:  velix.deliver.<account>.<device>
     │ publishes:   velix.message.fanout, velix.push.requested
┌────▼─────────────────────────────────────────┐
│ NATS JetStream                                │
└─────────────────────────────────────────────┘
     │
┌────▼─────────────────────────────────────────┐
│ Postgres velix_routing                        │
│   - message_envelope                          │
│   - delivery_state                            │
└──────────────────────────────────────────────┘
```

Edge envoy uses consistent hashing on `device_id` (extracted from the client's bearer token) to route every connection from a device to the same routing pod for the duration of the connection. This gives us locality without forcing global state.

## Send path

Client → routing.SendEnvelope:

```
1. Edge auth interceptor validates the bearer token (cached for 60s).
2. routing handler:
   a. Validates ciphertext size (≤ 64 KB).
   b. Validates idempotency_key against (account, key) → cached response if replay.
   c. Begins Postgres transaction:
        INSERT INTO message_envelope (recipient_account_id, recipient_device_id, ciphertext, ttl_at)
        VALUES ($1, $2, $3, now() + interval '30 days')
        for EACH recipient device.
        INSERT INTO idempotency_keys ON CONFLICT DO NOTHING.
      Commits.
   c'. The transaction is per-account, single-row writes. p99 < 50 ms.
   d. Publishes velix.deliver.<account>.<device> to NATS for each recipient device.
   e. Returns OK with the new message id.
3. Recipient routing pods receive the NATS message.
4. If recipient device is connected:
      Push EnvelopeDelivery onto its outbound stream channel.
      Mark delivery_state = 'delivered' on Ack receipt.
5. If not connected:
      Publish velix.push.requested for the push service.
      Envelope stays in message_envelope until next reconnect.
```

p99 send-to-NATS-publish: ≤ 80 ms.
p99 NATS-publish-to-recipient-pod-receive: ≤ 30 ms (intra-region).
p99 recipient-pod-to-device delivery (assuming connection): ≤ 16 ms.
**End-to-end intra-region p99 target: ≤ 250 ms.**

## Receive path on reconnect

On `Subscribe`, the routing pod:
1. Verifies the bearer token.
2. Reads recent envelopes for `device_id` from `message_envelope` where `delivered_at IS NULL ORDER BY enqueued_at`.
3. Streams them to the device.
4. Subscribes to `velix.deliver.<account>.<device>` on NATS for live messages.
5. Continues until disconnection.

The Postgres read uses the partial index `idx_envelope_recipient_undelivered`. p99 < 20 ms even at large queue depth.

## Acks

Clients ack each envelope with the message id. The server marks `delivered_at = now()` and `delivery_state.state = 'delivered'`. Acks are batched by the client (every 10 envelopes or 500 ms) for throughput.

If the server doesn't receive an ack within 30 seconds of delivery, the envelope is treated as un-delivered and re-streamed on the next reconnect. Idempotency at the client side (the client deduplicates by message id before storing locally) makes this safe.

## Read receipts

Read receipts are themselves messages, sent through the same envelope pipeline. The client emits a special envelope addressed to the original sender with payload `{kind: ReadReceipt, message_id}`. This is intentionally simple: read receipts are E2E-encrypted just like everything else.

## Presence

A presence cell is `presence:<account_id>` in Redis with EX 60s. Devices ping every 25s; the routing pod renews the TTL. When a device disconnects, the TTL expires; subscribers see "offline" within ≤ 60s.

For typing indicators, the client emits a `ReportTyping` RPC (separate from the stream). The routing pod sets `typing:<conv>:<account>` in Redis with EX 6s. Subscribers to `Presence` for that conversation receive a `PresenceUpdate{typing: true}`.

The 6-second TTL aligns with the client's 4-second auto-clear after no further updates.

## Fanout to peers

When account A sends to account B:
- Server enqueues one envelope per *recipient device*. If B has 3 devices, 3 rows are written.
- For each, NATS publishes `velix.deliver.<B-account>.<B-device-N>`.
- B's connected device(s) receive immediately; offline ones get the envelope from Postgres on reconnect.

The fanout is idempotent: re-sending the same `(idempotency_key, recipient_device)` pair is a no-op via the unique constraint on `idempotency_keys`.

## Group fanout

Group conversations work the same way: the sender's client knows the recipient device list (from the group's Sender Keys distribution; Phase 7 detail) and addresses one envelope per device. The server has no concept of "group" — it just has many recipients per send.

This keeps the server's data model trivially simple and means the server cannot derive group membership from server-side state.

## Backpressure

Per-device outbound queue is bounded at 256 envelopes. If the device is slow consuming, the pod stops draining from NATS for that device. The NATS consumer group buffers (configurable max ack-pending). Beyond that, the durable stream holds the messages.

Postgres queue depth is unbounded but TTL-pruned. A device offline for 30 days loses its older messages.

## Read-only paths

- `routing.MarkAsRead(conversation_id)` — bulk read-receipt; server enqueues read-receipt envelopes for the conversation peers.
- `routing.GetUndelivered(device_id)` — convenience query for diagnostics; not used in the hot path.

## Failure scenarios

| Failure | Effect | Handling |
|---|---|---|
| Routing pod crashes | All sockets to that pod drop | Edge re-hashes connections; clients reconnect within 1-2 s |
| NATS partial loss | Live delivery stalls; durable stream persists | Stream recovers; clients re-fetch from Postgres on reconnect |
| Postgres primary loss | Writes fail; reads continue from replica | HA failover; retry via send-side idempotency |
| Edge envoy loss in a region | New connections fail; existing hold | Anycast routes to neighbor region; clients reconnect |
| Device with stale token | Auth fails | Client refreshes token via identity service |

## Performance targets

| Metric | Target |
|---|---|
| `SendEnvelope` p99 (server-side handler time) | ≤ 80 ms |
| `Subscribe` initial drain (10 envelopes) p99 | ≤ 50 ms |
| Per-pod concurrent connections | 5,000 sustained |
| Per-pod CPU at peak | ≤ 60% (leaving headroom for spikes) |
| Memory per connection | ≤ 64 KB |

## Banned

- Reading ciphertext fields server-side. Any.
- Storing the sender's account id in `message_envelope` (use Sealed Sender; the recipient extracts the sender from inside the ciphertext).
- Routing decisions based on conversation type — the server does not know what type of conversation a message belongs to.
- Persisting presence/typing state to Postgres. They are ephemeral hot state; Redis only.
- Long-running transactions across the send path (single-shot, single-row INSERTs).
- HTTP long-polling fallback. We use HTTP/3 + gRPC bidi; there is no LP path.
