# 03 — Consent & Opt-in Model

## The principle

Every cloud AI invocation requires a fresh, explicit, per-query user gesture. We do not "remember" consent across queries. We do not pre-fetch. We do not "while we have you here" any AI traffic.

This is the strictest possible interpretation of "opt-in." We accept the friction. The friction is the feature.

## Three consent tiers

| Tier | What it covers | Default | Where set |
|---|---|---|---|
| **Global AI off** | All AI features, on-device included | Off (AI fully disabled) | Settings → AI |
| **Per-feature toggle** | Translation auto-detect, smart reply suggestions, etc. | Off for cloud features; On for non-content on-device features (smart reply chips, language detection) | Settings → AI |
| **Per-query consent** | Each cloud invocation | Required every time | In-line UX |

A user with the global toggle off sees no AI suggestions, no translation prompts, no assistant FAB. The product remains fully usable.

A user with the global toggle on but per-feature toggles off sees the affordances that would invoke each feature (e.g., a "Translate" hint appears for foreign messages) but no auto-execution.

A user with both global on and per-feature on still requires the per-query consent for every cloud invocation. Per-query consent is **never** auto-granted.

## What "per-query consent" looks like

A simple, calm UX. Not a dark pattern. No misleading copy.

For each cloud invocation, the user sees a Tier-3 modal with:

```
┌──────────────────────────────────────────────────┐
│   Send to Velix AI?                              │
│                                                   │
│   This text will be processed without            │
│   identifying you. It will not be stored.        │
│                                                   │
│   ┌─────────────────────────────────┐            │
│   │  "Translate this French paragraph│            │
│   │   into English: ..."             │            │
│   │                                  │            │
│   │  (preview of redacted content)   │            │
│   └─────────────────────────────────┘            │
│                                                   │
│   [ Cancel ]              [ Send ]               │
└──────────────────────────────────────────────────┘
```

The preview is the **redacted** content — what the gateway will actually see. The user reviews before consenting. If they tap Send, the redacted content goes; if they tap Cancel, nothing happens.

This UX is the same shape as iOS's "Send anonymized location" prompt or macOS's "Allow access to camera" prompt. Calm, factual, action-oriented.

## What we do not do

Anti-patterns we deliberately refuse:

| Anti-pattern | Why we refuse |
|---|---|
| "Remember my consent for this conversation" | Defeats per-query consent. We refuse. |
| "Skip the consent dialog if the user has used AI before" | Same. |
| "Auto-accept consent for translation when in foreign-language conversations" | Defeats per-query consent. |
| "Send to AI in background while the user composes" | Bypasses per-query gesture. |
| Pre-warming the gateway with content before the user taps Send | Defeats per-query consent. |
| Hiding the consent dialog inside a settings flow | Consent must be visible at the moment of invocation. |
| Defaults that pre-check "Send to AI" | Decision must be the user's. |
| Showing the consent dialog with "Send" pre-focused | Yes-bias. We make Cancel and Send equally weighted. |

## Per-query consent token

The consent gesture mints a one-shot, short-lived token:

```
consent_token = HMAC-SHA-256(
                    key=client_consent_seed,
                    data="velix.ai.consent.v1" || query_id || expires_at)
```

- `query_id`: ULID generated at consent time.
- `expires_at`: 60 seconds after consent.
- `client_consent_seed`: 32-byte device-local secret.

The token is included in the OHTTP request to the gateway. The gateway verifies the HMAC against the client's published consent-seed (per-device, refreshed per session). After verification, the gateway processes the request.

This prevents:
- Replay (`expires_at` enforces 60 s window).
- Forgery without the device's seed (the seed is the device's; not the gateway's).
- Cross-device replay (each device has its own seed).

The token is single-use (gateway tracks `query_id` for 5 minutes; second use of the same id rejected).

## Per-feature defaults

| Feature | Default state |
|---|---|
| Smart reply | On (on-device only; never auto-sends content) |
| Translation auto-detection | On (on-device language ID; never auto-translates) |
| Translation tap-to-translate (on-device) | On |
| Translation cloud-assisted (long-form) | Off |
| Summarization (on-device, short) | Off |
| Summarization (cloud, long) | Off |
| AI assistant (open Q&A) | Off |
| Moderation in Spaces | On per Space owner choice |
| Live captions on calls | Off |
| Search expansion | Off |

The cloud-eligible features all default off. Users opt in once globally + per-query.

## Consent UX accessibility

VoiceOver and TalkBack readout for the consent modal:

```
"Send to Velix AI?

This text will be processed without identifying you.
It will not be stored.

Preview of content to be sent:
[reads the redacted content aloud]

Two actions: Cancel and Send.
```

The actions are equally announced; we do NOT pre-announce "Send" as "default action."

Per-query consent thresholds in Accessibility settings:
- Standard (≤ 1 s) — default
- Confirmed-tap-and-hold (≥ 500 ms hold) — for users who frequently misclick
- Voice-confirm (says "Send" aloud) — accessibility option

## Auditing the consent flow

Every consent prompt emits a content-free telemetry event:

```
velix_ai_consent_shown_total{feature}
velix_ai_consent_accepted_total{feature}
velix_ai_consent_declined_total{feature}
```

We track the funnel for product purposes (does the consent UX have unusable friction?) but never the prompt content or the response.

A deviation from these counts (e.g., 1000 invocations but only 800 consent_shown) would indicate a code path that bypassed consent. CI tests assert the ratio is 1:1.

## Revoking consent

The user can revoke any AI feature at any time in Settings → AI. Revocation is immediate; in-flight queries cancel.

The user can also clear all AI session state in one tap: "Clear AI session" — wipes the consent seed, clears any cached on-device model state, removes any locally-cached AI responses. Useful before passing the device to someone else.

## What we deliberately don't track

- Per-user AI usage history.
- Time-of-day heatmaps of AI invocations.
- Topic frequencies.
- Provider routing decisions per user.
- Anything that would allow us to say "user X used AI Y times last week."

The aggregate metrics tell us the system is healthy. Per-user metrics would defeat the privacy property.

## Banned

- Any consent UX that pre-selects "Send."
- Any consent UX that hides the redacted preview.
- Any feature flag that disables the consent modal.
- A "developer mode" that auto-consents (we don't ship this even for ourselves).
- Caching consent across queries.
- Pre-warming the gateway with speculative content.
- Sending consent tokens that can be reused.
