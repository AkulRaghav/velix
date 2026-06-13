# 11 — Encrypted Backup & Restore

A user's local data — every Double Ratchet session, every Sender Keys state, every key in the protocol store, every message in their local DB — can be backed up to Velix's server in encrypted form. The server stores ciphertext only; we cannot read it.

## Goal

Survive a lost device. Allow the user to restore on a new device by remembering a passphrase.

## Non-goal

Restore arbitrary point-in-time. Backups are full snapshots; we do not version them.

## Construction

The backup is the entire SQLCipher database file plus a wrapped key:

```
backup_artifact = wrapped_db_key || nonce || aead_ciphertext_of_db_file

where:
  passphrase_hash = Argon2id(passphrase, salt=backup_seed,
                             memory=64 MiB, parallelism=4,
                             iterations=tuned_to_~1000ms_on_iPhone_12)

  wrapping_key = HKDF(passphrase_hash, salt=zero,
                      info="velix.backup.wrap.v1", len=32)

  random db_dek = csprng.fill_bytes(32)

  wrapped_db_key = AEAD-XChaCha20-Poly1305(
                       key=wrapping_key,
                       nonce=random_24,
                       aad="velix.backup.v1",
                       plaintext=db_dek)

  aead_ciphertext_of_db_file = AEAD-XChaCha20-Poly1305(
                       key=db_dek,
                       nonce=random_24,
                       aad="velix.backup.v1",
                       plaintext=db_file)
```

Two keys for separation of concerns:
- `wrapping_key` derived from passphrase, never persisted.
- `db_dek` random per-backup; protects the actual DB; wrapped by `wrapping_key`.

A change of passphrase re-wraps `db_dek` without re-encrypting the DB.

## Backup_seed (a Tier-2 key from the Phase 7 doc 05 hierarchy)

`backup_seed = HKDF(MDK, salt=app_bundle_salt, info="velix.backup.v1", len=32)`

The seed lives only on the device, derived from the MDK on every app launch. It's used as the Argon2id salt so two devices' passphrases produce different `wrapping_key` (preventing precomputed-rainbow attacks tied to a known salt).

When the user changes devices, the new device cannot derive the same `backup_seed` — but it doesn't need to, because the salt is part of the backup artifact itself.

Wait — that's a subtle issue. Let me clarify:

**The backup carries its own Argon2id salt.** The salt is *included in the backup artifact*. The new device:

1. Reads `salt` from the backup artifact.
2. Asks the user for the passphrase.
3. Computes `Argon2id(passphrase, salt=salt, ...)`.

The salt is random per-backup, included in cleartext in the artifact, exactly as in standard password-based encryption schemes.

The corrected flow:

```
backup_artifact = magic_header
               || version_byte
               || argon2_salt       (16 bytes random)
               || argon2_params     (memory, parallelism, iterations)
               || wrapped_db_key    (with its own AEAD nonce)
               || db_aead_nonce
               || db_ciphertext
               || hmac_tag          (over the entire artifact for integrity-before-decrypt)
```

The HMAC tag uses a separate `hmac_key = HKDF(wrapping_key, info="velix.backup.hmac.v1")`. This lets the recipient verify the artifact is intact before attempting Argon2id (which is expensive); a tampered artifact fails the HMAC check first.

## Argon2id parameters

| Parameter | Value | Notes |
|---|---|---|
| Memory | 64 MiB | enough to deter GPU attacks; fits on devices we ship to |
| Parallelism | 4 | matches modern phone CPU |
| Iterations | tuned per device | calibrated at first run to ≈ 1000 ms |
| Output length | 32 bytes | |

The per-device iteration count is calibrated and stored in the backup artifact so any device can re-derive identically. The calibration is done once on device pairing.

## Passphrase requirements

- Minimum 8 characters; we encourage 4 random words.
- We use `zxcvbn` to check strength; weak passphrases get a warning but are not rejected (user agency).
- The passphrase is held in process memory only during backup creation and restore; zeroized immediately after.

## Backup creation flow

```
User taps "Create backup":
   1. Prompt for passphrase. If first backup, prompt twice (confirm).
   2. Derive wrapping_key via Argon2id (≈ 1 s; show "Backing up..." UI).
   3. Generate random db_dek.
   4. Wrap db_dek with wrapping_key.
   5. Read SQLCipher DB file from disk (a flushed, consistent snapshot via VACUUM INTO).
   6. AEAD-encrypt the DB file with db_dek.
   7. Compute HMAC over the artifact.
   8. Upload artifact to backup endpoint via media-style presigned URL.
   9. Server stores ciphertext in R2 with metadata in `backups` table.
   10. Zero passphrase, wrapping_key, db_dek from memory.
```

The backup is one R2 object per user. Restoring overwrites; we keep one prior version for 7 days as protection against ransomware-style attacks (an attacker who got into the device couldn't immediately destroy the last good backup).

## Backup integrity

Every backup carries the artifact-level HMAC tag. On restore, the new device:

1. Verifies the magic header + version.
2. Reads the salt + argon2 params.
3. Computes wrapping_key via Argon2id.
4. Verifies the HMAC tag using the derived hmac_key.
5. **Only if the HMAC verifies**, proceeds to AEAD-decrypt the DB.

This two-stage verification means a tampered backup fails fast (≤ 1 s) instead of after a successful Argon2id (which would otherwise take 1 s before discovering corruption).

## Restore flow

```
User opens Velix on new device:
   1. Choose "Restore from backup".
   2. Enter their account_id (or scan QR from another device — Phase 7 doc 10).
   3. Server returns the most recent backup artifact.
   4. Prompt for passphrase.
   5. Derive wrapping_key (≈ 1 s).
   6. Verify HMAC.
       Failure → display "Wrong passphrase or backup corrupted"; do NOT
                 distinguish between the two (information leak).
   7. AEAD-unwrap db_dek.
   8. AEAD-decrypt the DB file into a temporary location.
   9. Open SQLCipher with db_dek; verify schema version.
   10. Promote the temp DB to the live DB location.
   11. Pair this device with the existing identity (Phase 7 doc 10).
   12. Zero passphrase, wrapping_key, db_dek.
```

The new device now has the same protocol-store state. Sessions, Sender Keys, and identity records all carry over. Other users' clients see the new device, fan out to it via the standard pairing event.

## What backups DO contain

- The full SQLCipher database, including:
  - libsignal protocol store (sessions, sender keys, identity records, prekeys)
  - Local message envelopes (decrypted body in `messages` for client display)
  - Conversation metadata
  - User preferences
  - Sync queue state at backup time

## What backups do NOT contain

- The OS-keychain entries (MDK, identity Ed25519/X25519). These are tier-1 keys; restoring requires re-pairing via the multi-device flow, where the existing trusted device emits an attestation for the new device.
- The push token (regenerated by the new device's OS).
- Telemetry breadcrumbs.

So a "fresh device restore" requires:
1. Pairing with an existing trusted device (gets identity attested).
2. Restoring the backup (gets local data).

If no existing trusted device is available (the user lost all of them), they can ONLY restore the messages, not their identity. They'll need to create a new identity. Their contacts will see them as a new account_id and re-verify.

This is intentional: the identity private key never leaves a device unencrypted. There's no "restore my identity from a passphrase" path — that would mean the passphrase is the de-facto root, and a server-side passphrase database becomes the attack target.

## Storage

| Service | Storage | Retention |
|---|---|---|
| `media` (re-used for backups since R2 is the storage) | One R2 object per user | Last 1 + previous (7-day grace) |
| `media` table | metadata (size, etag, expiry) | Same |

## Performance

- Backup creation (10k messages, ~50 MB DB): ~2-4 s on iPhone 12; dominated by AEAD over the DB file.
- Restore: ~3-5 s.
- Argon2id is the user-visible slow part (≈ 1 s); we show a spinner with a clear "Verifying passphrase…" message.

## Limitations

- No partial restore. The user gets all-or-nothing.
- No incremental backups in 1.0. Each backup is a full snapshot.
- Loss of passphrase = loss of backup. We do not have a recovery path; key escrow would defeat the security property.

## Banned

- Storing passphrases server-side, even hashed.
- Server-side decryption attempts on backup contents.
- Sending the passphrase over any network.
- Caching the unwrapped db_dek beyond the restore operation.
- Skipping HMAC verification in the name of "speed".
- Logging passphrase entropy (zxcvbn score is fine; the passphrase itself never).
- Distinguishing "wrong passphrase" from "tampered backup" in user-visible errors.
- Allowing restore without a paired trusted device's attestation (would defeat the device-binding property).
