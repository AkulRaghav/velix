## 02 — Cryptographic Primitives

The complete primitive table. Every byte that crosses Velix's encryption boundary is processed by something on this list. Nothing else.

## Primitives

### Asymmetric

| Use | Primitive | Source | Notes |
|---|---|---|---|
| Identity signing | **Ed25519** | libsignal / curve25519-dalek | 32-byte public, 64-byte signatures |
| Long-term key agreement | **X25519** | libsignal / curve25519-dalek | 32-byte public; combined with Ed25519 via the `curve25519` extension trait in libsignal |
| Ephemeral key agreement (per-message) | **X25519** | libsignal | Used inside Double Ratchet |
| (Tracked) Post-quantum hybrid | **ML-KEM-768** alongside X25519 | upstream, when libsignal lands it | 2026+ rotation |

### Symmetric AEAD

| Use | Primitive | Parameters |
|---|---|---|
| Per-message body | **XChaCha20-Poly1305** | 24-byte nonce, 32-byte key, 16-byte tag |
| Hardware-accelerated path (where Argon2id-derived) | **AES-256-GCM** | 12-byte nonce, 32-byte key, 16-byte tag |
| Local DB at rest | **SQLCipher (AES-256-CBC + HMAC-SHA-512)** | 16-byte block, 64-byte HMAC tag |
| Media | **XChaCha20-Poly1305** | per-message DEK, 24-byte nonce |
| Backup | **XChaCha20-Poly1305** | per-backup DEK, 24-byte nonce |

We prefer **XChaCha20-Poly1305** as default AEAD because:
- 24-byte nonce eliminates nonce-reuse risk under high message counts.
- ChaCha20 is constant-time on every CPU we ship to.
- The construction has fewer footguns than AES-GCM under high-message-count regimes.

We use **AES-256-GCM** only where hardware acceleration matters (file encryption on devices with AES-NI). Both are AEAD; neither carries plaintext outside the construction.

### Hash & MAC

| Use | Primitive |
|---|---|
| Identity hash (account ID) | SHA-256 |
| HMAC | HMAC-SHA-256 |
| Performance-critical hashing (Sender Keys derivation, etc.) | BLAKE3 |
| Safety-number fingerprint | SHA-256 truncated to 30 digits (encoded in 6 emoji) |

### KDF

| Use | Primitive | Parameters |
|---|---|---|
| Session key expansion | **HKDF** with HMAC-SHA-256 | salt, info per-context |
| Password / passphrase derivation | **Argon2id** | memory 64 MiB, parallelism 4, iterations tuned to ≈ 1000ms on iPhone 12 |
| Per-context key derivation in Double Ratchet | HKDF | inside libsignal |

### Random

- OS CSPRNG: `getrandom(2)` on Linux, `arc4random_buf` on iOS/macOS, `BCryptGenRandom` on Windows, `/dev/urandom` on legacy Android (rare).
- We mix with hardware RNG (`RDRAND` / Apple Secure Enclave RNG) where available, via XOR — never replacement.
- Every random call goes through a single `Csprng` type in the Rust core. No use of `rand::thread_rng()` directly.

## Algorithm agility

Every encrypted blob in Velix carries a 1-byte version prefix:

```
0x01  v1: XChaCha20-Poly1305 over Signal Protocol primitives (X25519 + Ed25519)
0x02  v2: (planned 2026) XChaCha20-Poly1305 over X25519+ML-KEM-768 hybrid
0x03+ reserved
```

Version 1 is the only deployed version at Phase 7 ship. Receivers MUST handle every documented version; senders write the highest version they support and the recipient supports.

## Key sizes

| Key | Size |
|---|---|
| Identity Ed25519 private | 32 bytes |
| Identity Ed25519 public | 32 bytes |
| X25519 private | 32 bytes |
| X25519 public | 32 bytes |
| AEAD key | 32 bytes |
| HMAC key | 32 bytes |
| Argon2id-derived key | 32 bytes |
| SQLCipher key | 32 bytes |
| Push routing seed | 32 bytes |

We do not use 16-byte keys anywhere. We do not use 24-byte keys anywhere. 32 bytes is the system-wide minimum.

## Nonces

| Use | Source |
|---|---|
| Per-message AEAD nonce inside Double Ratchet | Derived deterministically from the chain key + message number; never user-controlled |
| Media nonce | Random 24 bytes (XChaCha20) |
| Backup nonce | Random 24 bytes |
| Push payload nonce | Random 24 bytes |

The Rust core never accepts a nonce parameter from Dart. Nonces are produced internally per construction; this defeats nonce-reuse-via-API-misuse.

## Length limits

| Field | Limit | Reason |
|---|---|---|
| Plaintext message body | 64 KB | Matches the routing service envelope cap; anything larger is media |
| Sender Keys group size | 5,000 devices | Distribution cost grows linearly; beyond this, MLS or channel broadcast |
| Backup size | 1 GB | DB at the largest expected user |
| Media single object | 4 GB | R2 limit |

## Padding

Message bodies are padded to multiples of 256 bytes inside the AEAD construction. This defeats simple traffic-analysis-by-size attacks (e.g., distinguishing "yes" from "I love you").

We do NOT pad to a single fixed size — that would be wasteful at scale. The 256-byte bucket is a tradeoff: enough to coalesce typical short messages; not enough to inflate every payload by 4x.

## Constants and KDF labels

Each KDF call has a constant `info` label so derivations are domain-separated. Examples:

```
"velix.identity.kdf.v1"
"velix.session.root.v1"
"velix.session.chain.v1"
"velix.media.dek.v1"
"velix.backup.dek.v1"
"velix.push.seed.v1"
"velix.livekit.frame.v1"
```

Domain separation prevents an attacker from coercing two contexts into deriving the same key.

## Rotation policy

| Key class | Rotation cadence |
|---|---|
| Per-message keys (Double Ratchet chain) | every message (intrinsic) |
| Per-conversation root key | rotates with each new ratchet (every receive of a new ephemeral) |
| Sender Keys group key | rotates on join/leave of any participant |
| One-time prekeys | consumed once; replenished automatically |
| Signed prekey | rotates every 7 days (client publishes new) |
| Identity key | once per device; never rotates without a new identity |
| Master device key (MDK) | manually on user request, or on detected compromise |
| Backup DEK wrapping | regenerated on each backup |
| Push routing seed | rotates per push (every push) |
| LiveKit per-call key | rotates on participant change |

## What we do NOT use

- **MD5, SHA-1, SHA-512** — outdated, broken, or unnecessarily slow.
- **RSA** — Ed25519 / X25519 are smaller, faster, and have fewer footguns.
- **DSA, ECDSA** — Ed25519 is strictly better.
- **CBC mode** — except inside SQLCipher (where the construction is HMAC-protected and well-audited as a whole).
- **CTR mode without authentication** — banned. AEAD only.
- **PBKDF2** — Argon2id is strictly better for password hashing.
- **HKDF without info** — every call has a domain-separation label.
- **scrypt** — Argon2id is the modern choice.

## Forbidden patterns

- Two AEAD operations under the same `(key, nonce)` pair.
- Truncated keys ("save 16 bytes by truncating SHA-256").
- Encrypt-then-MAC with separate keys (use AEAD).
- MAC-then-encrypt (broken; use AEAD).
- Hash-then-encrypt without authentication.
- Manual key derivation via XOR.
- Use of any cryptographic library not in the table at the top of this document.

## Tracked: post-quantum

ML-KEM-768 (formerly Kyber-768) is on the roadmap once libsignal upstream lands hybrid X25519 + ML-KEM-768 key agreement. Velix will adopt it within 90 days of upstream release.

We are not deploying experimental post-quantum primitives ahead of upstream. Cryptographic conservatism wins here.

## Annual review

The primitive table is reviewed annually and after any of:
- A primitive is publicly broken.
- A primitive's underlying assumption is weakened.
- libsignal upstream changes the primitive.
- A peer-reviewed paper recommends rotation.

Each review produces a public changelog entry on `velix.app/security/changelog`.
