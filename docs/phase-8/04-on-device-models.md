# 04 — On-Device Models

Specifically: what we ship, what size, what runtime, how they're updated, and the performance budget.

## Constraints

- App bundle size adds ≤ 8 MB for AI runtimes (TFLite + XNNPack runtime + minimal MediaPipe).
- Per-model size ≤ 50 MB; lazy-downloaded on first use; cached.
- Total on-device model storage cap ≤ 250 MB; least-recently-used eviction.
- Inference must run on the dedicated AI isolate (Phase 5 architecture pattern), never on the UI thread.
- Battery cost ≤ 0.5% per minute of active inference on reference devices.
- Models are signed (Ed25519); integrity verified before load; failed verification = no AI.

## Runtime selection

We target the platform-optimal runtime per model:

| Platform | Default runtime | Hardware acceleration |
|---|---|---|
| iOS A14+ | CoreML | Apple Neural Engine |
| iOS A12-A13 | CoreML | GPU only |
| Apple Silicon Mac | CoreML | ANE |
| Android with NNAPI | TFLite via NNAPI delegate | GPU/NPU per device |
| Pixel 8+ | Gemini Nano via AI Core | TPU |
| Other Android | TFLite via XNNPack | CPU SIMD |
| Linux (desktop) | TFLite via XNNPack | CPU SIMD |
| Windows | TFLite via XNNPack | CPU SIMD |
| Web | (no on-device AI; fallbacks to no-AI) | n/a |

The runtime selection is automatic at app launch via a `RuntimeProbe` that benchmarks a tiny fixed model (~50 KB) to confirm the runtime works and to choose between options where multiple are available.

## Model catalog (1.0)

### Smart reply

- **Name:** `velix_smart_reply_en_v1`
- **Size:** ~12 MB
- **Runtime:** TFLite / CoreML
- **Input:** sequence of last 5 messages (concatenated, max 1024 tokens).
- **Output:** 3 candidate reply strings, max 60 chars each.
- **Languages:** English at 1.0; expansion via locale-specific models (each ~12 MB).
- **Inference:** ≤ 80 ms on iPhone 12.
- **Source:** distilled from a public Gboard-quality smart-reply baseline; fine-tuned by Velix on permissively-licensed conversational data (no user data).

### Translation

- **Name:** `velix_translate_nllb_distilled_v1`
- **Size:** ~50 MB (200 languages, distilled)
- **Runtime:** TFLite via XNNPack / CoreML
- **Input:** source text + (src_lang, tgt_lang) tags.
- **Output:** translated text.
- **Inference:** ≤ 200 ms for ≤ 500 chars.
- **Source:** NLLB-200 distilled (Meta, CC-BY-NC for the public release; we use it under the appropriate license terms or our own re-train).
- **Language ID:** separate small model, ~2 MB.

### Summarization (short)

- **Name:** `velix_summarize_short_v1`
- **Size:** ~30 MB
- **Runtime:** TFLite / CoreML / Gemini Nano (on Pixel 8+)
- **Input:** ≤ 5,000 characters of conversation.
- **Output:** 2-4 sentence summary.
- **Inference:** ≤ 800 ms.
- **Source:** seq2seq distilled from a public summarization baseline; Velix-tuned for conversational tone.

### Moderation

- **Name:** `velix_moderate_v1`
- **Size:** ~8 MB
- **Runtime:** TFLite
- **Input:** single message text.
- **Output:** classification probabilities for { harassment, sexual_explicit, csam, violence, spam, ok }.
- **Inference:** ≤ 30 ms.
- **Source:** distilled from public moderation classifier datasets; Velix-tuned on permissively-licensed labeled data.

### Live captions

- **Name:** uses platform-native API
  - iOS: `SFSpeechRecognizer` (on-device when available)
  - Android: `SpeechRecognizer` with on-device language model
- **Size:** 0 (uses platform models)
- **Inference:** real-time streaming.
- **Source:** Apple / Google.

### Intent extraction (search expansion)

- **Name:** `velix_intent_extract_v1`
- **Size:** ~6 MB
- **Runtime:** TFLite
- **Input:** user query + abstract metadata of last 7 days.
- **Output:** refined query + filters.
- **Inference:** ≤ 50 ms.

## Total on-device footprint

If a user enables every feature with model downloads:

```
Smart reply (en)       12 MB
Translate (NLLB)       50 MB
Summarize short        30 MB
Moderation              8 MB
Intent extract          6 MB
Live captions           0 (platform)
─────────────
Total                ~106 MB
```

Plus the runtimes (~8 MB). Total on-device AI footprint ≤ 120 MB for a fully-enabled user.

## Lazy download flow

Models are NOT shipped in the app bundle. They're downloaded on first use:

```
[user] enables a feature for the first time.
[client] checks model registry.
[client] if model missing:
            displays "First-time download (~50 MB). Use Wi-Fi?" prompt.
[user] confirms.
[client] downloads model from velix model CDN over HTTPS.
[client] verifies Ed25519 signature.
[client] writes to app's encrypted model cache.
[client] runs the feature.
```

The model registry is signed and version-pinned. A model file's hash is verified before load, every load.

The download endpoint is a static CDN (Cloudflare R2 or similar); no per-user identification.

## Updates

- Model files are versioned. New versions published periodically.
- Client checks for updates on launch (once per 24 hours).
- Update download requires Wi-Fi by default; user can override in Settings → AI.
- Old model versions are evicted after the new version is verified loadable.

## Storage

Models live in the app's data directory, encrypted by the OS-level full-disk encryption (we do NOT additionally encrypt model files; they're public assets). Hashes are stored in SQLCipher for integrity verification on every load.

## Failure modes

| Failure | Behavior |
|---|---|
| Model file corrupted | Re-download; if re-download fails, feature unavailable |
| Signature verification fails | Refuse to load; alert telemetry; feature unavailable |
| Inference returns NaN / inf / empty | Treat as feature failed; user sees no-AI state |
| Inference times out (> 5x target) | Treat as feature failed |
| Runtime probe fails on app launch | All on-device AI disabled for this device class |

## Update integrity

Every model has:

```
model_signed = model_bytes || Ed25519_signature(velix_model_signing_priv, hash(model_bytes))
```

The signing key is held in Vault; rotated annually. Public key shipped in the app bundle (compiled-in). A compromise of the signing key means we can ship a malicious model — we treat the model signing key as a Tier-1 production secret with the same protections as any other.

## Ban-list

- Models that produce text bodies > N characters (we cap output sizes per feature to defeat output amplification attacks).
- Models that don't ship with a signed manifest.
- Models compiled from unverified sources.
- Models that require Internet at inference time (defeats on-device guarantee).
- "Optional" cloud fallback inside an on-device feature — if it's on-device, it's on-device.

## Privacy properties

- On-device inference: no content leaves the device.
- No telemetry of inference results (we count invocations, not contents).
- No per-user model fine-tuning (we don't ship that path).
- No federated learning.
- No user-content-derived gradients sent anywhere.

## Banned

- Sending decoded-but-low-confidence outputs to a cloud model "for confirmation."
- Auto-redownloading models that the user explicitly removed.
- Models that haven't passed our internal evaluation (privacy + safety + quality).
- Operating system speech-to-text APIs that send audio off-device (we use only on-device modes).
- Bundle-included models. (We use lazy-download to keep app install size reasonable.)
