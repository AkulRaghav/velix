# 05 — Secure Key Storage

The on-device key hierarchy. Every secret in Velix sits in this hierarchy; nothing escapes it.

## Hierarchy

```
1. Master device key (MDK)
   ├── stored in: OS keychain (iOS Keychain / Android Keystore / macOS Keychain / Windows DPAPI / Linux libsecret)
   ├── hardware-backed where available (Secure Enclave on iOS A12+, StrongBox on Android 9+)
   ├── access constraint: WhenUnlockedThisDeviceOnly (iOS) / userAuthenticationRequired (Android)
   └── never leaves the device or appears in process memory longer than necessary

2. Per-purpose subkeys derived from MDK via HKDF
   ├── DB encryption key (SQLCipher)
   ├── identity-key wrapping key
   ├── push-notification decryption key
   ├── backup-DEK wrapping key
   └── conversation cache key (for ephemeral session caches)

3. Identity keys (long-lived per-account)
   ├── Ed25519 signing keypair (account identity)
   ├── X25519 KEM keypair (per-device prekey)
   ├── stored in OS keychain (separately from MDK)
   └── private keys never read into Dart unless required for a specific operation

4. Per-conversation keys (Double Ratchet root chain + Sender Keys)
   ├── stored in DB (encrypted at rest)
   ├── ratcheted per message (root key + chain key + per-message keys)
   └── deleted on disappearing-message expiry
```

The OS keychain holds *long-lived* secrets only. Per-conversation key material lives in the encrypted SQLite database, where the volume is high but throughput requirements rule out keychain storage.

## OS keychain wrapper

We use **`flutter_secure_storage`** as the underlying API, with a thin Velix wrapper that adds:

- Strong-typed key names (no string keys at call sites)
- Audit logging (every read/write hit by `velix_telemetry` for security review)
- Configurable per-key access constraints
- Test fakes

Per-platform configuration:

```dart
const _iOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.unlocked_this_device,
  accountName: 'app.velix',
  synchronizable: false,            // never iCloud-sync
);

const _androidOptions = AndroidOptions(
  encryptedSharedPreferences: true,
  keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
  storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  // StrongBox where available
  preferencesKeyPrefix: 'velix.',
);
```

We do not enable iCloud sync for any keychain item. Cross-device sync of identity is a deliberate flow (Phase 7), not a side effect of platform sync.

## Master device key (MDK) lifecycle

### Generation

On first app launch:

1. Generate 32 random bytes via `Random.secure()`.
2. Store in keychain with the constraints above.
3. Derive subkeys via HKDF.

### Read

Every app launch reads the MDK once during bootstrap and derives the subkeys it needs. The MDK is held in process memory for the duration of bootstrap, then dropped. Subkeys live as long as their data does.

### Rotation

The MDK rotates on:
- Manual user action ("Re-secure this device")
- Detected compromise (rare; out-of-band)
- Major version migrations that warrant it

Rotation re-derives all subkeys, re-encrypts the DB key, re-encrypts the identity-key wrapping. This is a multi-second operation; the user sees a "Re-securing" UI.

### Loss

If the MDK is lost (keychain wiped, device wiped, app reinstall), the local data is **unrecoverable**. The user's identity can be restored on a new device via:
- A trusted-other device of theirs (preferred)
- Their backup with passphrase (secondary)

## Identity keys

### Generation

When the user creates an identity:

1. Generate Ed25519 signing keypair on device.
2. Generate X25519 KEM keypair (per-device prekey).
3. Store private keys in keychain, separately from MDK.
4. Hash the public key → account ID.
5. Register the public key with the server (server never sees private keys).

### Storage constraints

Identity keys use the strictest access:

- iOS: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + `kSecAttrAccessControl` (UserPresence on biometric-capable devices).
- Android: `setUserAuthenticationRequired(true)` with a 60s validity window.

This means a user who unlocks the phone has implicit authorization for the next minute of crypto operations; beyond that, biometric/PIN re-prompt.

### Use

Identity keys are read into memory only for the specific operation that requires them — signing a session establishment, decrypting an X3DH bundle. They are never held in long-lived state.

## DB encryption key

The SQLCipher key is derived from the MDK via HKDF with a labeled context:

```dart
final dbKey = HKDF.derive(
  ikm: mdk,
  salt: appBundleSalt,
  info: 'velix.db.v1',
  length: 32,
);
```

This is what `OpenSqliteDatabase` is keyed with. The key is held only for the duration of `db.open()`; afterward, drift owns the connection and we drop the key from Dart memory.

## Push key

Push-notification payloads are encrypted with a per-device push key. The push key is derived from MDK + the FCM/APNs token (so token rotation invalidates old encryptions automatically).

The server holds only the routing token, never the push key. Server-side, a notification is sent as ciphertext; the device's push handler decrypts it.

## Backup DEK wrapping

A backup is encrypted with a *separate* DEK (data encryption key) which itself is wrapped by an Argon2id-derived key from the user's passphrase. The DEK never leaves the device unencrypted. The Argon2id parameters are tuned for ~1 second on a modern phone.

## Memory hygiene

- Secrets are read into `Uint8List` and zeroed after use via `secrets.zeroize(buffer)`.
- We do not pass secrets through `String` (which is GC-managed and may persist).
- Crypto operations happen in a dedicated isolate (`velix_crypto`) so the main isolate's heap never contains keys longer than necessary.
- `addPostFrameCallback` is never used to schedule key reads.

## Audit logging

Every read/write of a secret is logged to `velix_telemetry` with:
- The key name (not the value)
- The caller's class
- A wall-clock timestamp
- Whether the read succeeded

These logs are local-only and rotated weekly. They are not sent to telemetry's network sink. They support security incident review when needed.

## Banned

- Direct calls to `flutter_secure_storage` outside `velix_data/secure_storage/`.
- Storing secrets in `SharedPreferences` or any non-secure store.
- Logging key values, even in debug builds (lint enforces).
- Holding any decrypted private key in `provider` state.
- Cross-isolate transfer of a secret over a `SendPort` (use derived contexts instead).
- iCloud sync, Google Drive sync, or any platform sync of a secret.

## Testing

Secure storage has a fake implementation (`InMemorySecureStorage`) for tests. Tests run with no real keychain access. Integration tests use the real keychain on the iOS simulator and Android emulator.

## Phase 7 dependencies

This phase establishes the storage. Phase 7 implements the actual cryptographic operations using these stored keys. The interface is stable; Phase 7 swaps the stub implementations.
