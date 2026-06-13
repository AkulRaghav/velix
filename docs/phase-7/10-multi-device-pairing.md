# 10 — Multi-Device Pairing

The flow that adds a second (or third, fourth) device to an existing identity without exposing the identity private key over a network.

## Problem statement

A user has an identity on Device A. They install Velix on Device B. We need to:

- Bind Device B to the same identity (account_id) as Device A.
- Issue Device B its own per-device key material.
- Allow Device A to vouch for Device B cryptographically (so other users can verify the new device is legitimate).
- Optionally transfer the user's conversation history.
- Defeat the threat that an attacker registers a rogue device under the user's account.

## Threat model for pairing

- A1 / A2: network attacker may try to MITM the pairing handshake.
- A3: server may try to add a rogue device covertly.
- A4: a compromised Device A could pair an attacker's device.

We mitigate via out-of-band human verification (QR + emoji confirmation), short-lived pairing tokens, and identity-attested device certificates.

## High-level flow

```
Device A (existing)                         Device B (new)
─────────────────                            ──────────────

1. User taps "Add a device" on A.
   A generates a 32-byte ephemeral nonce + a 6-character display code.
   A renders a QR encoding (account_id, ephemeral_nonce, A_X25519_pub_eph).

                                           2. User installs Velix on B.
                                           3. B prompts "Pair with existing device".
                                           4. User scans the QR with B's camera.
                                              (Or types the 6-character code as fallback.)

5. B reads (account_id, ephemeral_nonce, A_pub_eph) from the QR.
6. B generates its own ephemeral X25519 keypair (B_priv_eph, B_pub_eph).
7. B generates its own long-term device X25519 keypair (B_dev_priv, B_dev_pub).
8. B computes shared = DH(B_priv_eph, A_pub_eph).
9. B derives a confirmation key:
     conf_key = HKDF(shared, salt=ephemeral_nonce, info="velix.pair.conf.v1", len=32)
10. B computes 6 emoji from a 30-bit truncation of HMAC(conf_key, "velix.pair.emoji.v1").

11. B publishes (B_pub_eph, B_dev_pub, B_platform, ...) to a temporary
    pairing endpoint on identity service, addressed by `account_id` and
    `ephemeral_nonce`. This is a pre-paired channel; identity service
    holds it for 5 minutes.

12. A polls the pairing endpoint, receives B's payload.
13. A computes shared = DH(A_priv_eph, B_pub_eph).
14. A derives the same conf_key + 6 emoji.
15. A displays the 6 emoji to the user.

                                           16. B displays the 6 emoji to the user.

17. User compares the emoji on both screens.
    - Match → user taps "Confirm" on A.
    - Mismatch → user aborts; pairing fails.

18. A signs an attestation:
      attestation = Ed25519_sign(identity_priv,
        "velix.device_attestation.v1" || B_dev_pub || B_device_id || timestamp)

    A also emits an X3DH session-establishment payload to B (so B has an
    immediate session with A).

19. A submits attestation to `identity.AddDevice` (B_dev_pub, attestation, ...).
20. Identity service verifies attestation against account's identity_pub.
21. Identity service inserts a `devices` row for B.
22. Identity service emits `velix.device.paired` (Phase 6 doc 06).

23. B receives confirmation via the same pairing endpoint.
24. B persists its long-term keys (B_dev_priv, identity_pub copy) into its
    OS keychain + SQLCipher.
25. B is now signed in.

26. (Optional) A initiates encrypted history transfer to B (next section).
```

## Key derivation security

The confirmation emoji are derived from a *real* X25519 DH between two ephemeral keys + a session-specific salt (the ephemeral_nonce). An MITM would need to:

- Substitute their own X25519 public for A_pub_eph in the QR code (visual; defeated by out-of-band scanning).
- Substitute their own X25519 public for B_pub_eph in the pairing endpoint payload (defeated by user comparing emoji on the legitimate B's screen).

If the user dutifully compares the 6 emoji and they match, the pairing is authenticated. If they don't match, the user aborts — the channel was MITM'd.

## Why 6 emoji from 30 bits

- 30 bits → 1 in 1 billion collision probability for an MITM trying to fake a match.
- 6 emoji from a curated set of ~700 emoji is human-readable, language-neutral, easy to compare.
- The set of emoji is fixed; the algorithm is deterministic; identical conf_key produces identical emoji.

The emoji set is published in `cryptocore/data/emoji_set_v1.json` and committed to the repo.

## Failure handling during pairing

| Failure | Behavior |
|---|---|
| QR scan times out (5 min) | Pairing aborted; user must restart from A. |
| Network failure during step 11 or 18 | Pairing aborted; B retries with a fresh QR. |
| Emoji don't match | User aborts; we do NOT retry automatically — emoji mismatch is a real security event. |
| Attestation signature invalid (server-side) | Identity service rejects AddDevice; B is not paired. |
| User adds the wrong device by accident | User can revoke any device from any other trusted device. |

## Server-side AddDevice contract (Phase 6 reference)

```proto
rpc AddDevice(AddDeviceRequest) returns (AddDeviceResponse);

message AddDeviceRequest {
  string idempotency_key       = 1;
  bytes  device_public_key     = 2;
  bytes  attestation_signature = 3;
  string device_name           = 4;
  string device_platform       = 5;
}
```

The identity service:

1. Reads the calling client's account_id from the bearer token.
2. Verifies attestation_signature against accounts.identity_pubkey.
3. Inserts devices row.
4. Returns the new device_id, attestation_signature, paired_at.
5. Publishes velix.device.paired.

A failed signature returns INVALID_ARGUMENT with reason=`ATTESTATION_INVALID`.

## What goes wrong if pairing is hostile

If the attacker controls Device B (e.g., they stole the user's phone after they unlocked it briefly):

- Attacker can scan A's QR and complete pairing (because the user's device A trusts whoever scans the QR).
- The real defense here is the 6-emoji confirmation: A waits for the user's confirmation tap before issuing the attestation.
- Attacker's only way past this is if they also control device A, in which case the pairing is irrelevant (they already have access).

## History transfer

Optional, post-pairing. Triggered by user action ("Sync history to this new device"):

```
1. Device A serializes its protocol-store state for the conversations the
   user wants to transfer (default: all). Includes Double Ratchet sessions,
   Sender Keys for groups the user is in, identity records.

2. A encrypts the bundle to B's just-paired device key:
     bundle_key = HKDF(DH(A_dev_priv, B_dev_pub), salt=zero,
                       info="velix.history_transfer.v1", len=32)
     ciphertext = AEAD(bundle_key, nonce=random_24, plaintext=bundle)

3. A uploads ciphertext to a short-lived holding pen on the routing service.
   Holding pen TTL: 24 hours; then deleted.

4. B downloads ciphertext + nonce.
5. B derives bundle_key the same way (via DH(B_dev_priv, A_dev_pub)).
6. B AEAD-decrypts.
7. B imports the protocol-store state into its own SQLCipher.
8. B sends "Got it" to A. A may delete the holding-pen entry.
```

## What's NOT in history transfer

- The user's actual messages from the local DB (those are inside the per-conversation state but limited to the on-device retention window — typically the past 90 days).
- Media files (the encrypted blobs are still on R2; B's client downloads on demand using the wrapped DEKs in the history bundle).
- Drafts, scroll positions, view states.
- Telemetry breadcrumbs.

## Multi-device key fan-out

Once paired, every group with the user as a member needs to fan out new messages to B's device. This happens automatically:

- When other members send to the group, their clients fetch the new device list (via group membership refresh) and produce per-device envelopes for B.
- The Sender Keys distribution message for new senders is sent from each existing sender to B via the standard E2E channel.

There is a brief window (≤ 60 seconds typically) where group sends might miss B if other members haven't refreshed their device lists. The recovery is automatic; missed messages arrive when the senders' clients catch up.

## Pairing rate limit

The server rate-limits pairing attempts to prevent abuse:

- 3 pair-attempts per 60-min window per account.
- Excess returns `RESOURCE_EXHAUSTED`.

## Banned

- Skipping the emoji confirmation.
- Hardcoded ephemeral nonces.
- Reusing ephemeral keys across pairings.
- Sending the identity private key to the new device (it's per-device; identity_pub is enough; the device gets its own X25519 keypair).
- Pairing without an attestation from an existing device.
- Server-issued attestations (the server cannot vouch for a new device; only the user's existing devices can).
- History transfer without re-encryption to the new device's key.
