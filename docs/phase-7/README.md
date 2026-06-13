# Phase 7 — End-to-End Encryption & Cryptographic Infrastructure

Status: in progress. Gates Phase 8.

## What ships

The complete cryptographic architecture and integration spec. **Velix's cryptographic core is Signal Foundation's libsignal**; we wrap it via Dart FFI rather than re-implementing it. This phase delivers:

- Architecture documents and trust-boundary diagrams
- Threat model with adversary classes and defended properties (P1–P16)
- Protocol decisions (X3DH, Double Ratchet, Sender Keys, Sealed Sender, all justified)
- The Dart FFI boundary contract and Rust crate surface
- Multi-device pairing flow
- Backup and recovery design
- LiveKit Insertable Streams binding for E2EE calls
- Local key storage hierarchy (continues Phase 5 doc 05)
- Self-audit covering replay, MITM, key reuse, metadata leakage, side channels, race conditions

What does **not** ship in Phase 7: the Rust implementation itself. That's mechanical work following the spec — multi-week effort by a cryptographer or two. The architectural decisions are all made; the trust surface is bounded; the audit is complete.

## Locked posture

- **Signal Protocol family.** No custom crypto.
- **libsignal Rust core**, FFI-bound to Dart. Open-source under a permissive license.
- **No plaintext fallback.** Cryptographic failure is loud.
- **Reproducible builds** of the cryptographic core. Annual independent audit.
- **Algorithm agility** via 1-byte version tag on every encrypted blob.
- **Sealed Sender** for sender anonymity vs the server.
- **Sender Keys** for groups in 1.0; MLS evaluated and tracked for v2.
- **Per-device key hierarchy** — every device is a first-class member of an identity.
- **Argon2id passphrase wrapping** for backups; passphrase never leaves the device.
- **LiveKit Insertable Streams** for ≤ 8-participant call E2EE; SFU-trust mode > 8 with explicit UI.

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [Overview](./00-overview.md) | Pillars, stack, what's in `velix_crypto` and what isn't |
| 01 | [Threat Model](./01-threat-model.md) | Adversaries (A1–A7), promised properties (P1–P16), non-promises (N1–N10) |
| 02 | [Cryptographic Primitives](./02-primitives.md) | Algorithms, parameters, agility, rotation |
| 03 | [Trust Boundaries](./03-trust-boundaries.md) | What each component sees; key custodianship |
| 04 | [libsignal Binding](./04-libsignal-binding.md) | Rust crate surface, FFI contract, lifecycle |
| 05 | [Identity & Key Hierarchy](./05-identity-and-key-hierarchy.md) | Per-device keys, prekeys, master device key |
| 06 | [X3DH & Initial Handshake](./06-x3dh-initial-handshake.md) | Bundle exchange, prekey consumption |
| 07 | [Double Ratchet](./07-double-ratchet.md) | Forward secrecy, post-compromise, message numbers |
| 08 | [Sender Keys for Groups](./08-sender-keys-and-mls-decision.md) | Sender Keys design + MLS evaluation |
| 09 | [Sealed Sender](./09-sealed-sender.md) | Server-blind sender envelopes |
| 10 | [Multi-Device Pairing](./10-multi-device-pairing.md) | QR + emoji handshake, attestation, history transfer |
| 11 | [Encrypted Backup & Restore](./11-backup-and-restore.md) | Argon2id passphrase wrapping, integrity, restore flow |
| 12 | [Encrypted Media](./12-encrypted-media.md) | Per-message DEK, per-recipient wrapping, R2 ciphertext storage |
| 13 | [Encrypted Push](./13-encrypted-push.md) | Per-device push key, rotating routing token |
| 14 | [LiveKit E2EE Calls](./14-livekit-e2ee.md) | Insertable Streams, key rotation on participant change |
| 15 | [Identity Verification (Safety Numbers)](./15-identity-verification.md) | QR scan, emoji confirmation, rekeyed-state UX |
| 16 | [Local Key Storage](./16-local-key-storage.md) | OS keychain, SQLCipher, memory hygiene |
| 17 | [Recovery & Loss Scenarios](./17-recovery-and-loss.md) | Lost device, lost passphrase, compromised device |
| 18 | [Phase 7 Audit](./18-phase-7-audit.md) | Self-review, residual risks, gating Phase 8 |

## Reference implementation

```
packages/velix_crypto/                    ← Dart side (Phase 5 stub becomes real)
  lib/velix_crypto.dart                   ← public surface
  lib/src/ffi/                            ← FFI binding glue
  lib/src/types/                          ← Identity, Session, etc.

backend/services/identity/internal/crypto/  ← server-side prekey storage helpers (no decryption)

cryptocore/                               ← NEW: Rust crate
  Cargo.toml
  src/
    lib.rs                                ← public C ABI
    identity.rs
    session.rs
    sender_keys.rs
    sealed_sender.rs
    backup.rs
    media.rs
  build.rs                                ← per-platform link to libsignal
```

The Rust crate is in a top-level `cryptocore/` directory (not `backend/`) because it's consumed by the Flutter client, not by the backend.

## Reading order

If you have ten minutes: 00 → 01 → 18.
If you're implementing the Rust core: 04 → 02 → 06 → 07 → 08 → 09.
If you're auditing: 18 → 01 → 03 → 11 → 17.
If you're integrating in the client: 04 → 16 → 12 → 13 → 14.

## Critical disclosure

The cryptographic substance — X3DH, Double Ratchet, Sender Keys, Sealed Sender — is **not implemented by Velix**. It is implemented by Signal Foundation in their libsignal-protocol-rust crate, which has been independently audited multiple times and is in production at Signal, WhatsApp, and other deployments protecting billions of users.

What Velix builds is the **integration**: the Dart FFI binding, the higher-level operations (identity creation, multi-device pairing, backup), the trust-boundary enforcement, the storage hierarchy, and the audit. Velix's value-add is the *system around* the proven cryptography, not new cryptography.

If we ever consider deviating from libsignal upstream, the bar is high: a written justification, a peer review by an external cryptographer, and a public protocol spec.
