# 02 — Data Flows

Per feature, the exact step-by-step path of user content through the system. Every flow is bounded; every flow ends with the data either rendered to the user or destroyed.

## Notation

```
[user]                  ← user device
[client]                ← Flutter app + velix_crypto + velix_ai
[on-device-model]       ← TFLite / CoreML / Gemini Nano
[ohttp-relay]           ← independent OHTTP relay (not Velix)
[velix-gateway]         ← Velix-operated AI gateway
[provider]              ← Anthropic, OpenAI, etc.
─→                      ← request
←─                      ← response
║ E2E ║                 ← end-to-end encrypted between two parties
─ – – ─                 ← plaintext (within a trust level)
```

## Flow 1 — Smart reply suggestions

User opens a conversation; client wants to suggest 3 short reply candidates.

```
[client] reads recent messages from local SQLCipher
[client] → [on-device-model]   plaintext snippet of last 5 messages
[on-device-model] → [client]   3 candidate reply strings
[client] renders 3 chips above the composer
```

**Boundaries crossed:** none. Everything stays at trust level 1-3.

**Network:** none.

**Storage:** suggestions live in process memory; not persisted. They disappear when the user moves away from the composer.

**If the model unavailable:** no suggestions. The user sees the standard composer.

## Flow 2 — Translation, on-device, default mode

User reads an incoming message in a foreign language; client offers translation.

```
[client] reads message from local SQLCipher (already decrypted)
[client] → [on-device-model: language-id]   plaintext message
[on-device-model] → [client]                 detected language code (e.g., 'es')
                                             (compared to user's locale)
[client] (if different) renders "Translate" affordance
[user] taps "Translate"
[client] → [on-device-model: NLLB-distilled]   plaintext + (src_lang, tgt_lang)
[on-device-model] → [client]                    translated string
[client] renders translation inline below original
```

**Boundaries crossed:** none.

**Network:** none.

**Storage:** translation cached for the conversation's lifetime in process memory. Optional persistent cache in SQLCipher (Phase 8.5; user-configurable). Cache key: `(conversation_id, message_id, target_lang)`. Cache TTL: 30 days.

**Failure mode:** if the local NLLB model is missing (lazy-downloaded), client offers to download. If download fails, no translation.

## Flow 3 — Translation, cloud, long-form

User wants to translate a long block (a forwarded article inside a chat). Local NLLB is too slow or insufficient quality.

```
[user] highlights the long text + taps "Ask AI to translate"
[client] presents consent UX:
            "Send this 1,247-character excerpt to Velix AI for translation?
             It will be processed without identifying you to the AI service."
[user] taps "Send"

[client] runs prompt-sanitization (redaction.dart): strips emails, phone numbers,
         contact handles, URLs that look identifying.
[client] constructs OHTTP request:
            method: POST /v1/translate
            body: { text, source_lang, target_lang, locale }
            metadata: NONE — no account_id, no device_id
[client] → [ohttp-relay]   encrypted-to-gateway request
[ohttp-relay] → [velix-gateway]   relayed request without origin IP
[velix-gateway] (no auth check; the OHTTP carries a one-shot token):
                  validates token (rate-limit + quota)
                  forwards to provider
[velix-gateway] → [provider]   translation prompt
[provider] → [velix-gateway]   translation result
[velix-gateway] → [ohttp-relay] → [client]   result

[client] renders inline translation
```

**Boundaries crossed:** trust level 1-3 (client) → trust level 4 (gateway, provider).

**What the gateway sees:** the text content of the highlighted excerpt; no identity.

**What the relay sees:** the user's IP address; an opaque encrypted blob (cannot read content).

**What the provider sees:** the text content; no identity.

**Storage at gateway:** none beyond the response window (≤ 30 s for streaming connections).

**Storage at provider:** governed by provider contract (no-train-on-data; no logging beyond 30 days for abuse).

**Failure mode:** quota exceeded → user sees "Cloud AI quota exceeded; try again later." OHTTP relay down → "AI temporarily unavailable." Gateway down → same. Never a fallback to a non-private path.

## Flow 4 — Summarization, on-device, short

User wants to summarize a 80-message thread.

```
[user] taps "Summarize this thread"
[client] reads last 80 messages from local SQLCipher
[client] passes to on-device summarizer (Apple Intelligence / Gemini Nano /
         a small Velix-shipped seq2seq model)
[client] receives ~3-4 sentence summary
[client] renders summary in a Tier-3 sheet
```

**Boundaries crossed:** none.

**Network:** none.

**Storage:** summary lives in process memory; user can copy it. Not persisted to SQLCipher unless user pins.

## Flow 5 — Summarization, cloud, long

User wants to summarize a thread > 200 messages or > 50,000 characters total. The on-device model can't handle the context window.

```
[user] taps "Summarize this thread"
[client] computes content size; sees it exceeds local capacity
[client] presents consent UX:
            "This thread is too long to summarize on your device.
             Send it to Velix AI? Your messages will be processed without
             identifying you. They will not be stored."
[user] taps "Send"

[client] runs redaction over each message's body (per Phase 8 doc 06)
[client] bundles into a structured prompt
[client] → [ohttp-relay] → [velix-gateway] → [provider]   summarization request
[provider] → ... → [client]   summary
[client] renders summary
```

**What the user is asked:** the consent UX explicitly mentions message count and provides a sample of the redacted content the user can review before sending.

**What the gateway sees:** the redacted thread content; no identity, no recipient names.

## Flow 6 — Live captions on calls

User enables captions during a video call.

```
[user] taps "Captions" in call controls
[client] activates on-device speech-to-text on the local audio stream
         (CoreML / Android speech-to-text)
[client] rolling caption text rendered as overlay; never persisted
```

**Boundaries crossed:** none. The local audio never leaves the device.

**Network:** none.

**Storage:** none. Captions are rendered live and discarded.

**Why on-device only:** Captions require continuous audio access. Sending the audio stream to a cloud STT would expose every spoken word. Even with OHTTP, the privacy cost is too high for a routine call feature.

## Flow 7 — AI assistant (open Q&A)

User taps the AI assistant FAB. They want to ask "how do I export my data?"

```
[user] taps AI assistant
[client] opens VelixSheet (Phase 4)
[user] types or speaks a question
[client] presents the question for confirmation:
            "Send this question to Velix AI?"
[user] taps "Send"

[client] runs redaction (Phase 8 doc 06)
[client] → [ohttp-relay] → [velix-gateway] → [provider]   question + system prompt
[provider] streams tokens back via the same path
[client] renders streaming response via AIStreamingText (Phase 4 doc 03)
```

**System prompt:** prepended by the gateway. Static, audited, version-pinned. Says: "You are Velix's assistant. You answer user questions about Velix or general questions. You never see the user's messages or contacts. You do not remember previous queries."

**What the assistant CANNOT do in 1.0:**

- Read the user's conversations.
- Send messages on the user's behalf.
- Access settings.
- Verify or unverify contacts.
- Trigger any state change in Velix.

The assistant is a **read-only Q&A surface**. Tool-using assistants come post-1.0 with explicit tool gating.

## Flow 8 — Moderation, Space-level

A Space owner enables moderation. Each new message in the Space is classified for policy violations.

```
[Space-member's client] sends a message to the Space (E2E encrypted)
[recipient client] receives the encrypted envelope
[recipient client] decrypts (libsignal Double Ratchet)
[recipient client] passes the decrypted plaintext to the on-device moderator
[on-device-model] classifies: { spam, harassment, csam, ok }
[recipient client] if violation:
                     - hides the message inline (with "potentially harmful" affordance)
                     - emits an encrypted moderation report to the Space owner only
[Space owner client] receives report; decides action
```

**Boundaries crossed:** none server-side. The plaintext only ever exists on the recipient's device. The server never sees the moderation classification.

**What is shared:** if the recipient chooses to "Report to Space owner", an encrypted report (containing message_id + category + severity) is sent to the Space owner via the standard E2E channel.

**Important:** moderation runs **on the recipient side**, not the sender side. This is privacy-preserving: each user's device decides what they see; the system doesn't gate-keep what the sender writes (which would be a content-moderation panopticon).

**Failure mode:** if the local model is missing or unavailable, classification doesn't happen. No fallback to cloud classification — moderation never sends content to the gateway.

## Flow 9 — Search expansion ("find that thing")

User searches "that thing about lasagna recipe last weekend." Local search would do exact-match; AI helps.

```
[user] types query in search bar; query is "vague" (heuristic: contains words like "that thing", "what was", "earlier this week")
[client] presents "Help me find this with AI?" prompt
[user] taps "Yes"

[client] runs the on-device intent extractor:
            input: query + recent (last 7 days) message metadata (subjects, dates,
                   topical extracts)
            output: refined query (e.g., "recipe lasagna 7-day window")
[client] runs local search with refined query
[client] renders results
```

**Boundaries crossed:** none. Search expansion runs entirely on-device.

**Why on-device only:** sending recent message metadata to a cloud service is functionally close to relaying content. We keep this on-device.

## Universal failure handling

For any flow:
- If on-device model missing → render the no-AI variant of the surface; offer to download model.
- If consent declined → return to base state; no retry.
- If cloud relay errors → display "Try again." Never silent fallback.
- If quota exhausted → display quota-state UX; never auto-purchase.
- If timeout → cancel the request server-side; client returns to base state.

## Cross-flow invariants

Every flow above satisfies:

1. **No automatic transmission of user content to any AI service** without an explicit per-query gesture.
2. **No persistent association of user identity with AI invocation** at the gateway or provider.
3. **No retention of user content** at the gateway beyond the response window.
4. **No fallback** that routes content to a less-private path on error.
5. **Bounded scope:** each invocation operates on the explicit selection only, never on more.
6. **Telemetry is content-free:** counters and latency, never the prompt or response.
