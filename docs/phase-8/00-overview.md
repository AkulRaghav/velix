# 00 — AI Architecture Overview

## Position

The AI layer in Velix exists to make four things faster: composing replies, translating across languages, summarizing long threads, and answering questions the user asks the assistant directly. That's it. Every AI feature is an *enhancement* of what the user already does explicitly; nothing happens to the user's data without the user's explicit, per-query gesture.

This phase operates within the cryptographic architecture from Phase 7. The AI layer is not allowed to weaken any property P1–P16 from Phase 7 doc 01. The trust boundary in `01-trust-boundary.md` is the immovable constraint; everything else flows from it.

## Pillars

1. **On-device first.** Smart reply, summarization, translation, moderation, and search expansion run on-device by default. Cloud AI is a deliberate user gesture, not a default.
2. **Per-query opt-in.** Cloud AI queries require an explicit user action per query. We do not "remember" consent across queries. We do not pre-fetch.
3. **Trust level 4 forever.** The AI gateway sits at the same trust level as Cloudflare R2 and APNs/FCM. It can never become level 1-3. The architecture forecloses that path.
4. **Privacy-preserving relay.** Cloud queries flow through an OHTTP-style relay that decouples identity from content. The gateway sees content but not who sent it.
5. **No background AI.** No scheduled scans. No daily summaries. No "while you were away, the AI organized your inbox." If the user isn't actively asking, AI doesn't run.
6. **Bounded local model scope.** On-device models are small, fast, focused. We do not run general-purpose LLMs on-device. The local models do specific jobs: smart-reply selection, language ID, short summarization, moderation classification.
7. **Failure is a fallback to nothing.** If the AI fails, the user sees the no-AI state — never an unauthorized retry against a different provider, never silent escalation to a less-private channel.

## What ships in 1.0

| Feature | Posture | Trust level |
|---|---|---|
| Smart reply | On-device, default-on, no opt-in (suggestions only) | 1-3 |
| Translation (per-message) | On-device, opt-in per-conversation | 1-3 |
| Translation (long-form, cloud) | Cloud, opt-in per query | 4 |
| Summarization (≤ 200 messages) | On-device, opt-in per query | 1-3 |
| Summarization (long-form, cloud) | Cloud, opt-in per query | 4 |
| Live captions on calls | On-device, opt-in per call | 1-3 |
| AI assistant (open-ended Q&A) | Cloud, separate sheet, opt-in per query | 4 |
| Moderation (Spaces) | On-device, owner-configured per Space | 1-3 |
| Search expansion ("find the thing about X") | On-device, opt-in per query | 1-3 |

## Stack (locked, Phase 8)

| Concern | Choice | Justification |
|---|---|---|
| On-device inference | TFLite (Android, iOS, Linux), CoreML (Apple Silicon, iOS A14+), MediaPipe (cross-platform) | Battle-tested; small footprint |
| iOS-specific small-model path | Apple Foundation Models / Apple Intelligence APIs (where available) | Native, no app-bundle bloat |
| Android-specific small-model path | Gemini Nano via AI Core (Pixel 8+), MediaPipe LLM Inference (others) | Vendor-supplied small models |
| Translation small models | NLLB-200 distilled / on-device via TFLite | Open-source; self-hostable |
| Cloud assistant model | Claude (Anthropic) via gateway, with OpenAI as failover | Best privacy posture per contract |
| Cloud relay | OHTTP via dedicated relay operator (Cloudflare Privacy Pass / Fastly equivalent) | Separates IP from content |
| Gateway | Velix-operated; minimal logic; routes to provider | Velix-controlled trust surface |
| Telemetry | OTel aggregate counters only | No content; no per-user breadcrumbs |

We do **not** use:
- Federated learning. (We never train on user content.)
- Differential-privacy aggregation. (Same; user content is never an input to anything we train.)
- "Background prefetch" of summaries. (Banned per Phase 7 trust model.)
- A single AI provider as exclusive (we want failover; we want negotiating leverage).

## Top-level shape

```
                  ┌─────────────────────────────┐
                  │     User gesture            │
                  │  (highlight + tap "Ask AI") │
                  └──────────────┬──────────────┘
                                 │
                  ┌──────────────▼──────────────┐
                  │   velix_ai (Dart package)   │
                  │     Routing layer           │
                  │     • picks on-device or    │
                  │       cloud                 │
                  │     • redacts/sanitizes     │
                  │     • requests consent UX   │
                  └──────┬──────────┬───────────┘
                         │          │
                  ┌──────▼──┐   ┌───▼──────────┐
                  │ on-     │   │ cloud relay  │
                  │ device  │   │ (OHTTP)      │
                  │ TFLite/ │   │              │
                  │ CoreML  │   │              │
                  └─────────┘   └──────┬───────┘
                                       │
                                ┌──────▼─────────┐
                                │ velix_ai_      │
                                │ gateway        │
                                │ (Velix-run)    │
                                │  • policy      │
                                │  • rate limit  │
                                │  • route       │
                                └──────┬─────────┘
                                       │
                                ┌──────▼─────────┐
                                │ Model provider │
                                │ (Anthropic,    │
                                │  OpenAI ...)   │
                                └────────────────┘
```

## Module layout

```
packages/velix_ai/                     ← Dart-side AI package
  lib/
    velix_ai.dart                      ← public surface
    src/
      router.dart                      ← decides on-device vs cloud
      consent.dart                     ← per-query opt-in tokens
      redaction.dart                   ← prompt sanitization
      on_device/
        smart_reply.dart
        translate.dart
        summarize.dart
        moderate.dart
        search_expand.dart
      cloud/
        relay_client.dart              ← OHTTP-relayed gateway client
        request.dart                   ← typed prompt envelope
        response.dart
      models/
        registry.dart                  ← which models we ship
        download.dart                  ← lazy fetch for large local models

backend/services/ai_gateway/           ← Velix-operated gateway (Phase 8.5)
  internal/
    handlers/
    policy/
    providers/                         ← Anthropic, OpenAI clients
    rate_limit/
```

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | this | Pillars, stack, top-level shape |
| 01 | [Trust Boundary](./01-trust-boundary.md) | Where AI sits in the trust hierarchy; what's banned |
| 02 | [Data Flows](./02-data-flows.md) | Per-feature step-by-step flows |
| 03 | [Consent & Opt-in](./03-consent-and-opt-in.md) | Per-query gesture model, UX |
| 04 | [On-Device Models](./04-on-device-models.md) | What ships, sizes, performance budgets |
| 05 | [Cloud Relay (OHTTP)](./05-cloud-relay.md) | Identity decoupling, gateway protocol |
| 06 | [Prompt Sanitization](./06-prompt-sanitization.md) | Redaction, injection defense, output filtering |
| 07 | [Smart Reply](./07-smart-reply.md) | Local model, ranking, never-auto-send rule |
| 08 | [Translation](./08-translation.md) | Detection, NLLB, cloud assist for long-form |
| 09 | [Summarization](./09-summarization.md) | Local short-form; cloud for >200 messages |
| 10 | [Moderation](./10-moderation.md) | On-device classification for Spaces |
| 11 | [Live Captions](./11-live-captions.md) | On-device audio→text during calls |
| 12 | [AI Assistant](./12-ai-assistant.md) | The bottom-sheet open-Q&A surface |
| 13 | [Rate Limits & Quotas](./13-rate-limits-and-quotas.md) | Per-account caps; abuse defense |
| 14 | [Telemetry](./14-telemetry.md) | What we count; what we don't |
| 15 | [Privacy Tradeoffs](./15-privacy-tradeoffs.md) | What cloud AI costs; honest disclosure |
| 16 | [Phase 8 Audit](./16-phase-8-audit.md) | Self-review, gating Phase 9 |

## Banned at the architecture level

- A future "auto-summary" feature that reads conversations without explicit invocation.
- A future "AI inbox" feature that ranks messages.
- A future "smart notifications" that decide priority by content.
- A future "conversation insights" derived from message bodies.
- Storing any AI invocation tied to a user identity beyond the immediate response.
- Sharing AI usage data across users.
- Using user content for training (any provider).
- Running a general-purpose LLM on-device that loads conversations as context.
- A "free trial" that bypasses opt-in.
- Selling AI usage data.

## Performance targets

| Operation | Target |
|---|---|
| On-device smart-reply suggestion | ≤ 80 ms on iPhone 12 / Pixel 6 |
| On-device language detection | ≤ 5 ms |
| On-device translation (single message ≤ 500 chars) | ≤ 200 ms |
| On-device summarization (50 messages, ≤ 5k chars total) | ≤ 800 ms |
| On-device moderation classification | ≤ 30 ms |
| Cloud assistant first-token latency | ≤ 600 ms |
| Cloud assistant streaming throughput | ≥ 30 tokens/sec |
| Cloud relay overhead (OHTTP roundtrip) | ≤ 80 ms |

These bound the user-visible latency. We benchmark on reference devices in CI.

## What this phase ships vs Phase 8.5 fills in

**Ships in Phase 8:**
- Architecture (this folder, 17 docs).
- The `velix_ai` Dart package skeleton with router, consent, redaction.
- The gateway protocol spec (proto + relay design).
- Self-audit.

**Fills in during Phase 8.5:**
- Vendor specific TFLite / CoreML / Gemini Nano model integrations.
- The Velix gateway service (Go, Phase 6 patterns).
- OHTTP relay operator selection and contract.
- Provider contracts (Anthropic, OpenAI no-train-on-data clauses).
- The actual local model files (downloaded lazily; signed; integrity-checked).

The architecture work in Phase 8 is what's structurally hard. The implementation in 8.5 is mechanical.
