# 04 — Offline-First Storage

Velix is offline-first by architecture. Every screen renders from local data; network is a sync mechanism, not a render path. Latency in a chat list is unacceptable; the chat list is **always** rendered from the local database.

## Stack

- **drift 2.x** for typed SQLite. Compile-time-safe queries, reactive streams, migrations.
- **sqlcipher_flutter_libs** for encrypted SQLite at rest (256-bit AES).
- **flutter_secure_storage** for the SQLCipher key (wrapped by hardware-backed Keychain/Keystore).
- **path_provider** for OS-appropriate writable directory location.

The application database is encrypted at rest. The encryption key is generated on first launch, stored in the OS keychain, and retrieved on every app launch.

## Schema overview

```
identities      (id, public_key, created_at, ...)
devices         (id, identity_id, public_key, paired_at, last_seen, ...)
conversations   (id, kind, title, room_color_hash, trust_state,
                 last_activity_at, unread_count, archived_at, ...)
participants    (conversation_id, identity_id, role)
messages        (id, conversation_id, sender_id, ciphertext, sent_at,
                 received_at, status, kind, reply_to, ...)
reactions       (message_id, identity_id, emoji, reacted_at)
media           (id, message_id, ciphertext_url, content_type_class,
                 size_bytes, encryption_key_wrapped, ...)
voice_envelopes (message_id, samples)        ← waveform shape
stories         (id, author_identity_id, ciphertext_url, expires_at, ...)
story_views     (story_id, viewer_identity_id, viewed_at)
spaces          (id, name, owner_identity_id, room_color_hash, ...)
space_members   (space_id, identity_id, role)
notifications   (id, kind, payload_ciphertext, received_at, read_at)
preferences     (key, value)
sync_state      (entity_kind, last_sync_token, last_synced_at)
```

Each table has a typed drift `Table` definition in `velix_data/lib/src/db/`. Queries are typed.

## Reactive streams from the DB

Drift exposes `select(...).watch()` returning `Stream<List<Row>>` that fires on any insert/update/delete affecting the query. Repositories wrap these:

```dart
@override
Stream<List<Conversation>> watchAll() {
  return (_db.select(_db.conversations)
        ..where((c) => c.archivedAt.isNull())
        ..orderBy([(c) => OrderingTerm.desc(c.lastActivityAt)]))
      .watch()
      .map((rows) => rows.map(_toEntity).toList(growable: false));
}
```

Riverpod `StreamNotifier`s consume these. The presentation layer never knows whether the data came from RAM, disk, or network — it just knows the stream.

## Write-then-sync pattern

Mutations write to the local DB first, then enqueue a sync job. The UI updates from the DB stream before the network round-trip completes — that's the offline-first feel.

```
User taps Send
    ↓
Repository.sendMessage(text)
    ↓
1. Insert message row (status: pending)       ← DB stream fires
                                               ← UI updates instantly
    ↓
2. Enqueue OutboundMessageJob in sync_queue
    ↓
3. SyncWorker picks up the job (background)
    ↓
4. Encrypt + send via gateway
    ↓
5. Update message row (status: sent)          ← DB stream fires
                                               ← UI tick → ✓
```

If the device is offline, step 4 fails; the job stays in the queue and retries with exponential backoff. The user sees their message immediately with a "sending" indicator until it commits.

## Sync queue

The `sync_queue` table is the durable list of operations that need to reach the server. Each entry has:

- `id` (ULID, sortable)
- `kind` (enum: `OutboundMessage`, `MarkAsRead`, `Reaction`, `Profile`, ...)
- `payload_ciphertext` (the actual content, encrypted)
- `attempts`, `next_retry_at`, `last_error`
- `created_at`

A single `SyncWorker` runs in a background isolate, draining the queue. Only one is active per app instance (lock-coordinated via the queue's `claimed_until` timestamp).

Retries:
- Network errors: exponential backoff with jitter, max 6 retries over 24 hours
- Authentication errors: pause queue, prompt re-auth
- Permanent errors (recipient deleted, etc.): mark failed, surface to UI
- Idempotent by `id`; the server dedupes

## Key rotation handling

When key material rotates (multi-device add/remove, periodic ratchet), we don't re-encrypt the local DB row-by-row. Instead, the row carries a `key_epoch` column; queries decrypt with the appropriate epoch's keys. Old keys are kept in the secure store for as long as old messages exist, then garbage-collected.

This avoids a multi-minute "re-encrypting your messages" pause that would expose the key in memory at scale.

## Migrations

drift's migrator is used. Each schema version has an explicit `MigrationStrategy.onUpgrade` step. We never delete a column without a deprecation window — migrations preserve data through at least three versions before removal.

A migration that fails leaves the DB at the previous version and raises a recoverable error to bootstrap. The app shows a one-time "Updating data store" screen and retries on the next launch (this is exceptional; in practice we test migrations exhaustively in CI).

Migration tests load a known-good DB at version N, run the migrator, verify version N+1 contents.

## Backup / restore

A `Backup` artifact is the entire encrypted DB plus a wrapped key sealed by the user's recovery passphrase (Argon2id-derived). The artifact is portable across devices.

Restore on a new device:
1. User enters their recovery passphrase.
2. Argon2id derives the wrapping key.
3. The backup's wrapped DB key is unwrapped.
4. The DB is opened with that key.
5. The new device pairs into the existing identity (Phase 7).

Backups exclude:
- The sync queue (operations are device-specific).
- Cached media (re-fetched on demand).
- Telemetry breadcrumbs.

## Performance budgets

| Operation | Target |
|---|---|
| DB open + migrations on launch | ≤ 200 ms |
| Watch chat list (50 conversations) initial | ≤ 30 ms |
| Insert a message + stream fire | ≤ 8 ms |
| Search 100k local messages | ≤ 200 ms |
| Backup creation (10k messages) | ≤ 4 s |
| Restore from backup (10k messages) | ≤ 8 s |

## Memory budget

- DB connection pool: 1 reader (UI thread), 1 writer (background isolate)
- WAL size: capped at 16 MB; we checkpoint aggressively after writes
- Cached prepared statements: ~30 in flight
- Total drift memory at idle: ≤ 4 MB

## Banned

- Direct SQL strings outside drift-generated queries.
- File I/O outside `velix_data/`.
- Synchronous DB calls on the UI thread (drift is async by default; we don't bypass it).
- Reading the SQLCipher key into a long-lived variable (read on demand from secure storage).
- Plaintext caching of decrypted media on disk outside the encrypted media cache directory.
