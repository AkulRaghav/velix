# 15 — Identity Verification (Safety Numbers)

The optional but emphasized flow that lets two users confirm their cryptographic identities match. Once verified, the conversation gains the `verified` trust state (Phase 2 doc 01); future identity changes raise the `rekeyed` state.

## What gets verified

For a conversation between A and B, the safety number is a fingerprint over both parties' identity public keys:

```
fingerprint = SHA-256(
                  "velix.safety_number.v1" ||
                  account_id_A || identity_pub_A ||
                  account_id_B || identity_pub_B
              )
```

The fingerprint is order-independent: A and B compute the same bytes by sorting `(account_id, identity_pub)` pairs lexicographically before hashing.

The fingerprint is 30 bytes (240 bits, truncated from SHA-256). 240 bits is the standard Signal-Foundation choice; collision probability is far below any practical attack.

## Display

```
30 bytes →
   60 hex digits, displayed as 12 groups of 5 hex digits → "ABCDE FGH12 ..." (12 groups)
```

Velix displays this as a QR code that the other party scans. A textual-numeric fallback exists but is rarely used.

## QR scan flow

```
Alice's screen:
    [QR code encoding fingerprint]
    "Have Bob scan this with their camera."

Bob scans:
    Bob's app reads the fingerprint from the QR.
    Bob's app computes its own fingerprint locally.
    Bob's app compares.
    If match:
        Display green "Verified."
        Mark Alice's identity record as verified in Bob's protocol store.
    If mismatch:
        Display red "Mismatch! Identities differ."
        Conversation marked rekeyed.
        User offered the option to re-establish session.
```

Only one party needs to scan; the verification happens locally on the scanner's side. The scanner could share their verified result with the scannee via the standard E2E channel ("I verified you"), but this is not security-critical — each party verifies for themselves.

In Velix UI, both parties get a "verified" indicator in the conversation header after the scan. The visual material change (Phase 2 doc 02 — `material.modifier` warmth shift) telegraphs the state.

## Audio verification (alternative)

For users without two devices in the same room:

- Alice reads the 12 groups of 5 hex digits aloud.
- Bob types them into their app.
- Bob's app computes its own fingerprint and compares.

We support this but it's clunkier. The QR scan is the primary flow.

## Trust state machine

```
unverified → (any successful X3DH session establishment) → standard
            ↓
            (user verifies via QR/audio) → verified

verified → (peer's identity_pub changes for any reason) → rekeyed
                                         (alert + re-verification prompt)

rekeyed → (user re-verifies) → verified

any state → (user marks distrust) → unverified
```

The `rekeyed` state is the most sensitive. It happens when:
- Peer's device is rebuilt (new install, new identity).
- Peer's account is compromised and they re-key.
- A network-level MITM successfully substituted an identity_pub at session establishment.

The visual signal (Phase 2 doc 02 trust tints) is sustained until the user takes action. We do not auto-verify.

## What the application should display

When a peer's identity changes:

- An inline message in the conversation: "Quinn's encryption changed. Last verified Tuesday. Verify again to be sure."
- The conversation header shifts to the rekeyed material variant.
- The `Verify identity` button in the conversation info sheet is highlighted.

## What the application should NOT do

- Block message exchange. The user can still send / receive; they're warned, but not gated.
- Auto-trust. We never silently accept a key change.
- Auto-prompt verification on every session establishment. It's opt-in for users who care.

## Per-device or per-identity?

Verification binds to **identity**, not device. A user with 3 devices has one fingerprint; verifying with one of their devices verifies the identity.

When a user pairs a new device, the identity attestation (Phase 7 doc 10) chains to the same identity. The fingerprint doesn't change. Existing verifications stay valid.

If a user **creates a new identity** (e.g., on lost-device recovery), their fingerprint changes. All previous verifications become stale. Contacts will see the rekeyed state and need to re-verify.

## Server-side surface

The identity service stores:

```sql
CREATE TABLE _internal_identity_pubkey_history (
  account_id          text REFERENCES accounts(id),
  identity_pubkey     bytea NOT NULL,
  recorded_at         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, identity_pubkey)
);
```

This is a *informational* record — not a source of truth. The protocol store on each device is the source of truth for what identity_pub is currently trusted.

The history table allows an audit answer: "When did this account's identity change?" — useful for incident response.

## libsignal mapping

In libsignal terms:

- `Fingerprint` is a built-in struct.
- `displayable_format` produces the 60-hex-digit string.
- `scannable_format` produces the QR-encoding bytes.
- `compare(other)` returns boolean.

Velix exposes these via the FFI binding.

## Banned

- Verification flows that expose only public-key bytes (no fingerprinting).
- Skipping the order-independence (one party hashing in a different order produces a different fingerprint).
- Using a different fingerprint construction than the libsignal-Foundation standard.
- Auto-trusting after a single failed scan ("user retried; they probably meant it").
- Verification that only checks a subset of the identity_pub bits (truncating defeats the construction's collision resistance).
- Storing the fingerprint plaintext server-side (it's a function of public material; safe per se, but no need).
