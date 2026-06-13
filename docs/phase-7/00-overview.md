# 00 — Cryptographic Architecture Overview

## Position

The Velix cryptographic system has one job: **make it impossible for the server (and everyone else) to read user messages**. Every other property follows from that one.

We do not invent cryptography. We **wrap the existing Signal Foundation libsignal Rust crate via Dart FFI**, layered over a small set of well-audited NaCl-equivalent primitives. The architectural work in Phase 7 is the integration boundary, the multi-device key hierarchy, the backup design, the LiveKit E2EE binding, and the threat-model audit — *not* the construction of new ciphers.

This is critical to state up-front: Velix's cryptographic core is **Signal's**, not ours. We track upstream. We do not fork unless we must.

## Pillars

1. **Signal-grade or nothing.** X3DH for initial key agreement, Double Ratchet for ongoing sessions, Sender Keys for groups (with MLS tracked for v2). Sealed Sender for sender anonymity vs the server.
2. **No custom cryptography.** Every primitive is from libsignal or libsodium. We do not roll our own ciphers. We do not roll our own modes. We do not roll our own padding schemes.
3. **Minimal trusted surface.** The cryptographic core is a small Rust crate, FFI-bound to Dart. The Dart side never holds a private key in plaintext beyond the duration of one operation. The OS keychain holds long-term keys; the SQLCipher database holds session state.
4. **Auditable.** The core is open-source, the protocol is documented, the threat model is published, builds are reproducible, and we commission an annual independent audit before public 1.0.
5. **Failure is loud.** Any cryptographic failure is a hard error visible to the user. There is no "fall back to plaintext for availability."
6. **Algorithm agility.** Every encrypted blob carries a 1-byte algorithm identifier. We can rotate primitives in months, not years. Post-quantum hybrid (X25519 + ML-KEM-768) is the next planned rotation.

## Architecture at a glance

```
       Application code (Dart)            Phase 5 client
           │
           │  velix_crypto API (small, typed surface)
           │
       ┌───▼─────────────────┐            Phase 7 boundary
       │  Dart FFI binding   │            (this phase)
       └───┬─────────────────┘
           │
       ┌───▼─────────────────┐
       │  velix_crypto_core  │            Rust crate
       │  (libsignal +       │            (this phase)
       │   thin wrappers)    │
       └───┬─────────────────┘
           │
           │
       ┌───▼─────────────────┐
       │  libsignal-protocol │            Signal Foundation
       │  (Rust)             │            (upstream, tracked)
       └─────────────────────┘
       ┌─────────────────────┐
       │  ring / libsodium   │            primitives
       │  (X25519, Ed25519,  │            (audited)
       │   AES-GCM, HKDF,    │
       │   Argon2id, BLAKE3) │
       └─────────────────────┘
```

## Stack (locked)

| Concern | Choice | Source |
|---|---|---|
| Identity signing | Ed25519 | libsignal |
| Key agreement | X25519 | libsignal |
| Message session | Double Ratchet (Signal Protocol) | libsignal |
| Initial handshake | X3DH | libsignal |
| Group messaging | Sender Keys | libsignal |
| Sender anonymity | Sealed Sender | libsignal |
| Symmetric AEAD | XChaCha20-Poly1305 (preferred), AES-256-GCM (fallback) | libsodium |
| Hash | SHA-256, BLAKE3 (perf-sensitive) | ring + blake3 crate |
| KDF | HKDF (HMAC-SHA-256) | libsignal |
| Password KDF | Argon2id | argon2 crate |
| Random | OS CSPRNG mixed with hardware RNG | rand crate |
| Local DB encryption | SQLCipher (AES-256-GCM, MAC-then-encrypt) | sqlcipher upstream |
| FFI binding | Dart FFI (`dart:ffi`) | Dart standard |
| Build | cargo + cmake; per-platform static link | per platform |
| Audit | annual third-party | scheduled before 1.0 |

## What `velix_crypto` (Dart) exposes

A small, typed, verb-shaped API. The Dart side never sees primitive types — it sees `Identity`, `Session`, `EncryptedEnvelope`, `WrappedKey`, etc. All bytes-handling is internal.

Core surface (full spec in `04-libsignal-binding.md`):

```dart
/// Identity creation. Generates Ed25519 + X25519 keypairs on device.
Future<IdentityCreated> createIdentity({
  String? handle,
  required PassphraseHasher backupPassphrase,
});

/// Sign in to existing identity (challenge-response).
Future<SignInProof> signInChallenge({
  required ServerChallenge challenge,
  required IdentityHandle identity,
});

/// Encrypt outgoing message ciphertext for a list of recipient devices.
/// Each recipient gets a separate ciphertext (Double Ratchet output).
Future<List<EncryptedEnvelope>> encryptForRecipients({
  required ConversationId conversation,
  required Plaintext body,
  required List<RecipientDevice> recipients,
});

/// Decrypt an incoming envelope addressed to this device.
/// Throws on integrity failure; returns plaintext on success.
Future<Plaintext> decryptEnvelope({
  required IncomingEnvelope envelope,
});

/// Pair a new device. Returns the multi-device handshake material.
Future<DevicePairingResult> pairDevice({
  required PairingQR scannedQR,
});

/// Encrypt media for a list of recipients. Returns ciphertext + per-recipient
/// wrapped DEKs.
Future<MediaEncryptionResult> encryptMedia({
  required Bytes plaintextMedia,
  required List<RecipientDevice> recipients,
});

/// Encrypted backup of the local key state. Wraps the DB key with an
/// Argon2id-derived passphrase key.
Future<EncryptedBackup> exportBackup({
  required PassphraseHasher passphrase,
});

/// Restore from a backup on a fresh device.
Future<RestoreResult> restoreBackup({
  required EncryptedBackup backup,
  required PassphraseHasher passphrase,
});
```

## What `velix_crypto_core` (Rust) does

- Wraps libsignal-protocol-rust.
- Wraps libsodium for the symmetric AEAD path.
- Wraps argon2 for password-derived keys.
- Provides safe-by-construction wrappers around primitive byte buffers (zeroized on drop, no debug-printable).
- Exposes a stable C ABI for Dart FFI.

## What is explicitly NOT in `velix_crypto`

- Network calls. The crypto core is offline; bytes go in, bytes come out.
- Persistence. SQLCipher and OS keychain are application-level concerns; the crypto core gets keys passed in.
- UI. AT-readable text strings (verification flow) are formatted in Dart, not Rust.
- Logging. The crypto core has zero logging output. PII safety by construction.

## Performance targets

| Operation | Target (median, iPhone 12 / Pixel 6) |
|---|---|
| Identity generation | ≤ 80 ms |
| Encrypt for one recipient device | ≤ 2 ms |
| Decrypt one envelope | ≤ 3 ms |
| Sender Keys distribution (group of 50) | ≤ 50 ms |
| Argon2id passphrase hash | ≈ 1000 ms (deliberately slow; tuned per device) |
| FFI call overhead | ≤ 50 µs |

These are floor targets. Real numbers depend on libsignal's underlying performance, which is excellent.

## Security failure semantics

When a cryptographic operation fails, the system **never** falls back to a less-secure path. Specifically:

- Decryption failure → message marked as "failed; tap to retry"; never displayed as plaintext.
- Identity verification failure on a peer → the peer's conversation is marked rekeyed; visual material change (Phase 2 trust tints).
- Signature verification failure → message rejected at the protocol layer before reaching application.
- Backup decryption failure → restore aborts; no partial state.

The application surface (Phase 5) maps these to user-visible errors via the existing error taxonomy.

## Banned

- Custom ciphers, modes, padding schemes.
- Encrypting two messages with the same nonce (libsignal handles this; we never feed it user-controlled nonces).
- Reusing key material across protocol versions.
- "Optimistic" decryption that returns partial plaintext on integrity failure.
- Caching plaintext outside SQLCipher.
- Sending error details that distinguish failure modes ("wrong key" vs "malformed ciphertext") to the server.
- Holding decrypted content in `provider` state across animation frames.
- Logging any decrypted byte, ever.
- Building from a libsignal fork without an upstream-merge plan.
