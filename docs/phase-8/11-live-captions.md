# 11 — Live Captions on Calls

On-device, opt-in per call, never persisted.

## Why on-device only

Live captions require continuous audio access. Streaming a call's audio to a cloud STT service would expose every spoken word for the duration of the call.

Even with OHTTP, the cost-benefit is wrong: a casual call user gets minor transcription quality lift in exchange for transmitting their voice continuously. We do not ship that.

## Implementation

### iOS / macOS

`SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`. Available on most modern devices for major locales.

If `supportsOnDeviceRecognition` is false for the requested locale (some less-common locales lack on-device models), we **do not fall back** to cloud STT. Captions are unavailable for that locale.

### Android

`SpeechRecognizer` with `EXTRA_PREFER_OFFLINE` set. On Android 13+, on-device recognition is reliable for major locales.

If on-device isn't available, captions are unavailable.

### Other platforms

- Windows: Azure speech services are not used; we ship Whisper-tiny via WebRTC's onnxruntime where feasible.
- Linux: same.
- Web: not supported in 1.0.

## UX

Per-call toggle in the call control bar. State:

- Off (default): no captions.
- On: rolling captions overlay at the bottom of the call view; ~3 lines visible; older lines fade out.

The captions are part of the call's transient state — no persistence. When the call ends, captions are gone.

## Privacy properties

- Audio is captured by the device for the call (it's already being captured for the call's outbound stream).
- A copy of the locally-decrypted audio (after LiveKit decode) is fed to the on-device STT model.
- The STT model produces text.
- The text is rendered as overlay.
- Nothing is sent over the network beyond the standard call traffic.

If the user records the call (via OS-level screen recording or other), they capture the captions. We don't prevent this; the user is in control of their device.

## Per-language

Captions are per-locale. The active locale matches the user's system locale.

For multilingual calls (participant A speaks French, participant B speaks English), captions only transcribe the local-locale audio with reasonable quality. Non-locale speakers' captions are best-effort or off.

A future enhancement: per-participant locale selection. Phase 8.5 if user demand exists.

## Latency

Captions appear with a 0.5-1 second delay relative to spoken audio. Acceptable for live use.

## Failure modes

| Failure | Behavior |
|---|---|
| On-device STT unavailable for locale | Captions toggle disabled; tooltip explains |
| STT runs out of memory | Captions stop; user notified |
| OS denies microphone-meta access | Captions disabled at OS level; no app workaround |
| Background — caller is on lock screen | Captions pause; resume on foreground |

## Telemetry

```
velix_live_captions_enabled_total{platform, locale}
velix_live_captions_word_rate_per_second   histogram
```

We count enables and aggregate word rate (which has no PII). We don't count caption text; we don't store transcripts.

## Banned

- Cloud STT, even as a "fallback for unsupported locales."
- Persisting captions to disk.
- Sending captions to other call participants as data (the captions are local; the audio is shared; participants who want captions enable them on their own device).
- Storing call transcripts at any layer (Velix-the-company, LiveKit, anyone).
- Sharing the on-device STT output with any subsystem (e.g., feeding captions to the smart-reply model).
- Real-time transcription of recorded calls (we don't record calls).
