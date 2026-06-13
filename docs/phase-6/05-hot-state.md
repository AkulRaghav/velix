# 05 — Hot State (Redis 7)

Redis is for ephemeral state where Postgres latency is too high or where data lifetime is shorter than 60 seconds. Every Redis key has an explicit TTL. Nothing in Redis is the system of record.

## Cluster topology

- 6-node cluster (3 masters + 3 replicas) per region in Stage B.
- Sharding by hash slot; clients route via cluster awareness.
- ACL per service: each service has its own user with permissions only for its key prefixes.

## Key namespaces

We do not use a single Redis cluster as a global namespace. Each service uses a logical database (Redis databases 0-15) and a key prefix. The combination is the key's full identity.

| Service | DB | Prefix |
|---|---|---|
| identity | 0 | `iden:` |
| routing | 1 | `route:` |
| media | 2 | `media:` |
| push | 3 | `push:` |
| call | 4 | `call:` |
| notifier | 5 | `note:` |

## Key catalog

### identity

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `iden:session:<jti>` | string | 15 min | Allowlist of valid session JTIs. The token is valid only if the JTI is present here AND the signature verifies. Revocation = DEL. |
| `iden:rate:<account_id>:<route>` | sorted set | 60 s | Sliding-window per-account rate limit. Score is unix-ms; ZREMRANGEBYSCORE prunes; ZCARD compares to limit. |
| `iden:rate:ip:<ip>:<route>` | sorted set | 60 s | Per-IP rate limit at edge. |
| `iden:reserved-handle:<handle>` | string | 5 min | Soft-reservation during signup before commit. |

### routing

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `route:presence:<account_id>` | set | 60 s | Set of online device_ids for an account. SADD on connect; per-device EX renewal. |
| `route:socket:<device_id>` | string | 60 s | Pod id holding this device's connection. Used by NATS-based fanout to discover routing locality. |
| `route:typing:<conv>:<account>` | string | 6 s | Single-flag boolean. SET with NX EX 6. |
| `route:idem:<account>:<key>` | string | 24 h | Cached SendEnvelope response (idempotency cache). The Postgres `idempotency_keys` table is the durable source; this is a hot read-through. |

### media

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `media:upload-token:<id>` | string | 5 min | Pending presigned-URL state during upload. |
| `media:rate:<account>` | sorted set | 60 s | Upload rate limit. |

### push

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `push:dedupe:<device>:<msg>` | string | 60 s | De-duplicate push delivery (APNs/FCM occasionally double-deliver). |
| `push:rate:<device>` | sorted set | 60 s | Per-device push rate limit (anti-spam). |

### call

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `call:active:<conv>` | string | 12 h | Currently-active call session id for a conversation. |
| `call:livekit-jwt:<call>:<account>` | string | 30 min | Cached LiveKit JWT for an account in a call. |

### notifier

(none — notifier writes to Postgres only; it has no hot-state needs.)

## Patterns

### Sliding-window rate limit

```
ZADD <key> <unix-ms> <unix-ms-as-member>
ZREMRANGEBYSCORE <key> 0 <now-window>
ZCARD <key>
EXPIRE <key> <window-seconds>
```

Atomic via Redis Lua. Returns true if `ZCARD <= limit`.

### Token allowlist

```
SET iden:session:<jti> <account_id>:<device_id> EX 900
```

Revocation: `DEL iden:session:<jti>`. Verification path:
1. Verify JWT signature with identity's public key.
2. Read `iden:session:<jti>`. If absent → revoked.
3. Compare `(account_id, device_id)` from JWT vs Redis value. Mismatch → revoked.

### Per-device socket discovery

When NATS-fanout picks the right routing pod for a recipient device, it could just publish to `velix.deliver.<account>.<device>` and let any pod with a subscription pick it up. We do exactly that; no Redis lookup is required because NATS handles the dispatch via its consumer-group semantics.

The `route:socket:<device>` key exists for diagnostics and for the rare cross-pod operation (e.g., force-disconnecting a device on revoke).

## Failure handling

Redis is best-effort. When Redis is unavailable:

- Presence: degraded — everyone shows offline. Messaging continues.
- Typing: degraded — typing indicators don't fire.
- Rate limits: degraded **closed** — reject the request rather than allow unbounded traffic. (Rate-limit failure → 503 with Retry-After 1 s.)
- Token allowlist: degraded **closed** — sign-in / refresh paths fail until Redis recovers. This is the strict choice; the alternative (degraded-open) means revoked tokens still work during outages.

## Sizing

| Stage | Cluster | Memory budget |
|---|---|---|
| Beta | 3-node | 4 GB |
| Stage B (100k MAU) | 6-node | 24 GB |
| Stage C (1M MAU) | 12-node | 96 GB |

These accommodate the working set: roughly 10 KB per active user (presence + tokens + rate limits).

## Banned

- Storing user content in Redis.
- Storing private keys in Redis.
- Keys without an EXPIRE.
- KEYS * in production code.
- Cross-service Redis access (each service uses only its own DB number and prefix).
- Using Redis as the source of truth for any business state.
- Lua scripts longer than 30 lines.
- `SCAN` over the entire keyspace at runtime (only operational tooling).
