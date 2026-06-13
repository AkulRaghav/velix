# 06 — Multi-Device Sync Foundation

Phase 5 establishes the **client-side primitives** for multi-device sync. The actual server protocol and key fan-out are Phase 6/7. What ships in Phase 5: data model, sync queue, conflict resolution, device registry.

## Identity & device model

Each account has one identity (Ed25519 + X25519 keypair). Each device under that identity is a first-class member.

```dart
class Identity {
  final IdentityId id;          // hash(public_key)
  final Bytes ed25519PublicKey;
  final Instant createdAt;
}

class Device {
  final DeviceId id;
  final IdentityId identityId;
  final Bytes deviceX25519PublicKey;
  final String name;            // "Quinn's iPhone"
  final DeviceStatus status;    // active, paused, revoked
  final Instant pairedAt;
  final Instant lastSeenAt;
}
```

The identity's authority is its long-lived signing key. Each device proves membership via a signed device-attestation issued at pairing time.

## Pairing flow

1. **Existing device A** generates a 32-byte ephemeral nonce + a 6-character display code.
2. A renders a QR encoding the nonce + the existing identity public key.
3. **New device B** scans the QR.
4. B and A perform an authenticated Diffie-Hellman over the ephemeral nonce; both parties confirm the resulting key by displaying matching emoji.
5. Once confirmed, A's identity-key signs a `DeviceAttestation` for B's new device key.
6. The attestation is published to the server, which adds B to the identity's device list.
7. B receives the attestation + the identity's public key + an *encrypted history transfer bundle* from A.
8. B unwraps the bundle locally; chats become available.

Phase 7 owns the cryptographic detail. Phase 5 establishes:
- The QR scanning UI (`/profile/edit/devices/add`)
- The device-attestation row in the local DB
- The pairing state machine in `PairingNotifier`

## History transfer

When a new device is paired, the existing-trusted device offers its full conversation history. The transfer is:

1. Existing device packages an encrypted history bundle (ciphertext + per-conversation key envelopes).
2. Bundle is uploaded to a short-lived server holding pen (server holds ciphertext only; cannot read).
3. New device downloads, decrypts, ingests.
4. Holding pen entry is deleted.

The bundle is a `.velixarchive` (parallel to `.velixscene`) — a deterministic ZIP with manifest + ciphertext blocks + per-conversation key envelopes. Defined in `velix_data/lib/src/sync/archive.dart`.

## Sync queue

Every mutation that needs to reach the server enters the local `sync_queue` (Phase 5 doc 04 `04-offline-first-storage.md`).

A single background `SyncWorker` drains the queue. Per-entry semantics:

| Entry kind | Idempotent | Retry policy |
|---|---|---|
| `OutboundMessage` | yes (by message id) | exp backoff, 6 retries / 24h |
| `MarkAsRead` | yes (last-write-wins by timestamp) | exp backoff, 6 retries / 24h |
| `Reaction` | yes (idempotent toggle) | exp backoff |
| `ProfileUpdate` | yes (last-write-wins) | exp backoff |
| `DeviceAttestation` | yes | retry until permanent failure |
| `KeyRotation` | yes | retry until permanent failure |

The worker authenticates per-request with a short-lived token issued by the auth flow (Phase 6).

## Inbound delivery

When the server has new data for the device, it pushes via WebSocket (foreground) or via APNs/FCM with an encrypted payload (background). The client decrypts and applies to the local DB.

Inbound merges follow CRDT-equivalent rules:

- Messages: append-only, ordered by `(sequence_number, sent_at)`.
- Reactions: idempotent toggles.
- Read receipts: last-write-wins per (conversation, viewer).
- Profile changes: last-write-wins per field.
- Device list: server-authoritative (the server keeps the canonical list signed by the identity).

The merge is implemented in `velix_data/lib/src/sync/merge.dart`. Each merge runs in a single drift transaction so the local DB never observes a partial state.

## Conflict resolution

Most operations are designed to be commutative (reactions are toggles; reads are timestamps). For the few that aren't:

- **Profile name changes from two devices simultaneously**: server picks the later wall-clock; the client's optimistic local change is reconciled by the merge.
- **Conversation title changes**: same posture.
- **Device add/remove from two existing devices simultaneously**: server-authoritative; ties broken by signature timestamp.

We do not present "you have a conflict" UX. The user never sees a merge prompt. Conflicts are resolved silently.

## Per-device read tracking

Read state is per-device, then aggregated. A user with three devices may have read a message on device A but not B; the aggregate is "this identity has read it." We use the union for the user-facing display, but the server knows the per-device state for accurate "delivered to all your devices" reporting.

## Bandwidth and throttling

- Outbound throttle: 30 ops/second cap. Above that, queue grows; user-perceived behavior unaffected because the UI reads from the local DB.
- Inbound: server fan-out limits.
- Initial sync (paired new device): chunked at 1 MB per chunk; resumable via chunk-id.

## Connectivity transitions

The client maintains a `ConnectivityState` (offline / connecting / online / metered).

- Offline: queue grows; UI shows a discreet "Offline" banner only after 30 seconds (we don't surface flicker).
- Online: queue drains; banner disappears.
- Metered: large media uploads paused; small messages still send (configurable by user).

## State observability

`ConnectivityNotifier`, `SyncQueueNotifier`, and `PairingNotifier` are exposed via Riverpod. Screens that care (Settings → Devices, profile edit) read from them.

## Privacy guarantees from Phase 1 carried into Phase 5

- The server never sees plaintext message content.
- The server sees minimal routing metadata (envelope addressed by account+device hash).
- Sealed Sender (Phase 7) hides the sender from the server.
- Push payloads are encrypted; the server sees only a routing token.
- The history transfer bundle is encrypted end-to-end; the server's holding pen is ciphertext only.

These are enforced at the boundary of `velix_data/gateways/` and verified in tests.

## Banned

- Plaintext sync of any message content over any channel.
- Server-side conflict-resolution that requires server access to plaintext.
- Cross-device sync via cloud (iCloud, Google Drive). Velix's own sync is the only path.
- Per-device PII collected for analytics (we collect anonymous per-device-class metrics only).

## Phase 5 deliverables (sync foundation)

- Local DB schema for identities, devices, sync queue (Phase 5 doc 04).
- `IdentityRepository`, `DeviceRepository`, `SyncQueueRepository` interfaces in `velix_domain`.
- `Drift…` implementations in `velix_data` against the local DB.
- Stub `MessageGateway`, `IdentityGateway` in `velix_data/gateways/` that simulate online/offline.
- `PairingNotifier`, `ConnectivityNotifier`, `SyncQueueNotifier` in `apps/velix_app`.
- Settings UI for device list (read-only at 1.0 in Phase 5; manage in Phase 7).
- Test fakes for offline, online, and intermittent connectivity.
