# Phase 8 — AI Systems

Status: in progress. Gates Phase 9.

## What ships

The complete AI architecture, operating strictly within Phase 7's cryptographic boundary. The AI layer is on-device-first; cloud invocation is via an OHTTP-relayed gateway that cannot correlate identity with content; every cloud query requires explicit per-query consent.

The package skeleton (`packages/velix_ai/`) ships the router, redaction pipeline, consent types, and the abstract on-device + cloud backend interfaces. Phase 8.5 fills in the platform-specific TFLite/CoreML/Gemini Nano integrations and the OHTTP relay client.

## Locked posture

- **On-device first.** Smart reply, language ID, on-device translation, on-device summarization, moderation, live captions, and intent extraction run on the device. No content leaves.
- **Cloud is opt-in per query.** Every cloud invocation requires a fresh user gesture. We do not "remember" consent across queries. We do not pre-fetch.
- **AI gateway is at trust level 4 forever.** Same level as Cloudflare R2 and APNs/FCM. The architecture forecloses any path to level 1-3.
- **OHTTP relay decouples identity from content.** A Cloudflare-Privacy-Pass-style relay sees IP + opaque ciphertext; the Velix gateway sees content + the relay's IP, no user identity.
- **No background AI.** No scheduled scans. No daily summaries. If the user isn't actively asking, AI doesn't run.
- **No memory across queries.** Every assistant query is a fresh context. The assistant cannot read other conversations, modify state, or take actions.
- **Aggressive redaction.** Every cloud-bound prompt is redacted (emails, phones, URLs, handles, control characters) before the user sees it for consent. Aggressive mode for summarization additionally collapses proper nouns and numbers.

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [Overview](./00-overview.md) | Pillars, stack, top-level shape |
| 01 | [Trust Boundary](./01-trust-boundary.md) | Where AI sits in Phase 7's trust hierarchy |
| 02 | [Data Flows](./02-data-flows.md) | Per-feature step-by-step paths |
| 03 | [Consent & Opt-in](./03-consent-and-opt-in.md) | Per-query gesture model and UX |
| 04 | [On-Device Models](./04-on-device-models.md) | What ships, sizes, runtimes, performance |
| 05 | [Cloud Relay (OHTTP)](./05-cloud-relay.md) | Identity decoupling, gateway, anonymous quota |
| 06 | [Prompt Sanitization](./06-prompt-sanitization.md) | Redaction, injection defense, output filtering |
| 07 | [Smart Reply](./07-smart-reply.md) | On-device, default-on, never auto-send |
| 08 | [Translation](./08-translation.md) | On-device default; cloud opt-in for long-form |
| 09 | [Summarization](./09-summarization.md) | On-device for short, cloud for long with strict redaction |
| 10 | [Moderation](./10-moderation.md) | Decentralized, on-device, per-recipient |
| 11 | [Live Captions](./11-live-captions.md) | On-device only; never persisted |
| 12 | [AI Assistant](./12-ai-assistant.md) | Read-only Q&A, no memory, no tools |
| 13 | [Rate Limits & Quotas](./13-rate-limits-and-quotas.md) | Privacy-Pass-style anonymous credentials |
| 14 | [Telemetry](./14-telemetry.md) | What we count; what we never log |
| 15 | [Privacy Tradeoffs](./15-privacy-tradeoffs.md) | Honest disclosure of cloud AI cost |
| 16 | [Phase 8 Audit](./16-phase-8-audit.md) | Self-review, gating Phase 9 |

## Reference implementation

```
packages/velix_ai/
  lib/velix_ai.dart                    ← public surface
  lib/src/
    types.dart                         ← AIFeature, InferenceLocation, AIOutcome enums
    redaction.dart                     ← Redactor.redact + idempotency check
    consent.dart                       ← ConsentToken, ConsentProvider, NoConsentRequired
    router.dart                        ← AIRouter: on-device first, cloud opt-in, OHTTP-bound
  test/redaction_test.dart             ← redaction + idempotency + AIResult tests
```

The Rust crate `velix_crypto_core` (Phase 7) is unaffected. The backend `ai_gateway` service (Phase 6 patterns) is scaffolded in Phase 8.5 with the contracts from Phase 8 doc 05.

## Reading order

If you have ten minutes: 00 → 01 → 16.
If you're integrating in the client: 04 → 03 → 06 → 07 → 08.
If you're operating the gateway: 05 → 06 → 13 → 14.
If you're auditing: 16 → 01 → 02 → 06 → 14.
