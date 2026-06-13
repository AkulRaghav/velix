# 15 — Privacy Tradeoffs

The honest disclosure of what cloud AI costs the user, in privacy terms. Velix users can read this and decide whether the convenience is worth the trade.

## Layer-by-layer truth

### Smart reply (on-device)

**What changes when the user enables it:** the smart-reply model loads (12 MB download, lazy). The model reads the last 5 messages of any conversation the user has open. Generates 3 candidates.

**What is sent over the network:** nothing.

**What is stored:** model file (~12 MB), suggestion cache in process memory.

**Worst case:** a forensic adversary with full disk access could read the model file (which is public; nothing private) and the SQLCipher DB (which contains the user's messages, encrypted at rest with hardware-bound keys).

**Privacy cost:** zero beyond what already exists.

### Translation (on-device, default)

Same as smart reply. Zero network traffic; zero cost.

### Translation (cloud, long-form, opt-in)

**What changes:** the user explicitly highlights text and taps cloud-translate.

**What is sent:** the redacted text. Through OHTTP relay → gateway → provider.

**What the relay sees:** user's IP + opaque encrypted blob.

**What the gateway sees:** redacted text content; no identity.

**What the provider sees:** redacted text content; no identity (gateway forwards on).

**Privacy cost:** the text content (after redaction) is processed by a third-party model provider for ≤ 30 seconds. Provider has a no-train-on-data contract. Provider's logs (per their own terms) retain ≤ 30 days for abuse detection. After 30 days, the content is gone.

**The user's identity is not associated with the content** at any point in this chain. The identifier closest to identity is the user's IP, which is seen only by the relay (not the gateway, not the provider). The relay cannot read the content. The chain is broken.

**What we don't promise:** anonymity vs the network at large. The user's ISP knows they used Velix's relay endpoint. If the user is the only person in their ISP's view using that relay endpoint at that moment, there's a timing correlation possible. We do not promise resistance to nation-state-level traffic analysis.

### Summarization (cloud, long, opt-in)

Same as cloud translation, with stricter redaction (`<name>`, `<date>`, `<number>` aggressive markers).

**The user sees the redacted version before consenting.** They are in control.

### AI assistant (cloud, opt-in per query)

Same. Each query is a fresh context. No memory.

### Live captions (on-device)

Audio streams to the on-device STT model. STT model produces text. Text renders as overlay.

**What is sent:** nothing.

**What is stored:** nothing (transcripts are transient).

**Privacy cost:** zero beyond what the call already exposes.

### Moderation (on-device)

Each receiving device classifies its own incoming messages.

**What is sent:** nothing (other than a Space-owner-bound encrypted report when the user reports).

**What is stored:** classification results in process memory; not persisted.

**Privacy cost:** zero beyond what already exists.

## Side-by-side comparison

For a user worried about the cloud AI privacy:

| Path | What leaves the device | What is identified |
|---|---|---|
| Cloud translation | redacted text | nothing (no identity sent) |
| Cloud summarization | redacted text content of selected messages | nothing |
| Cloud assistant Q&A | the user's typed question + any text they paste | nothing |
| On-device features | nothing | n/a |

What does NOT leave for any cloud feature:

- The user's account_id.
- The user's device_id.
- The user's bearer token.
- Anything about the recipient of the original messages.
- Any conversation context beyond what the user explicitly highlighted.
- The user's IP (the gateway sees only the relay's IP).

## Comparing to alternatives

### vs. iMessage

iMessage doesn't have AI features (Apple Intelligence is a separate product). Apple Intelligence:
- Mostly on-device.
- Cloud uses "Private Cloud Compute" — a similar privacy-preserving construction.
- But Apple Intelligence is opt-out per query for some flows; opt-in for others.

Velix's posture is *strictly opt-in per query* for cloud, even for "convenience" features. Stricter than Apple Intelligence's defaults.

### vs. WhatsApp / Signal / Telegram

- Signal: doesn't have cloud AI; on-device only. Same privacy posture as Velix's on-device features.
- WhatsApp: rolling out Meta AI. Each query is sent to Meta with the user's account. Privacy cost much higher than Velix.
- Telegram: cloud AI integrations; the platform already sees user content (chats are not E2E by default).

### vs. Discord, Instagram

These don't claim privacy. AI integration there is fine because the platform already sees content.

### vs. ChatGPT-class direct apps

- Anthropic Claude: ToS allows opt-out of training; conversations may be retained briefly for safety.
- OpenAI ChatGPT: similar terms.
- Both see the user's identity (account, IP).

Velix's relay model means the user's identity is hidden from the model provider. This is strictly better than direct usage of ChatGPT or Claude with an account.

## What we say to a user who asks "is cloud AI safe?"

The honest answer: "Cloud AI processes your text content briefly. The text is redacted. We hide your identity from the model provider via a relay system. We don't store your queries. The model provider's policies say they don't train on the data. But: nothing is private from a model. If you wouldn't be comfortable with someone else reading the text, don't send it. We make it easy to keep AI on-device by default."

This is what we put in the in-app privacy explainer.

## The ladder of privacy cost

From cheapest to most expensive (privacy-wise):

1. **Don't use AI.** The UI has no AI affordances if the user disables AI globally.
2. **On-device only.** All defaults. Free, fast, private.
3. **Cloud, opt-in per query.** Still strong privacy via the relay. The user is in control.

Users at any of these levels are first-class. We do not push them up the ladder.

## Banned PR claims

We will not say:

- "Velix AI is fully private." (False — cloud AI sends text to a model.)
- "Your messages are never used to train AI." (Mostly true, but with caveats — provider contracts; we say it with caveats in the privacy paper.)
- "Your AI queries are end-to-end encrypted." (False — they're between the user and the gateway, not between two endpoints.)

We will say:

- "On-device features keep your content on your device."
- "When you use cloud AI, we hide your identity from the AI service."
- "We don't store your AI queries."
- "We never send your messages to AI without you asking each time."

The privacy paper at `velix.app/security#ai` is the source of truth.

## Future considerations

As we add features, each is evaluated against the trust boundary (Phase 8 doc 01). A feature that would push the gateway above level 4 is rejected. A feature that requires the gateway to keep state is rejected. A feature that requires server-side scanning is rejected.

The product roadmap is constrained by these rules. We accept that.
