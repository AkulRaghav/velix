# 10 — Moderation

Velix's moderation is **decentralized and on-device**. Each user's device decides what they see based on their preferences. The server does not gate-keep content. There is no global content moderation panopticon.

## Why on-device

Centralized moderation means a server reads message content. That defeats the encryption property. We do not do this.

The cost: bad-faith users can send harmful content; we cannot block at the source.

The benefit: the architecture is honest. We say "we cannot read your messages" and it is true.

The mitigation: each receiving device can classify and act on incoming content. Spaces and Channels can apply moderation policies to incoming messages for their members.

## Moderation surfaces

| Surface | Moderation? | Where |
|---|---|---|
| 1:1 chats | None automatic | User-controlled blocks |
| Group threads (≤ 50) | None automatic | User-controlled blocks; group-admin removal |
| Spaces (community rooms) | Optional, owner-configured | On-device classification per member |
| Channels (broadcast) | Optional, owner-configured | On-device classification per subscriber |

A 1:1 chat has no moderation surface — the recipient sees what the sender sent. If they don't like it, they block.

A Space's owner can enable a moderation policy. The policy runs on each member's device when receiving messages. Members are NOT at the mercy of the owner's interpretation; the policy is downloadable as a JSON manifest the member can inspect.

## On-device classifier

Per Phase 8 doc 04:

- Model: `velix_moderate_v1`, ~8 MB
- Input: single message text (max 4 KB)
- Output: classification probabilities for `{harassment, sexual_explicit, csam, violence, spam, ok}`
- Inference: ≤ 30 ms

The classifier runs on:

- Every incoming Space/Channel message, if the member's app has the model loaded.
- Every received story attached to a Space.
- Optionally: outgoing messages from this user, as a "are you sure?" prompt for borderline content. (Off by default; opt-in.)

## Policy manifest

A Space owner publishes a moderation policy:

```json
{
  "version": 1,
  "applies_to": "space:01H...",
  "thresholds": {
    "harassment": 0.85,
    "sexual_explicit": 0.85,
    "csam": 0.50,
    "violence": 0.85,
    "spam": 0.95
  },
  "actions": {
    "harassment": "hide_with_warning",
    "sexual_explicit": "hide_with_warning",
    "csam": "block",
    "violence": "hide_with_warning",
    "spam": "hide"
  },
  "appeal_recipients": ["space:owner"]
}
```

Manifest is encrypted to all Space members via the Space's group key (Sender Keys). Members can read and inspect.

When a message classifies above threshold, the member's device:

- `block`: drops the message; never displays. Reports to the Space owner via encrypted message.
- `hide_with_warning`: shows a "potentially harmful content; tap to view" affordance.
- `hide`: drops the message; no notification.

The decision is **per-member**. A member who doesn't have the model loaded sees all messages.

## CSAM (CSEA) handling

CSAM is the one category where we apply the strictest threshold and a non-tunable action: `block` only.

The classifier is built with a higher recall than precision for CSAM. False positives are acceptable; false negatives are not.

Detection emits an encrypted report via NCMEC-compatible channels (in jurisdictions where mandated). The report is generated **by the recipient's device**, not by the server. The server never sees the content; it sees only the routing for the report (which is metadata).

We do not use Apple's CSAM-detection-via-perceptual-hashing (controversial, accuracy questions). We use a text classifier on text + a separate image classifier (planned post-1.0 for media moderation).

## Sender-side moderation (opt-in)

A user can opt to have their outgoing messages classified before sending. This is a user-controlled "are you sure?" check; it does not block anything.

```
User types a message that classifies as harassment with high confidence.
Client shows: "This might be harmful. Send anyway?"
User taps "Send" or "Edit."
```

This is intentionally a soft check, never enforcement. Censorship at the sender side is a step toward the panopticon.

## Reports

When a member's device blocks or warns on a message, they can report to the Space owner:

```
Encrypted report = {
  message_id,
  sender_account_id,
  category,
  severity,
  reporter_signature
}

Sent via E2E to Space owner only.
```

The Space owner receives reports. They can:

- Remove the user from the Space (via existing kick/ban controls).
- Forward the report to Velix support (rare; only if the report involves CSAM or imminent threat).

For CSAM, the report can also be forwarded to NCMEC (in the US) via a separate flow that the user explicitly initiates. We do not do this automatically.

## What Velix-the-company sees

Aggregate counters only:

```
velix_moderation_classified_total{category, action}
```

That's the only signal. We do NOT see:

- Which user reported what.
- What content was classified.
- Which Space had what policy.

Per-Space reports stay within the Space.

## Banned

- Server-side classification of any message.
- Server-side gate-keeping of message delivery.
- Centralized reputation scoring.
- "Auto-ban" based on classification — every action requires the recipient's device's choice.
- Sharing classification results across users (each user's device classifies for itself).
- Moderation that depends on cloud AI — moderation is on-device only.
- Policy manifests with tunable CSAM thresholds (CSAM threshold is fixed).
- Allowing Space owners to disable moderation for specific senders.
- Custom classifiers shipped by Space owners.
- Logging classification outputs anywhere on the server.
