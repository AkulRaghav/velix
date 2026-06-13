# 04 — Persistence (Postgres)

Each service owns its own logical database. At launch they may share a physical cluster (with `CREATE DATABASE` per service); at Stage C they're separate clusters with the routing DB sharded.

## Driver and tooling

- **pgx/v5** for the connection driver. No `database/sql`; pgx exposes typed parameter binding and copy-from for batch writes.
- **sqlc** for query generation. SQL files in `internal/queries/*.sql` produce typed Go structs.
- **goose** for migrations.
- No ORM. ORMs hide query plans, encourage N+1, and make audit harder.

## Conventions

- Primary keys: **ULID** stored as `text` (sortable, monotonic; works with cursor pagination directly).
- Timestamps: `timestamptz` with `default now()`. We do not store wall-clock times in any local tz.
- Soft deletes: `deleted_at timestamptz` column, only on tables where users can undo. Most tables hard-delete and rely on the audit log.
- Booleans: `boolean`, not `int`. We do not encode tri-states with `int4`.
- Foreign keys: declared and enforced. We do not optimize them away "for performance."
- `NOT NULL` is the default. Columns are nullable only when the schema demands it.
- All ciphertext columns are `bytea`, with explicit MAC-tag inclusion (the row stores `cipher || mac`).

## Per-service schema

### identity (`velix_identity`)

```sql
CREATE TABLE accounts (
  id                     text PRIMARY KEY,                -- ULID
  identity_pubkey_hash   bytea NOT NULL UNIQUE,           -- 32 bytes (SHA-256 of Ed25519 public key)
  locale                 text NOT NULL DEFAULT 'en',
  status                 text NOT NULL DEFAULT 'active',  -- active|suspended|deleted
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE handles (
  handle      text PRIMARY KEY,                            -- lowercased, ascii
  account_id  text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  reserved_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_handles_account_id ON handles(account_id);

CREATE TABLE devices (
  id                  text PRIMARY KEY,
  account_id          text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_pubkey       bytea NOT NULL,                      -- 32 bytes (X25519 public key)
  device_pubkey_hash  bytea NOT NULL UNIQUE,
  name                text NOT NULL,
  platform            text NOT NULL,                       -- ios|android|macos|windows|linux|web
  status              text NOT NULL DEFAULT 'active',      -- active|paused|revoked
  paired_at           timestamptz NOT NULL DEFAULT now(),
  last_seen_at        timestamptz NOT NULL DEFAULT now(),
  attestation_sig     bytea NOT NULL                       -- Ed25519 sig from identity over device_pubkey
);
CREATE INDEX idx_devices_account_id ON devices(account_id) WHERE status = 'active';

CREATE TABLE prekey_bundles (
  account_id    text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_id     text NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  signed_prekey bytea NOT NULL,
  signed_at     timestamptz NOT NULL,
  PRIMARY KEY (account_id, device_id)
);

CREATE TABLE one_time_prekeys (
  id          bigserial PRIMARY KEY,
  account_id  text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_id   text NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  prekey      bytea NOT NULL,
  consumed_at timestamptz
);
CREATE INDEX idx_otpk_unconsumed ON one_time_prekeys(account_id, device_id) WHERE consumed_at IS NULL;

CREATE TABLE refresh_sessions (
  id                  text PRIMARY KEY,                    -- ULID
  account_id          text NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_id           text NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  refresh_token_hash  bytea NOT NULL,                      -- HMAC of the refresh token
  user_agent          text,
  expires_at          timestamptz NOT NULL,
  revoked_at          timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_sessions_account_id ON refresh_sessions(account_id);
CREATE INDEX idx_refresh_sessions_expires_at ON refresh_sessions(expires_at) WHERE revoked_at IS NULL;
```

### routing (`velix_routing`)

The hot table. Sharded by `recipient_account_id` hash starting at Stage C.

```sql
CREATE TABLE message_envelope (
  id                    text PRIMARY KEY,                   -- ULID, monotonic
  recipient_account_id  text NOT NULL,
  recipient_device_id   text NOT NULL,
  -- Sealed sender: the server does not learn the sender from this row.
  -- The sender's identity is inside the ciphertext.
  ciphertext            bytea NOT NULL,
  enqueued_at           timestamptz NOT NULL DEFAULT now(),
  ttl_at                timestamptz NOT NULL,               -- 30 days default
  attempts              int NOT NULL DEFAULT 0,
  last_attempt_at       timestamptz,
  delivered_at          timestamptz                         -- null until acked by recipient
);

-- Hot lookups by recipient device:
CREATE INDEX idx_envelope_recipient_undelivered
  ON message_envelope(recipient_device_id, enqueued_at)
  WHERE delivered_at IS NULL;

-- TTL sweeper:
CREATE INDEX idx_envelope_ttl_at ON message_envelope(ttl_at);

CREATE TABLE delivery_state (
  message_id  text NOT NULL,
  device_id   text NOT NULL,
  state       text NOT NULL,                                -- pending|delivered|read
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, device_id)
);

CREATE TABLE idempotency_keys (
  account_id     text NOT NULL,
  key            text NOT NULL,
  response_blob  bytea NOT NULL,                            -- the cached response, marshalled
  created_at     timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL,
  PRIMARY KEY (account_id, key)
);
CREATE INDEX idx_idem_expires_at ON idempotency_keys(expires_at);
```

The `message_envelope` table grows to terabytes at scale. Strategy:

- TTL pruning: a daily cronjob deletes rows where `ttl_at < now()`.
- Devices acknowledge delivery; we set `delivered_at` and the row becomes deletion-eligible after the retention window.
- Stage C splits this table by `recipient_account_id_hash mod N` across N=8 → 64 shards. The split is done with citus or hand-rolled application-level routing depending on the operational fit.

### media (`velix_media`)

```sql
CREATE TABLE media (
  id                       text PRIMARY KEY,
  owner_account_id         text NOT NULL,
  content_type_class       text NOT NULL,                   -- image|video|audio|file (no finer)
  size_bytes               bigint NOT NULL,
  ciphertext_etag          text NOT NULL,                   -- R2 ETag of the ciphertext object
  ciphertext_object_key    text NOT NULL,                   -- R2 key
  encryption_key_wrapped   bytea NOT NULL,                  -- per-recipient wrapped DEKs (concat'd)
  uploaded_at              timestamptz NOT NULL DEFAULT now(),
  expires_at               timestamptz NOT NULL,            -- retention boundary
  deleted_at               timestamptz
);

CREATE INDEX idx_media_owner ON media(owner_account_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_media_expires_at ON media(expires_at) WHERE deleted_at IS NULL;
```

### push (`velix_push`)

```sql
CREATE TABLE push_token (
  id            text PRIMARY KEY,
  device_id     text NOT NULL UNIQUE,
  account_id    text NOT NULL,
  platform      text NOT NULL,                              -- apns|fcm
  token         text NOT NULL,                              -- the platform-specific token (rotates)
  app_bundle    text NOT NULL,
  last_used_at  timestamptz NOT NULL DEFAULT now(),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_push_token_account_id ON push_token(account_id);

-- Per-device routing seed used to generate per-message routing tokens.
-- The token sent in the push payload is HMAC(seed, message_id).
CREATE TABLE push_routing_seed (
  device_id   text PRIMARY KEY REFERENCES push_token(device_id) ON DELETE CASCADE,
  seed        bytea NOT NULL,                               -- 32 bytes
  rotated_at  timestamptz NOT NULL DEFAULT now()
);
```

### call (`velix_call`)

```sql
CREATE TABLE call_session (
  id                text PRIMARY KEY,
  conversation_id   text NOT NULL,
  mode              text NOT NULL,                          -- e2ee|sfu_trust
  livekit_room      text NOT NULL UNIQUE,
  started_at        timestamptz NOT NULL DEFAULT now(),
  ended_at          timestamptz
);

CREATE INDEX idx_call_active_by_conv ON call_session(conversation_id) WHERE ended_at IS NULL;

CREATE TABLE call_participant (
  call_id      text NOT NULL REFERENCES call_session(id) ON DELETE CASCADE,
  account_id   text NOT NULL,
  device_id    text NOT NULL,
  joined_at    timestamptz NOT NULL DEFAULT now(),
  left_at      timestamptz,
  left_reason  text,                                        -- left|kicked|timeout
  PRIMARY KEY (call_id, account_id, device_id)
);
```

### notifier (`velix_notifier`)

A small ringed audit table. Rotates weekly via partitioning.

```sql
CREATE TABLE notification_log (
  id          text PRIMARY KEY,                              -- ULID
  account_id  text,                                          -- nullable (system events)
  kind        text NOT NULL,
  metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,            -- never PII
  fired_at    timestamptz NOT NULL DEFAULT now()
) PARTITION BY RANGE (fired_at);
```

Weekly partitions automatically created by a cron job; partitions older than 7 days are dropped.

## Indexing discipline

Every query in `internal/queries/*.sql` has an `EXPLAIN` plan in the corresponding test file. We don't add indexes "just in case"; we add them because a documented query needs them. Unused indexes are removed every quarter.

## Connection pooling

- pgx pool: 10 connections per service replica baseline, scales to 50.
- Aggregate pool size capped at `(8 × cores)` per Postgres primary.
- `pgbouncer` in transaction-pooling mode in front of Postgres at Stage B+.

## Migrations

Every migration is paired (up + down). We test migrations forward-then-backward in CI on a snapshot of the previous schema:

```
migrations/
  001_init_accounts.sql
  001_init_accounts.down.sql
  002_add_handles.sql
  002_add_handles.down.sql
```

Migrations that destroy data require a separate PR and a written rollback plan.

## Backups and PITR

- Postgres WAL archived to S3 continuously.
- Daily snapshot retained 30 days; weekly retained 6 months.
- Point-in-time recovery target ≤ 5 min RPO; tested monthly.
- Restore drill tested quarterly per region.

## Banned

- Triggers (logic in code, not in the database).
- Stored procedures.
- Generated columns that hide query intent.
- Cross-service joins (each service owns its DB).
- N+1 queries — sqlc + explicit query design prevent this.
- `SELECT *` in production code (sqlc enforces explicit columns).
- Migrations that mix DDL and DML in the same transaction without an explicit reason.
- `text[]` arrays where a join table would do.
- `jsonb` columns for structured data we own (only for opaque attachments).
- Indexes covering columns that are never queried.
