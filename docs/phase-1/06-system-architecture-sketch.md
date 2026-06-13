# 06 — System Architecture Sketch (high-level)

This is the rough shape only. Detailed service contracts, data models, and queue topologies belong to Phase 6. Detailed encryption protocols belong to Phase 7. The purpose of this document is to make sure later phases have a coherent target.

## Architectural principles

1. **Server knows as little as possible.** Content is ciphertext. Metadata is sparse. Routing is the minimum required to deliver.
2. **Cell-based deployment.** Region cells are independent. Failure of one cell does not cascade. A user's home cell is determined at signup and is sticky.
3. **Eventually consistent by design, strongly consistent at the message level.** Order within a thread is preserved cryptographically (Double Ratchet message numbers + group sequence numbers) regardless of server reordering.
4. **NATS is the spine, not Postgres.** Postgres is the source of truth for durable state. NATS JetStream is the message bus, fan-out, and offline queue.
5. **Stateless edge, stateful core.** Edge services are horizontally scalable, hold no per-user state. Core services can be stateful but are sharded by user identity hash.
6. **Push is best-effort, pull is authoritative.** A device cannot trust push delivery; on resume it pulls anything it missed.

## Top-level shape

```
            ┌────────────────────────────────────────────┐
            │              Flutter Client                │
            │   (iOS, Android, macOS, Win, Linux, Web)   │
            └─────┬──────────────────┬──────────────┬────┘
                  │ TLS+gRPC         │ WSS          │ HTTPS (media)
                  │                  │              │
            ┌─────▼──────────────────▼──────────────▼────┐
            │            Edge Gateway (Go)              │
            │   - TLS termination, mTLS to internal      │
            │   - rate limit, request shaping            │
            │   - per-region anycast                     │
            └─────┬──────────────────┬──────────────┬────┘
                  │                  │              │
        ┌─────────▼──────┐  ┌────────▼──────┐  ┌────▼─────────┐
        │ Identity & Auth│  │  Routing /    │  │ Media Service │
        │   Service      │  │  Realtime     │  │  (presigned   │
        │   (Go)         │  │  Service (Go) │  │   R2 URLs)    │
        └─────────┬──────┘  └────────┬──────┘  └───────────────┘
                  │                  │                    │
                  │       ┌──────────▼──────────┐         │
                  │       │   NATS JetStream    │         │
                  │       │   (event spine)     │         │
                  │       └──────────┬──────────┘         │
                  │                  │                    │
       ┌──────────▼──────────────────▼──────────┐         │
       │   Persistence Layer (sharded)          │         │
       │     PostgreSQL 16  ·  Redis 7          │         │
       │     pgvector  ·  Meilisearch           │         │
       └─────────────────────────────────────────┘        │
                                                          │
            ┌─────────────────────────────────────────────▼────┐
            │       LiveKit SFU Cluster (per region)           │
            │  E2EE via Insertable Streams for ≤8 participants │
            │  SFU-trust mode for larger calls (UI flagged)    │
            └──────────────────────────────────────────────────┘

  Out-of-band:
    APNs / FCM   ←   Push Service (encrypted payloads)
    OHTTP relay  ←   AI Gateway   ←   Anthropic / OpenAI / on-device fallback
```

## Component responsibilities

### Edge Gateway
- TLS termination, mTLS between edge and core
- IP-level rate limiting, anycast routing
- WebSocket termination for the realtime channel
- Pure pass-through; holds no state, makes no decisions about content

### Identity & Auth
- Account registration (cryptographic identity creation handshake)
- Device pairing and revocation
- Token issuance (short-lived, asymmetrically signed)
- Stores: `account` (id, hashed-email-or-phone, metadata-key-encrypted-blob), `device` (id, public_key, last_seen, status)
- Never stores plaintext phone, email, or contacts

### Routing / Realtime
- Maintains the per-device live socket
- Receives ciphertext envelopes addressed by `account_id` + `device_id`
- Publishes to NATS subject `velix.deliver.<account_id>.<device_id>`
- Pulls offline queue on resume
- Triggers push fan-out to APNs/FCM if the device is offline

### Media Service
- Issues presigned upload URLs to R2
- Stores only ciphertext (client encrypts before upload)
- Stores metadata about size, content-type-class (image/video/etc., never finer), and a deletion-after timestamp
- Issues presigned download URLs scoped per-recipient

### Persistence Layer
- **PostgreSQL** for durable state: accounts, devices, group membership (encrypted), message envelopes (ciphertext + minimal routing meta + TTL), media references.
- **Redis** for hot state: presence, typing, online tokens, rate-limit windows, push deduplication.
- **pgvector** for AI memory at the gateway (only if the user opts in and only for explicit AI invocations; never the user's full history).
- **Meilisearch** for opt-in encrypted search index for large media metadata.

### NATS JetStream
- The event spine. Every domain event is published here.
- Subjects: `velix.deliver.*`, `velix.presence.*`, `velix.audit.*`, `velix.push.*`, `velix.media.*`.
- JetStream provides durability and exactly-once consumer semantics.

### LiveKit
- Self-hosted SFU. One cluster per region.
- E2EE for ≤8-participant calls via Insertable Streams. Server cannot decrypt media.
- SFU-trust mode for larger calls — UI is explicit about the trust change.
- Token issuance from Identity service; LiveKit validates JWT.

### Push Service
- Wraps APNs and FCM behind a single internal API.
- Payloads are encrypted; APNs/FCM see only a routing token + tickle.
- Token rotation on every send to defeat long-term tracking by intermediaries.

### AI Gateway
- Behind Oblivious HTTP relay so the gateway cannot correlate user → request.
- Routes between Anthropic / OpenAI / future providers via LiteLLM.
- Logs are minimal and rotate aggressively.
- Falls back to on-device when network or policy demands.

## Failure-domain analysis (sketch)

| Failure | Effect | Mitigation |
|---|---|---|
| Postgres primary loss | Read-only fallback to replica | Multi-AZ with synchronous replica; failover playbook tested monthly |
| Redis cluster partial | Degrades presence and rate limiting; messaging continues | Redis cluster across 3 AZ; presence is best-effort |
| NATS partial | Slows fan-out, durable queue still drains | NATS clustered with JetStream replication |
| One region down | Users in that region failover to nearest cell | Cell-based deployment, sticky home cell |
| LiveKit cluster loss | Calls fail; messaging unaffected | Cluster per region, client retries another cluster |
| Push provider degradation | Notifications delayed; on-resume sync recovers | Pull authoritative on resume |

## Data residency

- Each cell pins user data to its region.
- EU cell, US cell, APAC cell at minimum at scale.
- A user's data does not leave their cell except for the encrypted backup, which is geo-redundant ciphertext only.

## Open questions for Phase 6 / 7

1. Final Sender Keys / MLS decision for groups. Sender Keys is well-understood and lower-risk; MLS is more elegant for large groups but younger.
2. How aggressively to deploy noise traffic and dummy padding to defeat traffic analysis.
3. Whether to ship a Tor-friendly transport from day 1 or post-1.0.
4. Concrete `pgvector` policy: does AI memory persist server-side at all, even for opt-in cloud queries?
5. How long server-side ciphertext queue retention should be when a device is offline (default 30 days, but worth debate).

## What this sketch is not

It is not a final architecture, an SLA document, a capacity plan, or a security review. Those are Phase 6, 8, and 11.
