# 07 — Double Ratchet

The ongoing-session key-management protocol. Forward secrecy + post-compromise security via two intertwined ratchets. We use libsignal's implementation; this document specifies the Velix wiring.

## Why Double Ratchet

X3DH gives us an initial shared secret. Double Ratchet:

- Derives a fresh per-message key from that secret.
- Rotates the secret on every received message (Diffie-Hellman ratchet).
- Provides forward secrecy: compromise of current state does not expose past messages.
- Provides post-compromise security: if an attacker briefly steals state, the user heals automatically via the next DH ratchet.

## The two ratchets

### Symmetric ratchet (per-direction)

Each direction (sending, receiving) has a chain key. Each message advances the chain by one step:

```
chain_key_n+1 = HMAC-SHA-256(chain_key_n, "velix.chain.v1")
message_key_n = HMAC-SHA-256(chain_key_n, "velix.msg.v1")
```

The message key is consumed once, then deleted. The chain key is also discarded after deriving the next message key (we keep only the *next* chain key).

### Diffie-Hellman ratchet (per-DH-exchange)

Each side maintains a current DH ratchet keypair. When a new message arrives with a *new* DH public key in its header, we:

1. Compute a new shared secret with the received DH public key.
2. Derive a new root key + new receiving chain key from `(old root, new shared)`.
3. Generate our own new DH keypair.
4. Send the next outbound message with our new DH public key.

This rotation gives post-compromise security: after one full round-trip, both parties have new key material that the attacker doesn't know.

## Per-message format

```
Header:
  ratchet_pub         X25519 public key (32 B) — sender's current DH ratchet public
  prev_chain_len      u32 — number of messages in the previous sending chain
  message_number      u32 — index in the current sending chain

AEAD ciphertext:
  XChaCha20-Poly1305(key=message_key, nonce=derived_from_message_number, aad=header, plaintext)
```

The header is authenticated as AAD; an attacker can't tamper with it without breaking AEAD.

## Out-of-order messages

Messages can arrive out of order (NATS, push, retries). Double Ratchet handles this by:

- Pre-computing message keys for the next `MAX_SKIP` messages (default 1000) in any chain.
- Storing them in a "skipped keys" map keyed by `(ratchet_pub, message_number)`.
- Looking up a key if a message arrives out of order.
- Discarding the key on use.

Skipped keys live in SQLCipher inside libsignal's protocol store. They expire after 30 days (libsignal default we honor).

## The `MAX_SKIP` limit

We set `MAX_SKIP = 1000` (libsignal default). A burst of more than 1000 missing messages causes the session to deadlock — we'd need to re-establish via X3DH.

In practice this is rare: skipped messages persist for 30 days, well beyond typical reconnection windows. A user offline for months may exceed it; the recovery is automatic (libsignal triggers re-keying on next interaction).

## Replay protection

A message key is consumed once. After consumption, it's deleted from the skipped-keys map. A replayed message:

- Was already received → its key is gone → AEAD fails → silently dropped at libsignal layer.
- Was never received → first decrypt; subsequent replays fail.

The application surface never sees a replayed message.

## Forward secrecy

After processing message N, we hold:

- The current chain key (which derives message N+1's key).
- A small set of skipped keys (for in-flight reordering).
- Our current DH private key.

We do **not** hold:

- Any past message key.
- Any past chain key.
- Any past DH private key (after a full ratchet step).

An attacker who steals the device's current state at time T cannot decrypt messages from before T (forward secrecy). They can decrypt messages from T forward — until the next DH ratchet step, after which they're locked out again (post-compromise security).

## Post-compromise security in practice

For PCS to "heal" the session, both parties must complete a DH ratchet step — i.e., both must send at least one message after the compromise, and both must receive each other's response. This typically happens within minutes of normal use.

We do NOT auto-trigger ratchet steps on idle conversations. If a conversation is idle, its state remains compromised until the next message. This is a libsignal property, not a bug.

## Multi-device fan-out

Each session is per-recipient-device. A user with 3 devices has 3 separate Double Ratchet states with the sender. A new device joining triggers a new X3DH + Double Ratchet for that pair.

Within a user's own devices, history sync (Phase 7 doc 10) transfers the historical messages, but each device runs its own Double Ratchet for new conversations going forward.

## Storage

Inside SQLCipher via libsignal's protocol-store traits:

```sql
-- libsignal-managed schemas; we don't see the SQL directly, only the trait surface
CREATE TABLE _libsignal_session (
  session_id  text PRIMARY KEY,
  serialized  bytea NOT NULL  -- the entire libsignal SessionRecord protobuf
);
```

The `serialized` column contains the Double Ratchet state in libsignal's canonical Protobuf form. We do not parse it ourselves.

## Performance

- Encrypt operation: ≤ 2 ms on iPhone 12 (libsignal benchmark).
- Decrypt operation: ≤ 3 ms.
- Skip-key lookup (out-of-order): ≤ 0.1 ms (in-memory hash map via libsignal).

These are inside the FFI boundary; the FFI call overhead adds ~30 µs per op.

## Failure modes

| Scenario | Handling |
|---|---|
| Decrypt fails AEAD | libsignal returns InvalidMessage; envelope marked failed; we never display partial plaintext |
| Skipped-key map exceeds MAX_SKIP | New incoming message with a far-future number triggers session re-key; libsignal handles |
| Peer's ratchet_pub changes unexpectedly | Treated as a normal DH ratchet step (this is the design) |
| Identity mismatch detected during session | libsignal raises UntrustedIdentity; conversation marked rekeyed |
| Session corruption (storage error) | Reset session; force re-X3DH on next send |

## Memory hygiene

- Message keys are zeroed immediately after AEAD decrypt.
- Chain keys are zeroed after deriving the next chain key + message key.
- DH private keys are zeroed when a new ratchet step retires them.
- Plaintext lives only inside the Rust core during the operation; we copy out, then zero the Rust-side buffer.

## Banned

- Re-using a message key.
- Disabling AEAD authentication "for performance."
- Logging any chain or message key.
- Caching plaintext beyond the rendering frame.
- Using a non-libsignal Double Ratchet implementation.
- Modifying libsignal's `MAX_SKIP` to a higher number "for convenience" — that grows skipped-key memory without bound.
- Skipping the AAD on the AEAD operation — header tampering protection.
