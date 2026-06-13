# 03 — Realtime Motion

The three permitted "loops" in the system. Each is **input-driven**, never metronomic. Each fits inside the budget. Each has a static (motion-off) variant that preserves the information.

## Voice waveform

Real audio amplitude → seven vertical bars. Used during recording and during playback of voice messages.

### Visual contract

- Seven bars centered horizontally
- Bar width: 4 px
- Bar gap: 6 px
- Bar height range: 4 px (silence) to 32 px (peak)
- Color: `accent.signature` for active (recording, playing); `text.secondary` for inactive playback frames already passed
- Corner radius: `radius.pill`

### Driving signal

#### Recording
The platform mic exposes 100 Hz amplitude samples (10 ms intervals). We low-pass at 30 Hz (33 ms) to defeat fragmenting jitter. Each render frame, we sample the latest 7 windowed RMS values and map to bar heights.

#### Playback
A pre-computed amplitude envelope is generated server-side... no, we generate it on-device when the recording is captured (the recipient receives the encrypted audio + the encrypted envelope). Envelope is 50 samples per second, encoded as 7-bit unsigned integers (50 bytes/sec). For a 30-second voice message: 1.5 KB extra.

During playback, the seven visible bars represent a moving 7-sample window over the envelope, advancing at the playback head's rate.

### Implementation

`Waveform` is a `CustomPainter` reading a `WaveformSource` listenable. The painter draws seven `RRect`s on every paint. No widget-level animation; the listenable change drives `setState` in a parent.

Repaint is gated to ≤ 30 fps for waveform (perceptually indistinguishable from 60, half the GPU cost).

```dart
Waveform({
  required WaveformSource source,
  Color? activeColor,
  Color? inactiveColor,
})
```

`WaveformSource` has two implementations:
- `MicWaveformSource` — wraps platform mic with low-pass filter
- `EnvelopeWaveformSource` — replays a recorded envelope at the playback rate

### Reduce Motion

Bars freeze at the mid-amplitude resting state (8 px each). The audio still plays; the visualization is static. The duration timer continues to update (see typography numerals).

### Performance contract

- Paint cost: ≤ 0.2 ms per frame on iPhone 12
- Repaint rate: 30 fps
- Total CPU during a 30-second recording: < 0.5%

### Banned

- Random or pseudo-random animation when no audio is playing.
- Sin-wave-only fallbacks. If we don't have audio, we don't pretend.

---

## AI streaming token reveal

Tokens arrive from the AI gateway at variable rate. Each token fades in over 60 ms with a 12 ms delay between tokens. The total animation is paced by token arrival — when the model thinks, the reveal pauses.

### Visual contract

- Token text starts at opacity 0
- Fades to opacity 1 via `motion.reveal` curve over 60 ms
- 12 ms gap to next token (so a fast model produces a near-continuous flow; a slow model leaves visible pauses)
- After the final token, the entire reply settles to a single steady-state surface (no further animation)

### Implementation

`AIStreamingText` accepts a `Stream<String>` of token deltas. Internally, each new token is appended to a buffer with a per-token `Tween<double>` for opacity. Old tokens stay opaque. The widget repaints on each token, animating only the most-recent ~3 tokens (older tokens are already at opacity 1 and need no repaint).

```dart
AIStreamingText({
  required Stream<String> tokens,
  TextStyle? style,
  EdgeInsetsGeometry? padding,
})
```

### Accessibility

The streaming animation is **not announced** token-by-token to AT — that is deafening. Instead:

- A `Semantics(liveRegion: true, label: 'AI thinking')` is announced on the first token of a new response.
- The full response is announced once on completion (when the stream closes).
- Mid-stream, the user can interrupt; that fires a `LiveRegion` of `'Interrupted'`.

### Reduce Motion

Tokens appear instantly without fade. The 12 ms gap is preserved (so the stream feels paced, not flat-spammed).

### Performance contract

- Per-token cost: < 0.1 ms / paint
- Memory: bounded by message length (text only, no decoration)
- A 500-token response paints in steady state at < 0.05 ms (only the trailing 1-3 tokens are still animating)

### Banned

- A "typing" cursor blinking while the AI is thinking. We use the LiveRegion announcement and a static trailing ellipsis only.
- Token-by-token color-shift effects.
- Re-flowing text mid-stream that causes visible reflow shifts (we right-pad the buffer to defeat this).

---

## Typing indicator

Three dots, one of which fades up at any time. The classic, executed without ornament. The third permitted loop.

### Visual contract

- Three dots horizontally arranged, 6 px diameter, 6 px gap
- Each dot transitions opacity 0.3 → 1.0 → 0.3 over 1.4 s, offset by 0.467 s per dot (a third of the period)
- Color: `accent.signature` at 50% lightness — quieter than UI accents, intentionally low-contrast so it doesn't compete

### Implementation

A `CustomPainter` driven by a single repeating `AnimationController` of `Duration(milliseconds: 1400)`. Each dot's opacity is computed from the controller's value plus its offset.

```dart
TypingIndicator({
  Color? color,
  double size = 6,
})
```

### Behavior rules

- Appears within 250 ms of receiving a "typing" event from the conversation peer.
- Disappears after 4 seconds without an update (the last `typing=true` ping is stale).
- Disappears immediately when an actual message arrives.
- Never appears in a system-generated event surface (notifications, settings, etc.).

### Accessibility

- Announced once on appear: `'{name} is typing'`. Not announced again until cleared.
- Reduce Motion: the three dots are static at 0.7 opacity each. Same accessibility announcement.

### Performance contract

- Paint cost: < 0.1 ms / frame
- Total cost over a 30-second typing session: imperceptible (~0.05% CPU)

### Banned

- "Typing" with a longer animation (e.g., dot-bounce-along-a-curve).
- Multiple typing indicators stacked when multiple peers are typing in a group; we collapse to a single `'{n} people are typing'` line at `type.body.s`.
- Typing indicator outside conversation surfaces.

---

## What we do NOT animate

For completeness, common "loop" patterns Velix refuses:

- Pulsing send-button to attract attention
- Rotating logo in the splash (handled with a one-shot reveal)
- Breathing CTAs
- Auto-advancing carousels (the user advances)
- Hover glow on idle elements (we have no hover state — touch is press-and-release)
- Marching-ants borders
- Pull-tab-to-show-more swipe hints
- Confetti on success
- "Heart-fly" animations on like
- Trailing-cursor effects on user input

Each is the kind of thing that ages a UI to "2017 SaaS" within a year.
