# 06 — X3DH Initial Handshake

X3DH is Signal's asynchronous initial-key-agreement protocol. We use libsignal's implementation; this document specifies how Velix integrates it.

## Why X3DH

A user opens a conversation with a peer for the first time. The peer may be offline. We need to:

- Establish a shared secret without an online peer.
- Provide forward secrecy.
- Bind the handshake to both parties' long-term identities.

X3DH does this with one key bundle from each side and one optional ephemeral message.

## Bundle composition

Per recipient device, the server stores:

```
identity_pub        Ed25519 public key (account-level, 32 B)
device_pub          X25519 public key  (per-device, 32 B)
signed_prekey       X25519 public key  (rotates every 7 days, 32 B)
signed_prekey_sig   Ed25519 signature of signed_prekey by identity_priv (64 B)
one_time_prekey     X25519 public key  (consumed once)
```

The bundle's purpose is to allow a sender to compute a shared secret with the recipient device asynchronously.

## Bundle publication (recipient → server)

When a device first registers, and on every signed-prekey rotation, the client calls `identity.PublishPrekeys`:

```
PublishPrekeys {
  signed_prekey:           bytes
  signed_prekey_signature: bytes
  signed_at:               timestamp
  one_time_prekeys:        repeated bytes  (~100 at a time)
}
```

The server stores them in `prekey_bundles` and `one_time_prekeys` (Phase 6 doc 04).

## Bundle fetch (sender → server)

When a sender wants to establish a session with a peer device:

```
FetchPrekeyBundle {
  account_id: string
  device_id:  string
}
```

The server returns:

```
identity_public_key:       bytes
signed_prekey:             bytes
signed_prekey_signature:   bytes
one_time_prekey:           bytes (may be empty if exhausted)
```

The server consumes one one-time prekey atomically (`UPDATE one_time_prekeys SET consumed_at = now() WHERE id = (SELECT id FROM one_time_prekeys WHERE account_id = $1 AND device_id = $2 AND consumed_at IS NULL ORDER BY id LIMIT 1) RETURNING prekey`). If none are available, the bundle is returned without the one-time prekey field (X3DH proceeds without it; security degrades slightly).

## Sender-side X3DH

```
sender:
  generate ephemeral X25519 keypair (eph_priv, eph_pub)

  verify Ed25519 signature on signed_prekey using identity_pub
  if verification fails → abort, mark conversation as untrusted

  compute four DH operations:
    DH1 = DH(identity_priv, signed_prekey)
    DH2 = DH(eph_priv, identity_pub)
    DH3 = DH(eph_priv, signed_prekey)
    DH4 = DH(eph_priv, one_time_prekey)   // omitted if no OTPK was returned

  derive shared secret:
    SK = HKDF(salt=zero, ikm=DH1||DH2||DH3||DH4, info="velix.x3dh.v1", len=32)

  delete eph_priv (zeroize)

  initialize Double Ratchet with SK as the root key.
  send first message containing:
    - Ed25519 identity_pub of sender
    - eph_pub
    - one_time_prekey id used (or null)
    - encrypted body (the first ratchet output)
```

## Recipient-side X3DH

```
recipient:
  receive first message:
    - extract identity_pub_sender, eph_pub, one_time_prekey id, ciphertext

  look up the corresponding one_time_prekey (and mark it consumed locally if not already)

  compute the four DH operations symmetrically:
    DH1 = DH(signed_prekey_priv, identity_pub_sender)
    DH2 = DH(identity_priv, eph_pub)
    DH3 = DH(signed_prekey_priv, eph_pub)
    DH4 = DH(one_time_prekey_priv, eph_pub)

  derive SK = HKDF(...)  same parameters as sender

  initialize Double Ratchet with SK; decrypt the first message.

  if ciphertext fails to decrypt → reject the X3DH; sender must retry.
```

## Authenticity

X3DH binds the handshake to both parties' long-term identity keys via DH1 (sender's identity_priv → recipient's signed_prekey, signed by identity). An MITM cannot forge a session without both endpoints' identity private keys.

The signed_prekey is signed by the recipient's identity, so a server cannot substitute a fake signed_prekey without breaking Ed25519.

## Forward secrecy at handshake time

The ephemeral key is one-time. Even if the sender's identity private key is later compromised, an attacker cannot reconstruct the eph_priv (which was never persisted) and therefore cannot decrypt the captured first message.

The one-time prekey contributes additional forward secrecy. If the OTPK is exhausted (no DH4), forward secrecy is still provided via the eph_priv but is slightly weaker because compromise of the recipient's signed_prekey would expose the session. We log this as `velix_x3dh_no_otpk_total` for monitoring.

## Replay protection

The first message's nonce is derived inside the Double Ratchet from the sender's chain key (initialized from SK). A replayed first message would re-derive the same nonce, but the ratchet state on the recipient side has already advanced. The replay decrypts as a no-op or fails to decrypt.

Specifically:
- If the same X3DH ciphertext is replayed before the recipient has processed it: the recipient processes it once (the duplicate fails libsignal's session-establishment check).
- If after: the recipient's session has already advanced past it; libsignal rejects with `MessageOutOfOrder` or `InvalidMessage`.

## When the recipient device is unknown

If the sender doesn't have a session with this device yet:

1. The sender's send-flow calls `identity.FetchPrekeyBundle(recipient_account, recipient_device)`.
2. Performs X3DH locally.
3. Initializes the session.
4. Sends the first message containing the X3DH preamble.

The session is now established. Subsequent messages skip the preamble and use Double Ratchet directly.

## Multi-device fan-out

For a recipient with multiple devices, X3DH runs once per device. The sender's client maintains separate sessions per recipient device.

For a 3-device recipient:
- 3 prekey bundles fetched (one per device).
- 3 X3DH agreements computed.
- 3 separate ciphertexts produced (one per device).
- Sent as 3 separate envelopes via routing.SendEnvelope.

## Bundle staleness

A bundle is considered stale if its `signed_at` is older than 30 days. The signed prekey rotates every 7 days; bundles are fresh in normal operation.

If a stale bundle is encountered, the sender:
- Logs a warning.
- Proceeds with the X3DH (the signed prekey is still valid; staleness is operational, not cryptographic).

The server prefers to serve fresh signed prekeys. If a recipient hasn't been online to rotate, we fall back to the most recent.

## Edge cases

| Case | Handling |
|---|---|
| Recipient has 0 one-time prekeys | Bundle returned without OTPK; X3DH succeeds with DH1+DH2+DH3 only; logged. |
| Recipient identity_pub doesn't match what we trust | libsignal raises `UntrustedIdentity`; conversation is marked rekeyed. |
| Recipient's signed_prekey signature invalid | Abort; conversation cannot be established with this device. |
| Sender's X3DH output fails AEAD on the first message | Abort; sender retries with a fresh ephemeral. |
| Recipient receives X3DH for an account they no longer have a session with (re-installed) | libsignal handles transparently; session re-establishes. |

## libsignal mapping

In libsignal terms:

- Sender invokes `process_prekey_bundle(bundle)` on the protocol store.
- Recipient invokes `process_prekey_message(prekey_message)` on the protocol store.
- The library handles the four DHs, the HKDF, the session initialization.

Velix provides the pre-key bundle storage (via `identity` service) and the message envelope routing (via `routing` service). Velix does not implement the cryptographic operations.

## What we will NOT do

- "Trust on first use" without verification UX. The verification flow (`15-identity-verification.md`) is mandatory for users who want trust upgrades.
- Skip the signed_prekey signature check (libsignal enforces; we'd have to subvert it).
- Use a shared one-time prekey across devices (one-time prekeys are per-device).
- Cache the X3DH ephemeral private key (it's deleted after use).

## Banned

- Re-using a one-time prekey. The server enforces `consumed_at IS NULL` atomically.
- Logging the X3DH ephemeral key, even briefly.
- Storing the X3DH ephemeral key beyond the function scope.
- Skipping the signed_prekey signature verification because it's "the same person."
- Falling back to non-X3DH key agreement on bundle errors.
