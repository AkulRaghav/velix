# 01 — Threat Model

What we defend against. What we accept. What we explicitly do not promise. Numbered for traceability — every later document and code path can reference these.

## Adversaries

### A1 — Network adversary (passive)

Sees TLS metadata, IP routing, traffic timing, packet sizes. Cannot decrypt TLS sessions. Includes ISPs, public Wi-Fi, BGP-level passive collection.

**Capabilities:** observe, log, correlate.
**Cannot:** modify traffic without detection (TLS).

We assume A1 is always present.

### A2 — Network adversary (active)

A1 plus the ability to drop, replay, or inject packets. Includes state-level active interception, malicious cellular base stations, ARP-poisoning hotspots.

**Capabilities:** A1 plus block/delay/reorder.
**Cannot:** forge our TLS certificates without compromising a CA in our pin set.

### A3 — Server-side adversary (full server compromise)

Insider threat, lawful demand, server compromise, jurisdictional change. Includes Velix's own future selves under hostile conditions.

**Capabilities:** full read of any data Velix stores at rest, full read of memory of any service we operate, full read of every Postgres row, every Redis key, every NATS message, every R2 object.

We design to ensure this adversary **cannot read message content under any circumstance**, including with full root access to every cluster.

### A4 — Endpoint adversary (compromised client device)

The user's device is rooted, has malware, is forensically seized, or the user's OS has been backdoored.

**Capabilities:** read whatever the device can decrypt; observe user input; access keychain/keystore items the OS allows.

We mitigate, not eliminate. App lock, hardware-backed keys, ephemeral session keys, disappearing messages, screenshot detection, Reduce-PII surfaces.

### A5 — Cryptographic adversary

Attacker with the knowledge to exploit weak primitives, side-channels, or downgrade attacks.

**Capabilities:** academic — depending on the primitive.
**Cannot:** break our chosen primitives at our chosen parameter sizes within reasonable time horizons.

We mitigate via algorithm agility, secure defaults, and ongoing tracking of cryptographic literature.

### A6 — AI / model adversary

Attacker who attempts to extract user content via the AI gateway path.

**Capabilities:** observe AI traffic, attempt to correlate identity with content.

We mitigate via on-device-first AI; cloud AI is opt-in per query and routed through OHTTP-equivalent privacy relay.

### A7 — Forensic adversary (post-seizure)

Device seized, user separated, forensic toolchain applied.

**Capabilities:** read OS-accessible storage, attempt to extract keys from secure enclaves (varies by platform), apply legal coercion to user.

We mitigate via disappearing messages, hidden chats, panic dismiss, decoy mode (deferred), strict app-lock with biometric.

## Properties we promise

For every property, the corresponding adversary classes it defends against are listed.

| # | Property | Defends against |
|---|---|---|
| P1 | **Confidentiality of message content** | A1, A2, A3, A5, A6 |
| P2 | **Authentication of message source** (sender's identity binding) | A2, A3 |
| P3 | **Integrity of message content** (no undetected modification) | A2, A3 |
| P4 | **Forward secrecy** (compromise of long-term keys does not decrypt past messages) | A4, A5, A7 (post-seizure of new key material) |
| P5 | **Post-compromise security** (compromise heals — future messages secure once the attacker loses access) | A4 (intermittent compromise) |
| P6 | **Replay protection** (a captured ciphertext cannot be re-injected) | A2 |
| P7 | **Sender anonymity vs server** (server doesn't learn who sent to whom) | A3 |
| P8 | **Group authenticity** (only group members can produce valid group messages) | A2, A3 |
| P9 | **Multi-device transparency** (no covert device addition) | A3, A7 |
| P10 | **Verification of correspondent identity** (safety numbers / verification flow) | A2 |
| P11 | **Encrypted at rest on device** | A4 (limited), A7 |
| P12 | **Encrypted in transit on every hop** | A1, A2 |
| P13 | **Encrypted backup** (server cannot read backup) | A3 |
| P14 | **Encrypted media** (server stores only ciphertext) | A3 |
| P15 | **Encrypted push notifications** (APNs/FCM see only ciphertext + routing token) | A3 + push provider |
| P16 | **Encrypted call media (≤ 8)** (LiveKit cannot decode frames) | A3 (for LiveKit cluster) |

## Properties we deliberately do NOT promise

| # | Non-promise | Why |
|---|---|---|
| N1 | Anonymity vs the network | We use a centralized service; A1/A2 know you're talking to Velix. Tor-friendly transport is post-1.0. |
| N2 | E2EE on calls > 8 | LiveKit Insertable Streams E2EE is bounded; the SFU sees plaintext frames in `sfu_trust` mode (UI explicit). |
| N3 | Plausible deniability | Signal Protocol provides cryptographic deniability of authorship; we inherit this property as a side-effect of using it. We don't market it because the legal term-of-art varies. |
| N4 | Defense against an OS-rooted phone | A4 cannot be fully defeated. We can't promise content protection when the OS itself is hostile. |
| N5 | Defense against the user | If the user wants to leak their own messages, the cryptography cannot stop them. (Trivially: take a photo of the screen.) |
| N6 | Anonymity of the act of using Velix | Users who care need Tor + a fresh identity. Velix's centralized routing leaks "this account is using the service" in time. |
| N7 | Server cannot lie about who is online | Presence is server-mediated; the server can lie. Mitigation is "presence isn't security-relevant." |
| N8 | Synchronous read-receipt accuracy across devices | A device may report read while offline; the receipt arrives later. Acceptable. |
| N9 | Resistance to coordinated state-level attack on a specific named target | We promise the *baseline* against state-level attackers. We do not promise that a specific named target is safe from a specific named adversary. |
| N10 | Anti-quantum security today | Post-quantum hybrid (X25519 + ML-KEM-768) is on the roadmap once libsignal upstream lands it. Today's crypto is not quantum-resistant. Tracked. |

## Attack surfaces (audit map)

Every component is reviewed against every adversary. The audit document at `12-phase-7-audit.md` is the complete table.

Abbreviated:

| Surface | Primary adversary class | Mitigation |
|---|---|---|
| Identity creation | A2 (MITM at signup) | Client-generated keys; no server "trust on first use" beyond the UX |
| Sign-in | A1, A2 | Challenge-response with identity-key signature |
| Multi-device pairing | A2, A3 | Out-of-band QR + emoji confirmation |
| Send message | A1, A2, A3 | Sealed Sender + Double Ratchet |
| Receive message | A3 | Server delivers ciphertext only |
| Group message | A3, A8 (rogue group member) | Sender Keys with per-device fan-out |
| Media upload | A3 | Client encrypts with per-message DEK; server stores ciphertext |
| Media download | A3 | Recipient decrypts with wrapped DEK delivered via E2E channel |
| Push notification | A3 + push provider | Encrypted payload, rotating routing token |
| Backup | A3 | Argon2id-wrapped DEK; passphrase never leaves device |
| Restore | A2, A3 | Backup integrity verified before unwrap; failed unwrap is a hard error |
| Call signaling | A3 | Existing E2E channel + LiveKit JWT |
| Call media (≤ 8) | A3 (LiveKit) | Insertable Streams E2EE; key rotation on participant change |
| Call media (> 8) | (downgraded) | Explicit UI; sfu_trust mode |
| AI cloud query | A3, A6 | OHTTP relay; no logs at gateway |
| Local DB | A4 (limited), A7 | SQLCipher with hardware-backed key |

## Operational threat model

Beyond cryptographic adversaries, operational considerations:

- **O1 — Outage.** A service outage must never cause a security regression (e.g., we don't fall back to plaintext for "availability").
- **O2 — Bug.** A cryptographic bug is treated as a security incident with a public post-mortem. Reproducible builds and audited diffs reduce risk.
- **O3 — Pressure.** Government legal demands or commercial pressure cannot compromise the protocol. Architectural constraints (server cannot read content) outlast policy decisions.
- **O4 — Drift.** Each release is checked against the threat model. New features that reduce a property number above are blocked or downgraded with explicit user notice.

## Public commitments

These appear at `velix.app/security`:

1. End-to-end encryption for every message, by default, with no exception.
2. We never read your messages.
3. Our cryptographic core is open source under a permissive license.
4. We commission independent security audits annually and publish results.
5. We will not introduce a backdoor.
6. We publish a transparency report quarterly.

These are technical commitments backed by architecture, not policy commitments backed by promises.

## Banned behaviors

- "Secret chat" mode opt-in — encryption is always on.
- Plaintext fallback on protocol error.
- Server-side scanning of any content.
- Cryptography we invented ourselves (we use Signal primitives only).
- Unaudited cryptographic libraries.
- Using TLS as the only confidentiality layer (TLS is in addition to E2E, not instead of).
- Caching decrypted content beyond the rendering frame.
- Logging any decrypted byte at any level.
- Sending any error detail that could distinguish "decryption failed because key wrong" from "decryption failed because ciphertext malformed" to the server (those error classes leak information).
