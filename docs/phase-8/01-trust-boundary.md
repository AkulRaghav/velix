# 01 — AI Trust Boundary

The AI layer's relationship to the cryptographic system.

## Position in the trust hierarchy

Per Phase 7 doc 03 trust assumption rankings (1 = strongest, 5 = weakest), the AI gateway sits at **level 4**:

> "The user trusts Cloudflare R2 to not collude with Velix — they can't read the data."
> "The user trusts APNs / FCM to not collude with Velix — they can't read the data."
> "The user trusts LiveKit to not record E2EE calls — they can't decode frames."

The AI gateway joins this tier with one critical equivalent property: **it sees only what the user explicitly sends, when the user explicitly sends it, and it cannot correlate that content with the user's identity**.

The AI gateway can never become level 1, 2, or 3. If a feature would require it (e.g., "auto-summarize all my conversations daily"), the feature is rejected. There is no "pro tier that gives AI more access" carve-out. There is no debug mode that exposes content.

## What "trust level 4" means concretely

For the AI gateway:

1. It is operated by us, but designed so a compromise of the gateway leaks **per-query content only**, never **history of queries**, never **user identity tied to queries**, never **the user's full conversation graph**.

2. It cannot do anything to a user who has not invoked it. There is no scheduled scan of conversations. There is no "pre-warm summary" that runs in the background.

3. It receives requests through an OHTTP-style relay (`docs/phase-8/05-cloud-relay.md`), so the gateway server cannot correlate IP or session-token with content.

4. It logs nothing identifying. Aggregate metrics only.

5. It retains nothing per query beyond the immediate response window (≤ 30 seconds).

6. The TLS termination is operated by us; the upstream model providers (Anthropic, OpenAI) see content but not identity.

## What the AI gateway is NOT in the trust boundary for

- Not in the boundary for E2E-encrypted messages between users. The gateway never sees ciphertext that is not the user's own deliberate query.
- Not in the boundary for media stored in R2.
- Not in the boundary for backups.
- Not in the boundary for call media (audio / video). LiveKit handles those; AI features that operate on call audio (e.g., live captions) run **on-device only** in 1.0.
- Not in the boundary for typing indicators, presence, or any other ephemeral state.

## Diagrammed boundary

```
   ┌────────────────────────────────────────────────────────────┐
   │  Level 1 — User's device, OS keychain, Secure Enclave      │
   │            • identity_priv, MDK, decrypted plaintext       │
   └────────────────────────────────────────────────────────────┘
                          ▲    cryptographic boundary
                          │
   ┌──────────────────────┼─────────────────────────────────────┐
   │  Level 2-3 — Velix client / cryptographic core             │
   │              On-device AI (TFLite / CoreML / Gemini Nano)  │
   │              Runs INSIDE this level.                       │
   └──────────────────────┼─────────────────────────────────────┘
                          ▲
                          │  user explicit per-query gesture
                          │  (no auto-relay)
                          │
   ┌──────────────────────┼─────────────────────────────────────┐
   │  Level 4 — Velix AI Gateway                                │
   │            • OHTTP-relayed; no identity correlation        │
   │            • Sees query content for ≤ 30 seconds           │
   │            • Forwards to model providers                   │
   │            • Logs only aggregate; no per-user history      │
   └──────────────────────┼─────────────────────────────────────┘
                          ▲
                          │
   ┌──────────────────────┼─────────────────────────────────────┐
   │  Level 4 — Model providers (Anthropic, OpenAI, ...)        │
   │            • See query content                             │
   │            • Cannot correlate with Velix user identity     │
   │            • Subject to provider's own no-train-on-data    │
   │              business agreement                            │
   └────────────────────────────────────────────────────────────┘
```

## What the user explicitly grants by invoking cloud AI

Per query, the user explicitly grants:

- The text or media selection they highlighted is sent to the gateway.
- The conversation context is **NOT** automatically included unless the user explicitly enables "include recent context" for that query.
- The query may be forwarded to a third-party model provider per the routing rules.
- The response is returned to the user; nothing about this query is stored long-term.

The grant is per-query, not per-session and not per-feature. Every cloud AI invocation requires a fresh user gesture. There is no "remember my consent for this conversation."

The grant is **scoped**: it grants access to the highlighted content *for this query only*. It does not grant access to:
- Any other content the user has open.
- The conversation's encryption keys.
- Other messages in the same conversation.
- Identity information.
- Recipient information.
- Any data outside the explicit highlight.

## Per-feature opt-in matrix

| Feature | Default | Where it runs | Per-invocation consent |
|---|---|---|---|
| Smart reply suggestion | On | On-device | None — UI suggestion; user picks or ignores |
| Translation (auto-detect) | Off | On-device | None — toggled per-conversation |
| Translation (cloud, larger model) | Off | Cloud | Per-tap |
| Summarization (short — < 200 messages) | Off | On-device | Per-tap |
| Summarization (long — cloud assist) | Off | Cloud | Per-tap |
| Moderation in Spaces | On (per Space) | On-device | None — owner sets per Space |
| AI assistant (general questions) | Off | Cloud | Per-tap, separate sheet |
| Live captions on calls | On | On-device | None — toggle per-call |
| Search expansion ("find that thing about X") | Off | On-device | Per-tap |
| Auto-categorize / auto-folder | NEVER | n/a | n/a — banned |
| Sentiment analysis on conversations | NEVER | n/a | n/a — banned |
| Auto-summarize in background | NEVER | n/a | n/a — banned |
| AI-driven content suggestions | NEVER | n/a | n/a — banned |

The "NEVER" rows are architectural rejections. They cannot be turned on by a future product manager because they would violate the trust model.

## Banned

- Server-side scanning of any message content for any reason.
- Auto-relay of message content to any AI service.
- Caching of cloud-AI responses tied to identity.
- "AI features" that read the conversation without an explicit per-query gesture.
- AI features that derive secondary content from messages (e.g., "your weekly mood report").
- Cross-conversation AI context (the AI sees only what the user invoked it on, never historical context from elsewhere).
- A "premium AI tier" that lowers the privacy bar.
- Federated learning on user content.
- Differential-privacy aggregations that have user content as input.

## Audit hooks

Every AI invocation passes through `velix_ai`'s gateway-bound interceptor, which:
- Verifies the user gesture is present (per-query opt-in token).
- Logs only aggregate metrics: `velix_ai_invocations_total{feature, on_device|cloud}`.
- Refuses to attach a user identifier to the request.
- Refuses to log the prompt content.

A test in CI exercises a synthetic "leaked content" attempt (a malformed AI request that includes identity hints) and verifies the gateway rejects it.

## Public commitments

Published at `velix.app/security#ai`:

1. We never auto-send your messages to any AI service.
2. AI features run on your device unless you explicitly invoke a cloud query.
3. Cloud AI queries are routed so the gateway cannot correlate them with your identity.
4. We do not train on your messages, and our model providers don't either (contractually).
5. AI queries are never retained beyond the immediate response window.
