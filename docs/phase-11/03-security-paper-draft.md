# 03 — Public Security Paper (Draft)

> **Status:** Draft. Awaits independent cryptographer review (engagement scheduled per Phase 11 doc 02 item C4) and legal counsel review.
>
> **Will be published at:** `velix.app/security`
>
> **Length:** Target 6–10 pages of HTML, excluding linked specs.
>
> **Audience:** Technically literate readers — engineers, security researchers, journalists, sophisticated users. Plain language; no marketing inflation.

---

# Velix Security

## What we promise

Velix is built so that the people who run Velix cannot read your messages. This is the property everything else is shaped around.

We promise sixteen things. Each is a technical claim, not a marketing line. Each is enforced by architecture and verifiable by independent audit.

1. **Every message is end-to-end encrypted, by default.** No "secret chat" mode. There is no path to plaintext on Velix's servers.
2. **Velix's servers cannot read your messages, even with full administrative access to our cluster.** This is enforced by the protocol design, not by policy.
3. **Forward secrecy.** If your device is compromised today, messages from yesterday remain secure.
4. **Post-compromise security.** If an attacker briefly gains access, future messages secure themselves automatically.
5. **Replay protection.** A captured ciphertext cannot be re-injected.
6. **Authentication of message source.** A message displayed as "from Quinn" cryptographically came from Quinn's device.
7. **Sender anonymity from the server.** Velix's routing service does not learn who sent a message; only that the recipient should receive one. This is "Sealed Sender."
8. **Group authenticity.** Only group members produce valid group messages.
9. **Multi-device transparency.** Adding a device to your account requires authorization from an existing trusted device. We never silently add devices.
10. **Verifiable identity.** You can verify the cryptographic identity of any contact via QR-scan and emoji confirmation.
11. **Encrypted at rest on your device.** Local data is held in an encrypted database keyed from the operating system's hardware-backed keychain.
12. **Encrypted in transit on every network hop.** TLS 1.3 to our edge; mutual TLS internally.
13. **Encrypted backups.** Your backup is encrypted with a key derived from a passphrase you choose. We hold ciphertext only.
14. **Encrypted media.** Photos, videos, voice notes, and files are encrypted on your device before upload. Our object storage holds opaque ciphertext.
15. **Encrypted push notifications.** Push payloads are encrypted before they reach Apple or Google. APNs and FCM see opaque bytes.
16. **End-to-end encrypted voice and video calls** for groups of up to eight participants. Larger calls fall back to a server-aided mode that is clearly indicated in the user interface.

## What we explicitly do not promise

Honest disclosure matters more than marketing.

- **We do not promise anonymity from the network.** Your ISP knows you use Velix.
- **We do not promise end-to-end encryption on calls larger than eight participants.** Those calls use a server-aided mode and the interface tells you so.
- **We do not promise resistance to a compromised device.** If your phone is rooted, the operating system itself can read your messages — this is not something Velix can prevent.
- **We do not promise resistance to the user.** If you choose to share a message, take a screenshot, or read your screen aloud, no cryptographic system stops you.
- **We do not promise quantum-resistant cryptography today.** Our protocols use Curve25519, which is broken by a sufficiently large quantum computer. The Signal Foundation is working on a hybrid post-quantum upgrade for libsignal; we will adopt it within ninety days of upstream release.
- **We do not promise resistance to traffic analysis.** A determined network observer can correlate your activity timing and volume even without reading your messages. Defenses against this — mixnets, cover traffic — are not in the 1.0 release.

## How we deliver these properties

### Cryptography

Velix's cryptographic core is Signal Foundation's `libsignal-protocol`, the same library used by Signal and (for the messaging path) by WhatsApp. We do not invent cryptography; we implement Signal's protocols using their audited library.

The protocols:

- **X3DH** (Extended Triple Diffie-Hellman) for asynchronous initial key agreement.
- **Double Ratchet** for ongoing message session keys, providing forward secrecy and post-compromise security.
- **Sender Keys** for group messaging.
- **Sealed Sender** for sender anonymity from the server.

We use these in their canonical form. A separate "Cryptography Specification" document describes each in detail; this is the user-facing summary.

### Identity

Your account is a cryptographic key pair generated on your device the first time you sign up. Your account ID is a hash of the public half. We do not require a phone number or an email address; you may optionally attach a handle or email for discovery purposes, both of which are stored as cryptographic hashes (HMAC) on our servers — we do not see the plaintext.

Adding a second device requires authorization from your existing device, via a QR scan and a six-emoji visual confirmation. We never silently add devices to your account.

### Backups

You may optionally back up your local data to our servers. The backup is encrypted with a key derived from a passphrase that you choose. We hold the ciphertext; we cannot decrypt it. If you forget your passphrase, we cannot recover the backup.

### Calls

Voice and video calls of up to eight participants use end-to-end encryption via WebRTC's Insertable Streams API. The Selective Forwarding Unit (SFU) — the server that routes call media — sees only encrypted frames it cannot decode.

Calls of more than eight participants fall back to a server-aided mode. The user interface clearly indicates the mode at call invitation time. We do not silently downgrade.

### Media and push

Media files are encrypted on your device before upload. Our object storage holds ciphertext only. Push notifications carry encrypted payloads; APNs and FCM see only an opaque blob and a routing token.

## How you can verify our claims

We are open about how Velix works. We are open about what we cannot prove without external review.

### Open source

Our cryptographic core (`cryptocore`) is open source under the Apache 2.0 license at `github.com/velix/cryptocore`. The code is auditable by anyone.

### Reproducible builds

Two builds of `cryptocore` from the same source produce bit-identical artifacts. The build hash for every release is published at `velix.app/security/builds`. You can verify that the binary distributed to your device matches the published hash.

### Annual independent audits

We commission an independent third-party security audit of `cryptocore` and our integration of it. The first audit's results are published in full at `velix.app/security/audits`. We do not redact findings; if an issue is identified and fixed, we say so. If an issue is identified and unfixed, we say so.

The audit cadence is annual. The first audit was performed by [TBD: audit firm name to be inserted post-engagement] and completed in [date]. The next audit is scheduled for [date].

### Bug bounty

We run a coordinated vulnerability disclosure program. Researchers who find issues can submit at `velix.app/security/disclose` for monetary recognition and credit. Categories and payouts are documented there.

### Transparency reports

Quarterly, we publish a transparency report at `velix.app/transparency` covering:

- Total number of users and aggregate metrics.
- The number of legal requests received and how we responded.
- The categories of data we collect (and do not).

We have nothing to hide about what we do. The transparency report exists to demonstrate this on a regular cadence.

## What changes if we are subpoenaed

A government agency or law enforcement body can compel us to disclose what we have. We have:

- The fact that an account exists, when it was created, and when it last connected.
- The IP address of the most recent connection.
- The set of devices registered to the account.

We do not have:

- The contents of any message you have sent or received.
- Your contacts.
- Your conversation graph (with whom you communicate).
- Your call audio or video.
- Your media files in plaintext.

If we are subpoenaed for these things, we cannot produce them. They do not exist on our servers. This is the architectural property — not a policy choice we could later reverse.

## What changes if we are compromised

If our cluster is breached and the attacker has full read access:

- They can read account IDs, device IDs, encrypted message envelopes, encrypted media files, encrypted backups.
- They cannot decrypt any of this content. The keys are on user devices.
- They can disrupt service (delete data, drop connections). They cannot exfiltrate plaintext.

We design assuming we will be breached someday. The architectural goal is to make a breach uninteresting.

## What we will never do

These commitments are absolute, backed by architecture rather than policy:

- We will never introduce a backdoor.
- We will never weaken encryption "for compliance" with any jurisdiction.
- We will never read your messages — we cannot.
- We will never train AI on your messages.
- We will never sell your data.
- We will never use surveillance trackers in the app.
- We will never quietly change our privacy posture without public disclosure.

Each of these is a technical commitment, not a corporate policy. Even a future Velix under different ownership could not make these claims true again without a complete protocol redesign — visible in the open-source code.

## Where to read more

- **Cryptographic specification:** `velix.app/security/spec` — the precise protocols, primitives, key sizes, and algorithm identifiers.
- **Threat model:** `velix.app/security/threat-model` — adversaries we defend against, properties we deliver, residual risks we accept.
- **Audit reports:** `velix.app/security/audits` — full reports from independent firms.
- **Build verification:** `velix.app/security/builds` — per-release hashes and verification instructions.
- **Vulnerability disclosure:** `velix.app/security/disclose` — how to report issues; bounty terms.
- **Transparency report:** `velix.app/transparency` — quarterly disclosures.

## Contact

- Security issues: `security@velix.app` (PGP key available; responses within 48 hours).
- Privacy questions: `privacy@velix.app`.

---

> **End of public security paper.**
>
> Reviewer notes: this draft makes ten architectural claims as bullets, each backed by Phase 7 documents in this monorepo. The cryptographer review should verify (a) each claim is technically accurate, (b) the language is precise where it needs to be precise and accessible where it can be accessible, (c) the non-promises section honestly reflects our limitations, and (d) the "what we will never do" section does not overreach beyond what architecture enforces.
>
> Suggested edits welcome at the [internal review URL].
