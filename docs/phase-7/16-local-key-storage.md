# 16 — Local Key Storage

Phase 5 doc 05 sketched the OS-keychain hierarchy. Phase 7 doc 05 formalized the cryptographic key tiers. This document specifies how each platform's keychain integrates with `velix_crypto_core`.

## Per-platform integration

### iOS / iPadOS / macOS

- **Keychain item attributes:**
  - `kSecAttrAccessible`: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  - `kSecAttrSynchronizable`: `false` (never iCloud)
  - `kSecAttrAccessControl`: `kSecAccessControlUserPresence` (where biometric available)
- **Access path:**
  - The MDK and identity_priv are queried on app launch.
  - Each query that requires UserPresence triggers Face/Touch ID; a successful unlock validates for 60 seconds.
  - After 60s, biometric prompt re-fires.
- **Secure Enclave:**
  - On A12+ (iPhone XS, 2018), identity_ed25519_priv lives in Secure Enclave-backed keys.
  - This means the key never leaves the SE; signing operations happen inside the SE; the result returns to userspace.
  - Argon2id passphrase derivation does NOT happen in SE (memory-bound; SE is too constrained).

### Android

- **Keystore attributes:**
  - `setUserAuthenticationRequired(true)` with 60-second validity window.
  - `setUnlockedDeviceRequired(true)` (Android 9+).
  - `setIsStrongBoxBacked(true)` where StrongBox available (Pixel 3+, some Samsung).
- **Per-key:**
  - Identity Ed25519 private: stored as `KeyProtection` with `KEY_PROPERTY_ASYMMETRIC_KEY_PURPOSE_SIGN`.
  - X25519 private: similarly, with `KEY_PROPERTY_ASYMMETRIC_KEY_PURPOSE_AGREE_KEY` (Android 12+).
  - On Android < 12 (no agree-key API): X25519 is stored as 32 bytes inside an AES-256-GCM-protected blob whose AES key is in Keystore.
- **Fallback:**
  - Devices without StrongBox use TEE-backed Keystore. Less hardened than StrongBox but still strong.
- **Tested OS versions:** Android 11+ at 1.0; older versions documented as "best-effort."

### Windows

- **DPAPI** with `CryptProtectData` scoped to the user's logon credentials.
- TPM binding via `NCryptProtectSecret` with `NCRYPT_PROTECT_TO_LOCAL_SYSTEM` flag where TPM available.
- The MDK is wrapped by DPAPI; the identity_priv is wrapped separately.
- A user account compromise (Windows Hello bypass) compromises the keys; we do not promise resistance to attacks at the user-account level.

### Linux

- **libsecret** via the `org.freedesktop.secrets` schema.
- A Velix-specific schema with an explicit `Application = "app.velix"` attribute.
- Linux has no platform-mandated TPM binding by default; we enable TPM support via `tpm2-totp` if available, but it's optional.

### Web

- **Not supported in 1.0.** The Velix Flutter web build runs in degraded mode without local crypto state. Users on web sign in to their account but can only access ephemeral session material; they cannot maintain the protocol store.
- **Tracked:** Web Crypto API + IndexedDB encrypted with a derived key from a passphrase.

## SQLCipher integration

The local SQLite database is encrypted with `db_key`, derived from MDK via HKDF (Phase 7 doc 05).

```
db_key = HKDF(MDK, salt=app_bundle_salt, info="velix.db.v1", len=32)
```

SQLCipher uses AES-256-CBC with HMAC-SHA-512. We accept the construction; SQLCipher is well-audited and covers our threat model. We do not roll our own DB encryption.

The DB is opened on app startup with `db_key` passed via `PRAGMA key`. After open, drift (the Dart ORM, Phase 5 doc 04) operates as normal.

`db_key` is held in process memory only during the `db.open()` call. After open, SQLCipher caches its derived schedule internally; we drop our copy of `db_key` from Dart memory.

## Secure storage for protocol-store rows

libsignal's protocol-store traits are implemented in Rust. They write to the same SQLCipher DB via prepared statements. The Rust code calls into the Dart side via FFI return values; Dart performs the actual SQLCipher writes (because the SQLCipher binding is in Dart).

This is a deliberate split:

- Rust does the cryptographic operations.
- Rust returns serialized state.
- Dart persists.
- Dart reads on demand and passes back to Rust.

The split keeps the SQLCipher binding in one place (Dart) and the cryptographic boundary in another place (Rust). It costs an extra FFI hop per protocol-store read/write — measured at ~50 µs, negligible compared to the AEAD operations.

## Memory hygiene

The Rust core uses `Secret<T>` (Phase 7 doc 04). Plaintext, message keys, root keys, identity keys all live inside `Secret<T>` and are zeroized on drop.

The Dart side:

- Receives plaintext as `Uint8List`.
- Copies to a managed `String` (for UI display).
- The `Uint8List` plaintext is set to all zeros via `.fillRange(0, length, 0)` before nullification.
- The `String` is held only as long as the rendering frame requires; subsequent rebuilds replace it; GC collects.

Dart does not give us deterministic zero-on-drop guarantees. We accept this — a kernel-level forensic adversary (A4 / A7) is partially defeated only by hardware-backed keys, not by Dart's memory model.

## Cross-process isolation

- iOS App Groups: not enabled. Velix has no extension that needs shared access.
- Android: same. No exported services, no shared providers.
- macOS: per-process keychain access only; no group access.
- Windows: per-user only.
- Linux: libsecret is per-user.

The notification service extension (iOS) does access the per-device push key via the same keychain, scoped to the app group `app.velix.shared`. This is the only cross-process key access.

## Backup of keys

Phase 7 doc 11 covers backup of *protocol state* (sessions, sender keys). It does NOT cover backup of identity_priv or MDK.

To recover identity on a new device, the user pairs via existing trusted device (Phase 7 doc 10). There is no passphrase-only recovery of identity. This is a deliberate constraint to prevent server-side passphrase-based attack surface.

## Logging restrictions

The logger (Phase 6 doc 10 + lint rules) cannot accept any field whose name matches:

```
private | priv | secret | password | passphrase | key | pem | cipher
```

Or any field whose value matches a regex for hex-encoded crypto material (32 / 64 bytes hex-encoded).

The lint rules are enforced at compile time via `staticcheck` extensions in CI.

## Banned

- Storing keys in `SharedPreferences` / `UserDefaults` / plist.
- iCloud Keychain sync of any Velix key.
- Google account sync.
- Sharing keys across apps (other than the iOS notification service extension).
- Software-only key generation when hardware-backed is available.
- Logging keys, even truncated, even in debug builds.
- Generating keys via `Random()` rather than CSPRNG.
- Persisting `db_key` longer than the open() call.
- Persisting Argon2id-derived passphrase keys.
