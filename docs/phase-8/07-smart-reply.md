# 07 — Smart Reply

The most-used AI feature in messaging products. Velix's version is on-device, default-on, ranking-only — never auto-send.

## What it does

Surfaces 3 candidate reply chips above the composer, one tap each. The user picks one or ignores. Tapping fills the composer; the user can edit before sending.

## What it does NOT do

- Auto-send.
- Send without the user tapping the composer's send button.
- Pre-compose drafts in the background.
- Suggest replies that read the user's location, calendar, or external apps.
- Personalize across conversations (each conversation's suggestions are derived from that conversation's recent messages only).

## Construction

```
Trigger: a new incoming message in the active conversation.

[client] reads last 5 messages from local SQLCipher (already decrypted)
[client] passes to on-device smart-reply model
[on-device-model] returns 3 candidates with confidence scores
[client] filters:
            - drop candidates with confidence < threshold
            - drop candidates that exceed 60 chars
            - drop candidates that violate moderation classifier
            - dedup near-duplicates
[client] renders chips
```

## Latency budget

≤ 80 ms from "new message arrived" to chips visible.

This means smart-reply runs synchronously on the message-arrival path. We accept the cost because it's tiny.

If the model takes longer than 200 ms, we abort and show no chips. The user gets no smart-reply for that message; no fallback.

## Filtering rules

We filter aggressively:

- **Confidence threshold:** 0.6. Below that, the model is guessing; we don't show.
- **Length cap:** 60 chars. Smart replies are quick acknowledgments, not essays.
- **Moderation gate:** every candidate runs through the on-device moderation classifier. Anything classifying as harmful is dropped.
- **Dedup:** if two candidates are within edit-distance 3 of each other, drop the lower-confidence one.
- **Profanity gate:** lightweight profanity filter, on by default; user can disable in Settings → AI.
- **Personality match:** generic by default; users can opt into "match my style" which learns from the user's recent sent messages (on-device only; never sent to anyone).

## Multi-language

The smart-reply model has separate variants per language:

- English (en) — ships at 1.0
- Spanish (es) — Phase 8.5
- French (fr) — Phase 8.5
- German (de) — Phase 8.5
- Japanese (ja) — Phase 8.5
- Portuguese (pt) — Phase 8.5

Each is ~12 MB. A user with messages in multiple languages can have multiple variants loaded.

For unsupported languages, smart-reply is silently disabled for that conversation. No fallback to a "universal" model that might produce gibberish.

## Caching

Suggestions are memoized per (conversation, last_message_id). Re-rendering the same conversation produces the same suggestions without re-inference.

Cache lives in process memory; not persisted to SQLCipher (the cost of disk I/O exceeds the cost of re-running the 80 ms inference).

Cache eviction: LRU at 50 conversation entries.

## Fallback when model unavailable

If the model isn't loaded (lazy-download not yet completed):

- Conversation shows the standard composer.
- Settings → AI shows "Download smart-reply model (12 MB)?" affordance.
- User can opt to download or live without it.

## Privacy properties

Smart-reply runs entirely on-device. The model has no network access. The model's input (recent messages) is in-process plaintext (already decrypted). The model's output (3 candidates) is in-process plaintext (rendered to UI). Nothing crosses the device boundary.

The "match my style" mode learns on-device from the user's sent messages. The learned weights live in SQLCipher (encrypted at rest with the device's MDK-derived key). They are not shared.

A user who turns off smart-reply: the model is unloaded; the cache is cleared; no suggestions ever appear again.

## Telemetry

```
velix_ai_smart_reply_shown_total{language}
velix_ai_smart_reply_picked_total{language}
velix_ai_smart_reply_inference_duration_seconds{language}    histogram
velix_ai_smart_reply_filtered_total{reason}
```

No per-message, per-user, or per-content telemetry.

## Banned

- Auto-sending suggestions.
- Suggesting replies based on cross-conversation context.
- Suggesting replies that include personal details (names, locations) the user hasn't typed in this conversation.
- Cloud fallback for smart-reply.
- Suggesting replies that match the user's stylometry across all conversations (would create a panopticon-shaped fingerprint).
- "Smart reply" UX that auto-fills the composer.
- "Smart reply" UX that pre-selects one for keyboard "Enter" send.
- A/B testing suggestion variants per user (would require per-user telemetry).
