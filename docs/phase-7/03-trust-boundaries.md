# 03 — Trust Boundaries

What each component can see. What can be lost without security loss. What MUST be protected.

## Components and what they hold

| Component | What it sees | What it must protect |
|---|---|---|
| **Server (every backend service)** | Account IDs (hashed pubkey), device IDs, ciphertext envelopes, encrypted media, encrypted push payloads, encrypted backups, LiveKit JWTs, presence | Server-side TLS keys; LiveKit API keys |
| **Client (Flutter app, untrusted bytes path)** | Same as server, before decryption | App-level integrity: signed binaries, App Store / Play Store delivery |
| **`velix_crypto` (Dart binding)** | Pointers and sizes of crypto buffers, type-shaped wrappers around them | Don't leak buffer content via logs, don't keep plaintext alive |
| **`velix_crypto_core` (Rust)** | Plaintext briefly, all session state, derived keys | Zeroize on drop, no logging, constant-time where it matters |
| **OS keychain / Secure Enclave / Strongbox** | Identity keys, master device key (MDK), DB encryption key | Hardware-backed where available; access-controlled by OS |
| **SQLCipher database** | Session state (libsignal's protocol stores), message envelopes locally cached, drafts | Encrypted at rest with a key from the OS keychain |
| **APNs / FCM** | Encrypted push payload + routing token | (We don't trust them; they never see plaintext) |
| **LiveKit cluster** | E2EE call frames (encrypted) for ≤ 8; plaintext frames for > 8 | Server-side AES key for the SFU itself (call's API secret in Vault) |
| **Cloudflare R2** | Ciphertext media objects | (We don't trust R2; we encrypt before upload) |
| **AI gateway (cloud)** | Per-query content the user explicitly sent | OHTTP relay between user and gateway; gateway has no log retention |

## Trust assumption rankings

| Assumption | Ranked (1 = strongest, 5 = weakest) |
|---|---|
| The user trusts their own device | 1 — necessary axiom |
| The user trusts the OS keychain not to disclose to other apps | 1 — platform-level |
| The user trusts the App Store / Play Store binary distribution | 2 — verified signed builds, reproducible |
| The user trusts Velix to not introduce a backdoor | 2 — open-source crypto core, audits, transparency reports |
| The user trusts Velix not to change the protocol via auto-update | 3 — ABI version-pinned, breaking changes are visible |
| The user trusts Signal Foundation to not have backdoored libsignal | 3 — open-source, multi-party audited, in production at scale |
| The user trusts Cloudflare R2 to not collude with Velix | 4 — they can't read the data |
| The user trusts APNs / FCM to not collude with Velix | 4 — they can't read the data |
| The user trusts LiveKit to not record E2EE calls | 4 — they can't decode frames |

The numbers are not casual; they're the explicit sequence of breakages required to defeat a property. A defeat at level N requires defeating all assumptions ≥ N.

## Boundary diagrams

### Identity boundary

```
                 OS keychain  (hardware-backed where available)
                      │
                      │  identity_priv (Ed25519 + X25519)
                      │
       ┌──────────────▼─────────────────────────┐
       │                                        │
       │   velix_crypto_core (Rust)             │
       │     ─ uses identity_priv at sign time  │
       │     ─ holds in memory ≤ duration of op │
       │     ─ zeroizes on drop                 │
       │                                        │
       └──────────────┬─────────────────────────┘
                      │  signature, derived public key
                      │
                  Dart side
                      │
                      │  serialized public material
                      │
                  Server (sees public material only)
```

The identity private key crosses exactly two boundaries: from OS keychain into Rust core for one operation, then dropped. It never touches Dart's GC-managed heap. It never leaves the device.

### Message boundary

```
   Sender device                                 Recipient device
   ─────────────                                 ────────────────
   plaintext      ─encrypt─▶  ciphertext  ─via routing─▶  ciphertext  ─decrypt─▶  plaintext
                                  ▲                          ▲
                                  │                          │
                                  └─── Server only sees this ┘
```

The server is physically incapable of seeing plaintext. The "encrypt" and "decrypt" calls are inside `velix_crypto_core` on each device.

### Backup boundary

```
   Device A                                       Device A (or B, restored)
   ────────                                       ─────────────────────────
   passphrase + DB key  ─wrap─▶  encrypted blob  ─server stores─▶  encrypted blob  ─unwrap─▶  passphrase + DB key
                                       ▲                                                          ▲
                                       │                                                          │
                                       └────── Server sees only ciphertext ──────────────────────┘
```

The passphrase never leaves the device. The DB key never leaves the device unencrypted. The server stores opaque ciphertext.

## Custodial responsibilities

For each piece of key material, the custodian and the consequences of loss:

| Material | Custodian | If lost | If exposed |
|---|---|---|---|
| Identity Ed25519 private | OS keychain | Identity unrecoverable; user must create new identity | Account compromised; revocation via existing trusted devices |
| Master Device Key (MDK) | OS keychain | Local data unreadable; backup-restore required | Local data readable to attacker on this device |
| SQLCipher key | OS keychain (derived from MDK) | DB unreadable; effectively wipe | DB readable on this device only |
| Signed prekey | Local SQLCipher | Auto-replenished | Forward secrecy slightly weakened until rotation |
| One-time prekey | Local SQLCipher | Skipped during X3DH; future messages still secure | One specific X3DH negotiation weakened |
| Double Ratchet root | Local SQLCipher | Session unreadable; need new X3DH | Past messages encrypted with same root vulnerable |
| Sender Keys group key | Local SQLCipher | Group unreadable | Group rotates on next change |
| Backup passphrase | User memory | Backup unrecoverable | Backup readable to attacker |
| Backup DEK | Wrapped on server | Server-side outage = restore can't proceed | (DEK is wrapped; not directly exposed) |
| LiveKit per-call key | RAM only, per call | Call drops a participant | Call decryptable to attacker for duration |

## What the server CAN see (audit truth)

Honest list of what the server learns:

1. Which account IDs are registered.
2. Which device IDs belong to which account.
3. The fact that account A sent something to account B (via the routing service's envelope addressing — even with Sealed Sender, the outer envelope addresses recipient devices).
   - *Sealed Sender hides who sent. It does NOT hide who received.*
4. The size and timing of envelopes.
5. The IP address of the connecting client.
6. The platform string and rough device class.
7. Push tokens (per device).
8. LiveKit room metadata: who joined, who left, when.
9. Media object size, content-type-class (image/video/audio/file), and TTL.

We do **not** hide:
- The fact of communication (timing/metadata).
- Which devices are online when.
- Aggregate traffic patterns.

We do hide:
- Message content.
- The identity of the sender to the routing layer (via Sealed Sender).
- The identity of the user who uploaded a specific media object (the upload is via authenticated session, but the server doesn't relate it to other users until the recipient's client downloads).
- The contents of group messages and which group they belong to (the server doesn't know group structure).
- Profile information beyond the account ID hash.
- Search queries (search runs on-device).
- Read-receipt content (it's an encrypted message).

## Cross-boundary invariants

These hold across every release. CI tests assert each.

| Invariant | Test |
|---|---|
| No private key is sent over the network | Network capture in CI integration test; assert byte patterns absent |
| No plaintext message body appears in any service's logs | Log-scrubbing test on representative traffic |
| Routing service rejects envelopes with sender-info fields | Proto-level enforcement + handler validation test |
| Push payload server-side is opaque ciphertext | Push handler test with peer-side key absence |
| Backup is opaque to server-side decryption attempts | Round-trip test with server-side keys; expects failure |
| LiveKit ≤ 8 calls have E2EE Insertable Streams configured | LiveKit configuration test on issued JWT |
| AI gateway log contains no per-user content | Log scrubber + sample audit |

## When to revisit this document

- A new component is added that holds keys.
- A trust assumption ranking changes (e.g., a CA we depend on is compromised).
- An audit reveals a leak.
- A primitive is rotated (Phase 7 doc 02).

Updates require an explicit changelog entry and audit re-rating.
