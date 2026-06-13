# 08 — Sender Keys (Groups) — and the MLS Decision

The Phase 1 dossier deferred the choice between Sender Keys and MLS for groups to Phase 7. This document makes the call.

## Decision

**Velix 1.0 ships Sender Keys.** MLS is tracked for v2.0+.

## Why Sender Keys

| Criterion | Sender Keys | MLS (RFC 9420) |
|---|---|---|
| Maturity | Production at scale (Signal, WhatsApp) since 2014 | RFC published 2023; production deployments emerging |
| libsignal availability | Native; well-tested | Separate library (`mls-rs`); newer integrations |
| Audit history | Multiple independent audits over a decade | Initial audits done; less battle-tested |
| Group-size scaling | O(n) distribution per send (key fan-out) | O(log n) tree-based key updates |
| Forward secrecy | Per-message via chain key | Per-message + per-epoch tree updates |
| Post-compromise security | Per-conversation DH ratchet (out-of-band) | Built-in via tree updates |
| Add/remove participants | Sender redistributes per-device | Tree update propagated |
| Group size sweet spot | Small to medium (≤ 5,000) | Medium to large (efficient at 10,000+) |
| Implementation surface | Smaller; libsignal-shaped | Larger; new state machine to maintain |
| Dependency posture | "We use Signal" — well-understood | "We use Signal + MLS" — additional vendor surface |

For Velix 1.0 group sizes (typical 1–50 in Threads, up to 5,000 in Spaces), Sender Keys is the strict win:

- Lower implementation risk.
- Better-audited primitives.
- Single library boundary (libsignal) instead of two.
- Operational complexity matches our team size.

For a v2.0 product at >10,000-person communities, MLS becomes attractive. By then, MLS implementations will have matured and we can revisit. The migration path is documented below.

## Sender Keys overview

For each group, the sender maintains a per-group session state:

- A 32-byte chain key.
- An Ed25519 signing keypair (the sender signs every group message; recipients verify).

When sending:

```
1. Derive message_key from chain_key:
     message_key = HMAC-SHA-256(chain_key, "velix.sender_keys.msg.v1")
     chain_key   = HMAC-SHA-256(chain_key, "velix.sender_keys.chain.v1")

2. Sign(signing_priv, header || message_number)

3. AEAD-encrypt the body with message_key.

4. The output is delivered to every recipient device via the existing routing
   service. Each recipient receives one envelope (from the sender's send-flow).
```

When receiving:

```
1. Verify the Ed25519 signature on the message header using sender's signing_pub.
   Failure → drop the message; libsignal raises an error.

2. Compute the same message_key as the sender did (using the cached chain_key
   for this sender_id in this group).

3. AEAD-decrypt.

4. Advance the chain key.
```

## Per-recipient-device delivery

Every send produces N envelopes — one per recipient device — addressed via routing's per-device addressing. The envelopes are *identical* in payload (same ciphertext) but have different recipient device IDs. The routing service delivers each to the appropriate connected device or queues it.

The fanout is the sender's responsibility, not the server's. The server has no concept of "group" — it just sees per-device envelopes.

This means:

- Server-side group state: zero.
- Server learns group membership only by observing send patterns over time (we consider this acceptable; the alternative is server-mediated groups, which is worse).
- Sender-side computational cost: one AEAD per group, one signature per group, one envelope creation per recipient.

## Distributing the chain key (joining a group)

When a new participant joins:

1. The "joiner" generates their own per-group sender chain (chain_key + signing keypair).
2. An existing member shares the existing per-sender chain keys with the new joiner via the existing E2E channel — one Double-Ratchet message per sender.
3. The new joiner can now decrypt incoming group messages from each existing sender.

When sending, the joiner uses their own chain key (which existing members will receive in their next message header).

## Removing a participant

A participant is removed by:

1. Every remaining member rotates their per-group sender chain (generates a new chain_key and signing keypair).
2. The new chains are distributed via E2E to the remaining members only.
3. The removed participant's old chain keys are now useless for new messages.

Removal does NOT erase past messages from the removed user's local storage; that's outside the protocol's scope.

## Group size limits

| Tier | Max devices | Notes |
|---|---|---|
| Direct (1:1) | 2 (per side multi-device) | Standard 1:1 with Sender Keys per device |
| Small group | ~50 devices | Default Threads / DMs |
| Space | 5,000 devices | Sender redistributes on every join/leave |
| Channel (broadcast) | unbounded | One sender, fan-out per device — uses Sender Keys's per-recipient delivery |

Beyond 5,000 we currently do not support synchronous group send. Channels use a one-way Sender Keys distribution that scales linearly with subscribers; the sender's client batches across multiple SendEnvelope RPCs (each capped at 256 recipients per Phase 6 doc 03).

## Authenticity (P8)

Every group message is signed by the sender's per-group signing key. Recipients verify before decrypting:

- Signature invalid → message dropped (libsignal layer).
- Signature valid, AEAD valid → message authentic.

The signing key is **per-group, per-sender**. A user in two groups has two distinct signing keys. This prevents cross-group impersonation.

## Why not just use Sender Keys without per-group signatures

If we used a single signing key per user, an attacker who steals it could forge messages in any group the user is in. Per-group keys bound the blast radius.

## Scaling considerations

At 5,000 devices, every send produces 5,000 envelopes. The sender's client must handle this:

- Batched: the client splits into 5,000/256 = 20 SendEnvelope RPCs, sent in parallel.
- Network-bound: at LTE speeds (~1 Mbps), 20 RPCs of ~10 KB each = 200 KB upload. ~2 seconds.
- Server-bound: routing's `InsertBatch` handles 256 envelopes in one transaction; no scaling concern.

For Spaces approaching 5,000 we recommend Channels (one-way broadcast), not Spaces.

## libsignal mapping

In libsignal terms:

- `SenderKeyDistributionMessage` for joining.
- `SenderKeyMessage` for ongoing sends.
- `process_sender_key_distribution_message` and `group_encrypt` / `group_decrypt`.

We use these directly via the FFI binding.

## MLS migration plan (v2.0+)

When we revisit MLS:

1. New groups created in v2.0+ optionally use MLS.
2. Existing Sender Keys groups migrate via:
   - Coordinated handoff: each member runs both protocols in parallel for a week.
   - The first MLS-formed key is established via a special distribution message that all current members agree on.
   - After the migration window, the Sender Keys state is retired.
3. Migration is opt-in per-group (the group's owner triggers it).

We do not commit to a hard migration date; it depends on:
- MLS production maturity.
- Velix's group-size needs at scale.
- Audit confidence in the chosen MLS implementation.

## Banned

- Server-side group state (membership, keys, anything).
- Sharing a sender chain key across groups.
- Serving plaintext messages to "newly added members" by re-encrypting old messages with the new chain — past messages remain encrypted to the old chain only.
- Group sizes beyond 5,000 in synchronous-send mode.
- A "group" key shared by all members (compromise of one member exposes the whole group).
- Signing groups with a single per-user key.
- Using a Sender Keys variant not provided by libsignal.
