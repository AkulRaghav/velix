# 07 — Security Architecture Sketch (high-level)

Detailed protocols and key schedules belong to Phase 7. This document establishes the threat model, the protocol family, and the non-negotiables.

## Threat model

We design against four categories of adversary.

### A — Network adversary
- ISP, public Wi-Fi, BGP-level attacker, state-level passive collection.
- Capabilities: sees TLS metadata, IP routing, traffic timing.
- We assume they are present.

### B — Server-side adversary (compromise of our infrastructure)
- Includes insider threat, lawful demand, server compromise.
- Capabilities: full read of any data we store at rest, and any data we process in memory if compromised.
- We design to minimize what we store and process in plaintext to **as close to zero as possible**.

### C — Endpoint adversary (compromised device)
- Forensic seizure, malware on device, OS-level compromise.
- Capabilities: full access to whatever the device can decrypt.
- We mitigate, not eliminate. App lock, hardware-backed keys, ephemeral session keys, disappearing messages.

### D — Cryptographic adversary
- Weakness in primitives, side-channels, downgrade attacks.
- We mitigate via algorithm agility, secure defaults, and continuous tracking of cryptographic literature.

## Non-negotiables

1. **End-to-end encryption is on by default for all 1:1 and group chats. There is no opt-in mode and no "secret chat" subset. Everything is encrypted, period.**
2. **The server cannot read message content under any circumstances, including with full root access to the cluster.**
3. **Cryptographic identity is generated on device and never leaves it.** Private keys are stored in Secure Enclave / Strongbox / Keychain / Keystore.
4. **Forward secrecy** for all messages (Double Ratchet).
5. **Post-compromise security** for all messages (Double Ratchet healing property).
6. **Multi-device** without escrow — adding a device requires existing-device authorization.
7. **Open source** for the cryptographic core. Auditable.
8. **Annual independent audit** with public results.
9. **Reproducible builds** for the cryptographic core.
10. **No backdoor**, ever, regardless of jurisdiction or pressure.

## Protocol choices (initial)

### Identity
- **Long-term identity**: Ed25519 signing keypair, generated on device, hardware-backed where possible.
- **X25519 identity** for key agreement.
- **Account ID** = hash(public Ed25519 key). Server-side handles, emails, and phone numbers map to this hash via blinded discovery.

### 1:1 messaging
- **X3DH** for initial key agreement (asynchronous, no live handshake required).
- **Double Ratchet** for the ongoing session.
- **Sealed Sender** so the server does not learn who is sending to whom.

### Group messaging
- Initial choice: **Sender Keys** (Signal Protocol's group flavor).
- Tracked alternative: **MLS** (RFC 9420). We will revisit when MLS implementations stabilize and the group-size advantages clearly outweigh the migration cost.
- Decision deferred to Phase 7.

### Multi-device
- Each device is a first-class identity attached to the account.
- Group keys fan out per device (Sender Keys).
- New device pairing: QR + ephemeral handshake from existing device, transfers per-conversation key material under freshly negotiated pairwise sessions.

### Backup
- Optional, opt-in.
- Argon2id-derived key from user passphrase + hardware-bound salt.
- Server stores ciphertext only.
- Restoring on a new device requires the passphrase. We can tell the user the salt; we cannot recover content if the passphrase is lost.

### Calls (LiveKit)
- ≤ 8 participants: **Insertable Streams E2EE**. The SFU forwards ciphertext frames it cannot decrypt. Keys are rotated per participant join/leave.
- > 8 participants: SFU-trust mode (the SFU sees plaintext frames). Clearly indicated in UI as a different trust state. We will work toward E2EE at higher counts as MLS-based conferencing matures.

### Stories
- Stories from a user are encrypted with a per-story content key.
- The content key is fanned out to the viewing audience over the existing E2E channel.
- Server stores ciphertext stories with a TTL.

### Push
- Push payloads encrypted with a per-device push key.
- Server sees only routing token and a tickle (no thread, sender, or content).
- Token rotates on every push to defeat long-term linkage.

### Search
- On-device: Tantivy with full plaintext index decrypted only in process memory.
- Server-assist (if shipped): tokenized blinded indexes via key the server does not hold.

### AI
- On-device first.
- Cloud invocation is per-request, ephemeral, OHTTP-relayed. No persistent association of identity with content.
- We will publish the AI traffic spec separately.

## Cryptographic primitive choices

| Use | Primitive |
|---|---|
| Symmetric encryption | XChaCha20-Poly1305 (preferred), AES-256-GCM (fallback for hardware acceleration) |
| Hashing | SHA-256, BLAKE3 for performance-sensitive paths |
| Asymmetric KEM | X25519 (current); ML-KEM (Kyber-768) tracked for hybrid in 2026+ |
| Signatures | Ed25519 |
| KDF | HKDF (HMAC-SHA-256) |
| Password KDF | Argon2id |
| Random | OS CSPRNG, mixed with hardware RNG where available |

We will adopt **post-quantum hybrid** key agreement (X25519 + ML-KEM-768) as soon as the libsignal upstream lands it. This is a 2026 decision per current cryptographic guidance; we are tracking it.

## Algorithm agility and crypto rotation

- Every encrypted blob carries a 1-byte algorithm identifier.
- We commit to clean rotation paths: every new algorithm gets a release that decrypts old + new for at least 12 months before old is dropped.
- Key rotation is automatic on a schedule (per-message ratchet) and on events (device added/removed, key compromise reports).

## Secure storage on device

- iOS: Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for hot keys; Secure Enclave for identity keys where the device supports it.
- Android: Keystore with hardware-backed `STRONGBOX_BACKED` where available; user-authentication-bound for the master key.
- Desktop: OS keyring (macOS Keychain, Windows DPAPI/Hello, libsecret). Master key wrapped by user passphrase additionally.
- Local SQLite is encrypted with SQLCipher. The database key is derived from a key in the OS keyring.

## Hardening

- Certificate pinning for all client→server traffic, with a managed pin rotation playbook.
- mTLS between internal services.
- Server-side build artifacts are signed and verified at deploy time.
- All internal admin actions require dual-control (two operators).
- No production access via long-lived credentials. SSO + short-lived assumed roles only.
- Security incident playbook documented and rehearsed twice a year.

## Side channels we are tracking

- Traffic analysis (timing and size). We will explore message size padding and dummy traffic in Phase 7.
- App-layer metadata (group membership inference from delivery fan-out). Sealed Sender + per-recipient envelopes mitigate, do not eliminate.
- Push metadata to APNs/FCM. We can never fully eliminate this; we minimize.
- Screen-recording / accessibility-API exfiltration on the device. OS-level concern; we set platform flags to hint to the OS that screen recording is sensitive.

## What we will not do

- Backdoors, "law enforcement modes," exceptional access. Not under any jurisdiction.
- Server-side scanning of message content for any reason, including CSAM detection. We address abuse via report-with-decryption-key flows initiated by users.
- Telemetry that could de-anonymize users. Crash reports and analytics are scrubbed and aggregated.
- Closed-source cryptographic core.
- Custom cryptography. We use Signal Protocol primitives (audited, peer-reviewed) and standard NaCl/libsodium-equivalent operations. We do not invent.

## Open questions for Phase 7

1. Sender Keys vs MLS for groups, with concrete migration path between them.
2. Default backup passphrase strength enforcement (zxcvbn threshold).
3. Whether the AI gateway should support "fully homomorphic preview" experiments — likely no for 1.0.
4. Decoy / hidden chat mode design.
5. Tor-friendly transport scope for v1 vs v2.

## Public commitments

These are the commitments we will publish on `velix.app/security`:

1. We are end-to-end encrypted for every message, by default, with no exception.
2. We never read your messages. We are technically incapable of reading your messages.
3. Our cryptographic core is open source.
4. We commission independent security audits annually and publish results.
5. We will not introduce a backdoor.
6. We will publish a transparency report quarterly.
