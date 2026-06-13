# 01 — Service Boundaries

## Six services. No more.

Velix's backend is six small services. Each has a single bounded responsibility, owns its own data, and communicates with peers only through gRPC (synchronous) or NATS subjects (asynchronous). No service reaches into another's database. No shared schemas. No "common" service that becomes the everything-bag in two years.

| Service | Responsibility | Owns |
|---|---|---|
| **identity** | Account creation, device pairing, session tokens, key publication | `identities`, `devices`, `prekeys` (Postgres + Redis tokens) |
| **routing** | Persistent socket termination, message envelope routing, presence | per-account fanout state (Redis); ciphertext envelopes (Postgres `message_envelope`) |
| **media** | Presigned URLs, ciphertext upload metadata, retention | `media` table (Postgres) + Cloudflare R2 |
| **push** | APNs / FCM dispatch with encrypted payloads | per-device push tokens (Postgres `push_token`) |
| **call** | LiveKit JWT issuance and call lifecycle telemetry | `call_session` (Postgres); LiveKit cluster |
| **notifier** | Server-side fanout helpers and breadcrumb capture for telemetry | `notification_log` (Postgres, ringed) |

That's the entire backend at 1.0. Spaces, channels, AI gateway, and search live behind feature flags inside these six (Spaces extends `routing`, AI gateway extends `notifier`, etc.) — they do not become new services until the cost of in-process coupling exceeds the cost of operating an additional service.

## What is NOT a service

- A "user service" — accounts and identities live in `identity`. Adding a wrapper service in front of it is process complexity for no boundary clarity.
- A "chat service" / "messaging service" — there is no monolithic messaging service; routing is the only thing that handles messages, and it touches them only as opaque ciphertext envelopes.
- A "notification service" wrapping push — push *is* the notification service. The `notifier` service is for *server-internal* fanout, not for delivering bytes to devices.
- A "gateway" / "API gateway" service — the edge layer (Phase 6 doc 04) does TLS termination + routing only; it has no business logic.

## Why six and not one

A monolith would compile faster and ship faster in week 1. By month 12 it would have:
- The chat code path blocked by a slow image upload.
- A bug in push delivery that could only be deployed alongside identity.
- A single Postgres database that nobody dares to touch.
- A "shared" types module that's an everything-bag.

We accept the operational cost of six services because the per-service cost is small (each is ≤ 4k lines of Go), and the failure-isolation gain is large.

## Why six and not twenty

Microservice maximalism is the opposite failure. We do not split:
- Identity → "auth + handles + profile" (single bounded context, single team).
- Routing → "presence + delivery + read-receipts" (all share the per-device socket state).
- Media → "uploads + thumbnails + retention" (all share the media metadata table).

The rule: **a service exists when it has its own data, its own deploy cadence, or its own failure mode**. Splitting beyond that is theater.

## Service boundaries — physical contracts

Every cross-service interaction is one of:

1. **gRPC call** — synchronous, request-response, typed via `.proto`.
2. **NATS publish** — asynchronous fanout, typed via `.proto` (we use protobuf for NATS payloads too).
3. **Postgres advisory lock** — for the rare distributed lock; never for cross-service data sharing.

Forbidden: shared databases, shared in-memory caches, in-process imports of another service's package.

## Per-service data ownership

```
identity:
  Postgres (database: velix_identity)
    accounts            — id, identity_pubkey_hash, created_at, locale
    handles             — handle (unique), account_id
    devices             — id, account_id, device_pubkey, name, status, paired_at
    prekey_bundles      — account_id, device_id, signed_prekey, one_time_keys
    sessions            — id, account_id, device_id, refresh_token_hash, expires_at
  Redis (db: velix.identity)
    session:<token>     — short-lived auth tokens (JTI allowlist, 15 min TTL)
    rate:<account>:<route> — per-account rate-limit windows

routing:
  Postgres (database: velix_routing, sharded by account_id_hash)
    message_envelope    — id, recipient_account_id, recipient_device_id,
                          ciphertext, sent_at, ttl, attempts
    delivery_state      — message_id, device_id, state, updated_at
  Redis (db: velix.routing)
    presence:<account>           — set of online device_ids, EX 60s
    socket:<device>              — current edge node id (consistent hashing)
    typing:<conv>:<account>      — boolean, EX 6s
    queue:lock:<account>         — fanout-worker advisory lock

media:
  Postgres (database: velix_media)
    media               — id, owner_account, content_type_class, size_bytes,
                          ciphertext_etag, encryption_key_wrapped, expires_at

push:
  Postgres (database: velix_push)
    push_token          — id, device_id, platform (apns|fcm), token, app_bundle, last_used_at
    push_routing_seed   — id, device_id, current_seed, rotated_at
  Redis (db: velix.push)
    dedupe:<device>:<msg> — 60s TTL to defeat APNs/FCM duplicate delivery

call:
  Postgres (database: velix_call)
    call_session        — id, conversation_id, started_at, ended_at, mode (e2ee|sfu_trust)
    call_participant    — call_id, account_id, joined_at, left_at, left_reason

notifier:
  Postgres (database: velix_notifier — ringed; rotates 7d)
    notification_log    — id, account_id, kind, ciphertext, fired_at
```

Each service owns a separate Postgres database (logical, not necessarily physical at small scale). At small scale, all six logical DBs may share a single physical Postgres cluster with separate schemas. At Stage C (1M MAU per Phase 1 doc 08) the routing DB is sharded; the others remain single-shard.

## NATS as the spine

Cross-service notification flows through NATS JetStream. Every subject is namespaced and typed:

| Subject | Publisher | Subscriber | Payload |
|---|---|---|---|
| `velix.account.created` | identity | notifier (audit), media (quota init) | `AccountCreatedEvent` |
| `velix.device.paired` | identity | routing (presence init), push (token bind) | `DevicePairedEvent` |
| `velix.message.delivered` | routing | notifier (delivery audit) | `MessageDeliveredEvent` |
| `velix.message.fanout` | routing (worker) | routing (other shards) | `FanoutEnvelope` |
| `velix.push.requested` | routing | push | `PushRequest` |
| `velix.media.uploaded` | media | notifier (audit) | `MediaUploadedEvent` |
| `velix.call.started` | call | notifier (audit) | `CallStartedEvent` |
| `velix.call.ended` | call | notifier (audit) | `CallEndedEvent` |

Subject naming: `velix.<domain>.<event>`. Past-tense for events, no exceptions. We do not use NATS for command-shaped traffic — commands go via gRPC.

JetStream is configured per stream:
- Replication factor 3
- Max stream size 5 GB per region
- Retention: based on subject (varies; see ops doc Phase 10)

## Failure-domain analysis (sketch)

| Failure | Visible to user? | Mitigation |
|---|---|---|
| identity DB primary loss | Yes (sign-ins fail) | Hot standby in same region; failover ≤ 5 min |
| routing DB shard loss | Yes (one slice of users can't send/receive) | Cross-AZ replication; failover ≤ 5 min |
| Redis presence loss | No (degraded — presence shows everyone offline; messaging continues) | 3-node cluster, replicated |
| NATS partial loss | No (degraded — fanout slows; durable streams drain on recovery) | 5-node JetStream cluster |
| LiveKit cluster loss | Yes (calls fail) | Per-region cluster; client retries another region |
| One service crash | Bounded — only that service's traffic affected | Kubernetes liveness; routing's hot socket reconnects from clients |

## Service boundaries — what each can and cannot do

Concrete rules that govern code review:

1. `routing` may NOT decrypt ciphertext. Anywhere. Not even for "metrics."
2. `media` may NOT decrypt ciphertext.
3. `identity` may NOT see plaintext phone numbers / emails — only their HMAC.
4. `push` may NOT see plaintext message bodies. Notifications are encrypted by the routing/media services before push receives them.
5. `call` may NOT log call participant audio.
6. `notifier` may NOT relay actual user content — only audit metadata.

Each rule is enforced at the gRPC contract level (the proto messages don't carry plaintext) and at the code-review level.

## Cross-service auth

Internal calls between services use mTLS + a short-lived service token (issued by an internal CA, rotated daily). Services do not use long-lived API keys.

External calls (client → edge → service) use OIDC bearer tokens issued by `identity` after a successful auth. Tokens carry:
- `sub` = account_id (UUID, not username)
- `did` = device_id
- `aud` = the service the token is presented to
- `exp` = 15 minutes
- `jti` = randomly-generated, allowlisted in Redis until expiry

Tokens are signed by `identity`'s rotating Ed25519 key. Public key is published; every service verifies independently.

## Banned

- Shared schemas across services (each service's `*.proto` is its own).
- A "shared types" Go module that becomes an everything-bag.
- Cross-service direct Postgres reads.
- Synchronous chains longer than two services (`A → B → C` is fine; `A → B → C → D` triggers a redesign).
- Long-lived service-to-service credentials.
- Plaintext persistence of user content.
- Storing private cryptographic keys in any backend service.
