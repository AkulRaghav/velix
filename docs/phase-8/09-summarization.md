# 09 — Summarization

On-device for short threads. Cloud-assisted for long.

## When invoked

Always user-initiated. Conversation menu → "Summarize this thread."

We never auto-summarize. We never produce daily digests. We never email summaries. Each summary is a fresh user gesture.

## Two paths

### Path A — On-device

For ≤ 200 messages or ≤ 50,000 characters.

```
[user] taps "Summarize"
[client] gathers messages from local SQLCipher
[client] runs on-device summarizer
   - Apple Intelligence (iOS 18+)
   - Gemini Nano (Pixel 8+)
   - Velix-shipped seq2seq distilled (others)
[client] renders summary in Tier-3 sheet
```

Inference time: ≤ 800 ms target.

### Path B — Cloud

For > 200 messages or > 50,000 characters.

```
[user] taps "Summarize"
[client] computes content size; sees cloud needed
[client] presents consent UX with redacted preview
[user] taps "Send"
[client] runs aggressive redaction (Phase 8 doc 06)
[client] sends via OHTTP relay → gateway → Anthropic / OpenAI
[client] receives summary; renders
```

Inference time: ≤ 4 seconds typically.

## Aggressive redaction for summarization

Summaries quote input. To prevent quoted content from leaking PII to the model, summarization redaction is stricter:

| Marker | Replaces |
|---|---|
| `<email>` | All email addresses |
| `<phone>` | All phone numbers |
| `<url>` | All URLs |
| `<handle>` | All `@handle` references |
| `<name>` | All capitalized words ≥ 4 chars (heuristic for proper nouns) |
| `<date>` | Anything that looks like a date (heuristic) |
| `<number>` | All numbers ≥ 4 digits |

Yes, this over-redacts. The summary will contain `<name>` instead of "Quinn." We accept this. The user can use names from the original conversation when interpreting the summary.

The consent UX shows the redacted version before the user taps Send. They see exactly what's leaving.

## Output shape

Summary format is constrained:

- 3-5 sentences.
- 50-300 words.
- No emojis (defeats stylometry).
- No URLs.
- No quoting verbatim (quotes can leak content past redaction; the summarizer's prompt explicitly says "rephrase, do not quote").

The output is filtered server-side: any quote longer than 5 consecutive words from input is rejected and the model is re-prompted.

## Caching

Summaries are NOT cached server-side. They are cached client-side in SQLCipher per `(conversation_id, last_message_id_at_time_of_summary)`.

Re-summarizing a conversation that hasn't changed returns the cached result. Re-summarizing after new messages re-runs (with consent if cloud).

## Streaming

Cloud summaries stream via the existing `AIStreamingText` (Phase 4 doc 03). The user sees tokens arrive over 1-3 seconds.

## Failure modes

| Failure | Behavior |
|---|---|
| On-device model can't fit context | Auto-suggests cloud path with consent UX |
| Cloud quota exceeded | "You have N queries remaining; try again next month" |
| Redaction rejects (input too redacted to be useful) | "This thread contains too much identifying information for cloud summarization. Try selecting fewer messages." |
| Output filter triggers (model leaked verbatim quotes) | Re-prompt; if it fails twice, "Couldn't produce a useful summary" |

## Banned

- Auto-summarizing as a default behavior.
- Daily / weekly digest summaries.
- Cross-conversation summarization (summary of "all conversations this week").
- Server-side summary cache.
- Summary that includes verbatim quotes from input (a redaction bypass).
- Summarization training on user content (no provider does this; verified by contract).
- Streaming summary reveal that auto-saves to the conversation as a message (it's an artifact, not a message).
