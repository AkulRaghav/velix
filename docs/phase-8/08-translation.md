# 08 — Translation

On-device by default. Cloud only for long-form, opt-in per query.

## Two paths

### Path A — On-device per-message (default)

Triggered when:
- Incoming message language ≠ user's locale.
- Local language-ID model classifies with confidence ≥ 0.85.

UX:
```
[message bubble]
[Translate to English]   ← affordance, subtle, below the bubble
```

Tap → on-device NLLB-distilled translates → translation rendered inline below the original.

The original is always preserved. The translation is shown as a secondary line in `text.secondary` color. Users can hide translations by tapping.

### Path B — Cloud, long-form

Triggered when:
- User selects > 1,500 characters.
- User taps "Translate with cloud assistance."

This requires per-query consent + redaction (Phase 8 doc 06) + OHTTP relay (Phase 8 doc 05). Output rendered as a quoted block.

## Model selection

| Path | Model |
|---|---|
| A — short | `velix_translate_nllb_distilled_v1` (50 MB, 200 languages) |
| B — long | Cloud — Anthropic Claude with translation system prompt |

Why cloud for long-form: the on-device NLLB-distilled has a 512-token context window. Long passages get fragmented; quality drops. The cloud model handles 50k-token contexts coherently.

Why not always cloud: privacy. Most messages are short; on-device handles them at high quality.

## Language detection

Separate small model (~2 MB), runs on every incoming message body. Output: language code + confidence.

If confidence < 0.85, we don't show the Translate affordance. We don't want to mis-detect English as German on a single short word.

The detection model is ALWAYS loaded; it's tiny. Translation models are lazy-loaded by language pair.

## Per-conversation defaults

| Setting | Effect |
|---|---|
| Always translate | Auto-translate every incoming foreign message; equivalent to tapping Translate every time |
| Translate on tap (default) | Affordance shown; user taps to translate each |
| Off | No affordance; no auto-detection |

Set in conversation menu → Translation.

The "Always translate" mode runs on-device, so it's free; no quota usage.

## Caching

Translation results are cached in SQLCipher per `(message_id, target_lang)` with a 30-day TTL. Re-rendering the conversation does not re-translate.

The cache is encrypted at rest (it's part of the local DB).

## Quality posture

- For most languages → most languages, NLLB-distilled is good enough.
- For literary, technical, or idiomatic content, the user can use the cloud path explicitly.
- We do NOT auto-escalate from local to cloud on quality grounds. Quality vs privacy is the user's choice.

## Failure modes

| Failure | Behavior |
|---|---|
| Local model not yet downloaded | "Download translation model (50 MB)?" prompt |
| Local model returns gibberish (NaN) | "Translation unavailable for this message" |
| Cloud quota exceeded | UX shows quota state; user can wait or upgrade |
| Detection confidence too low | No affordance shown |

## Banned

- Auto-translating to a different language than the user's locale (UX bug).
- Sending the original to cloud translation while showing the on-device version "for confirmation."
- Translating private chat content without the user's tap, even if "Always translate" is on (the user enabled the feature; that IS the gesture).
- Cross-conversation translation context.
- Translation that strips formatting (we preserve newlines and basic structure).
- Translation that stores the result in plaintext outside SQLCipher.
