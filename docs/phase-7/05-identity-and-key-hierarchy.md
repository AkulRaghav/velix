# 05 — Identity & Key Hierarchy

The complete on-device key hierarchy. Phase 5 doc 05 sketched the outline; Phase 7 makes it precise enough to implement.

## Hierarchy

```
1.  OS keychain (hardware-backed where available)
       ├── Master Device Key (MDK)                32 bytes random
       ├── Identity Ed25519 private               32 bytes
       └── Identity X25519 private                32 bytes (derived from Ed25519 via libsignal)

2.  Derived from MDK via HKDF (label-separated)
       ├── DB encryption key                      32 bytes — passed to SQLCipher
       ├── Backup wrapping key seed               32 bytes — combined with passphrase
       ├── Push routing seed                      32 bytes
       └── Conversation cache key                 32 bytes — for ephemeral RAM caches

3.  Stored inside SQLCipher (encrypted at rest)
       ├── Signed prekey (rotates every 7 days)
       ├── One-time prekeys (consumed on use)
       ├── Per-conversation Double Ratchet state
       │     ├── root key
       │     ├── chain keys (sending, receiving)
       │     └── per-message-number AEAD keys
       ├── Per-group Sender Keys state
       │     ├── chain key
       │     └── signing key (Ed25519, for group authenticity)
       └── Per-call ephemeral keys
```

## The three tiers, explained

### Tier 1 — OS keychain

The smallest, longest-lived, most-protected tier. Three entries per device:

- **MDK** — generated on first launch. 32 random bytes. Hardware-backed where the platform allows (Secure Enclave on iOS A12+, StrongBox on Android Pie+).
- **Identity Ed25519 private key** — generated on identity creation. Used for signing X3DH bundles, attestations, and safety-number proofs.
- **Identity X25519 private key** — generated on identity creation. Used for X3DH initial key agreement.

Access constraints:

| Platform | Constraint |
|---|---|
| iOS | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + `kSecAttrAccessControl` (UserPresence on biometric-capable devices) |
| Android | `setUserAuthenticationRequired(true)` with 60s validity window |
| macOS | Keychain ACL with `kSecAccessControlUserPresence` |
| Windows | DPAPI scoped to user with TPM binding |
| Linux | libsecret + `org.freedesktop.secrets` schema with custom auth |

These keys are read into Rust core memory only for the specific operation that requires them, then zeroized.

### Tier 2 — Derived from MDK

These are NEVER stored. They are derived from the MDK + a static, domain-separated label via HKDF on every app launch:

```
db_key       = HKDF(MDK, salt=app_bundle_salt, info="velix.db.v1",       len=32)
backup_seed  = HKDF(MDK, salt=app_bundle_salt, info="velix.backup.v1",   len=32)
push_seed    = HKDF(MDK, salt=app_bundle_salt, info="velix.push.v1",     len=32)
cache_key    = HKDF(MDK, salt=app_bundle_salt, info="velix.cache.v1",    len=32)
```

The labels are domain-separated; deriving `db_key` cannot accidentally produce the same bytes as `backup_seed`.

These derived keys live in process memory for the duration of their use:
- `db_key` — held only during `db.open()`; SQLCipher caches its own derived schedule afterward.
- `backup_seed` — held only during backup operations.
- `push_seed` — held by the push handler for the duration of the app session.
- `cache_key` — held by the conversation cache for the duration of the conversation.

### Tier 3 — Inside SQLCipher

The entire libsignal protocol-store state. Including:

- Identity record (this device's identity public key)
- Pre-keys (signed + one-time)
- Sessions (per recipient device, Double Ratchet state)
- Sender Keys (per group)
- Trusted-identity records (peer identity public keys we've seen)

These are managed by libsignal via the Rust storage traits, persisted to SQLCipher via prepared statements. Never manually accessed by Dart code.

## Key generation

| Key | Generation |
|---|---|
| MDK | `csprng.fill_bytes(32)` |
| Identity Ed25519 | `Ed25519::generate(csprng)` |
| Identity X25519 | derived from Ed25519 via libsignal's `IdentityKey::private_key().to_public()` |
| Signed prekey | `X25519::generate(csprng)`, signed by identity |
| One-time prekey | `X25519::generate(csprng)` |
| Backup DEK | `csprng.fill_bytes(32)` (per-backup) |
| Backup passphrase wrapping key | Argon2id(passphrase, salt=backup_seed, params=(64MiB, 4, n_iterations)) |

`csprng` is a single source — `csprng.rs` in the Rust crate, mixing `OsRng` with hardware RNG.

## Key serialization

Every key is serialized in libsignal's canonical Protobuf format. We do not invent encoding.

For storage in OS keychain (Tier 1), we use a thin envelope:

```
[1-byte version][4-byte length][payload]
```

The version byte enables algorithm agility. Tier-1 currently uses version 0x01.

## Identity creation flow

```
User taps "Create identity"
   ↓
Rust core:
   1. Generate MDK.
   2. Store MDK in OS keychain (with access constraints).
   3. Generate Ed25519 identity keypair.
   4. Store identity-priv in OS keychain.
   5. Compute hash(identity_pub) = account_id.
   6. Generate signed prekey + 100 one-time prekeys.
   7. Open SQLCipher with derived db_key.
   8. Insert this device's identity record into the protocol store.
   ↓
Dart side:
   9. Submit account_id, identity_pub, signed_prekey, signed_prekey_signature,
      one_time_prekeys to identity service via gRPC.
   ↓
Server:
   10. Inserts accounts row, devices row, prekey_bundles row, one_time_prekeys rows.
   11. Returns access + refresh tokens (Phase 6).
   ↓
Client is signed in.
```

## Sign-in flow (existing identity)

```
User taps "Sign in"
   ↓
Server issues a fresh challenge (32 random bytes, expires in 60 s).
   ↓
Rust core:
   1. Read identity-priv from OS keychain (one-shot).
   2. Sign(identity_priv, challenge || device_pub || nonce).
   ↓
Dart submits the signature.
   ↓
Server:
   3. Verifies signature against the account's identity_pubkey on file.
   4. Issues access + refresh tokens.
```

## Identity rotation

The identity Ed25519 keypair never rotates within a device's lifetime. Rotation = creating a new identity, which produces a new account_id.

This is intentional. Rotation would invite covert key replacement attacks; the user's contacts would have to re-verify on every rotation.

If a device is suspected of compromise, the user creates a new identity on a fresh device and informs contacts to re-verify.

## Per-device identity

Every device under an account has its own X25519 keypair (the "device key"), distinct from the account's identity Ed25519. The device key is what X3DH negotiations bind to.

```
account_id   = hash(identity_ed25519_pub)
device_id    = ULID assigned at pairing
device_pub   = X25519 public key
attestation  = Ed25519 signature(identity_priv, "device_attestation_v1" || device_pub || device_id || timestamp)
```

The attestation is what binds a device to the identity. The server stores the attestation and verifies it on every device-add. A device without a valid attestation cannot be added.

## Prekey replenishment

The client maintains an inventory of one-time prekeys in libsignal's protocol store. When the inventory drops below 30:

1. Generate (100 - current) new one-time prekeys.
2. Insert into SQLCipher.
3. Submit public halves to `identity.PublishPrekeys`.

The signed prekey rotates every 7 days. The client schedules a Background Fetch task; on rotation:

1. Generate new X25519 keypair.
2. Sign the public key with identity_priv.
3. Submit `signed_prekey, signed_prekey_signature, signed_at` to `identity.PublishPrekeys`.
4. Old signed prekey remains valid for in-flight X3DH for 24 hours, then is dropped.

## Trusted identity records

When this device first encounters a peer's identity_pub, we store it in the protocol store with a `trusted` flag. On subsequent interactions, libsignal compares the incoming identity_pub against the trusted record:

- Match → continue normally.
- Mismatch → libsignal raises `UntrustedIdentity` → application surface marks the conversation `rekeyed` (Phase 2 trust state).

The user can re-trust via the verification flow (`15-identity-verification.md`).

## Memory hygiene rules

For every operation:

1. Read keys from OS keychain only when needed.
2. Pass into Rust as a `(ptr, len)` pair.
3. Rust wraps in `Secret<T>`, zeroized on drop.
4. After the operation, zero the input buffer on the Dart side too.
5. Never `.toString()` a key. Never include in `Debug` or `Display`.
6. Never log the bytes, even hex-encoded.

## Banned

- Storing private keys in `SharedPreferences`, `UserDefaults`, plist, or any other unencrypted store.
- iCloud Keychain sync of any Velix key.
- Google account sync of any Velix key.
- Sharing keys across apps via App Groups / shared keystores.
- Generating keys with `Random()` or `SecureRandom()` directly — always through libsignal's `csprng`.
- Hardcoded keys, even for tests (use `csprng` with a fixed seed in tests).
- Printing keys to logs at any level, even in debug builds.
- A `Default` impl on any private-key type.
- Reusing a key across protocol versions.
