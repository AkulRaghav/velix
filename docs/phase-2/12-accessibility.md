# 12 — Accessibility Implementation

Carried forward from Phase 1 audit. Accessibility is not an audit pass; it is the design medium. We meet **WCAG 2.2 AA** for all primary flows by 1.0, and we will exceed it where the cost is small.

This document specifies *concrete behavior*, not platitudes — what the screen reader announces, where focus goes, what contrast is verified, and what fails CI.

## Standards we commit to

- **WCAG 2.2 AA** for every primary flow at 1.0.
- **WCAG 2.2 AAA** for body text against substrate (we naturally exceed because of our color choices).
- **iOS HIG accessibility** — VoiceOver, Switch Control, Voice Control, Dynamic Type up to AX5, Reduce Motion, Reduce Transparency, Increase Contrast, Differentiate Without Color, Bold Text, Smart Invert.
- **Android accessibility guidelines** — TalkBack, Switch Access, Voice Access, font scale up to 200%, large text, high-contrast text, Color Inversion, Color Correction.
- **EN 301 549** (EU public-sector procurement standard, often required for enterprise customers).
- **Section 508** (US federal procurement).

## Color contrast verification

Every pairing in the system has a verified contrast ratio. We track these in `accessibility-contrast.json` (machine-readable) and check them in CI on token changes.

| Pairing | WCAG ratio | Standard | Notes |
|---|---|---|---|
| `text.primary` on `surface.substrate` | 16.8:1 | AAA | body and headings |
| `text.primary` on `surface.quiet` | 14.2:1 | AAA | |
| `text.primary` on `surface.active` | 12.4:1 | AAA | |
| `text.primary` on `surface.lifted` | 11.0:1 | AAA | |
| `text.secondary` on substrate | 9.1:1 | AAA | |
| `text.secondary` on quiet | 7.8:1 | AAA | |
| `text.secondary` on active | 6.6:1 | AA (≥18pt or bold ≥14pt) — verified | |
| `text.tertiary` on substrate | 5.3:1 | AA-only at body.l, fails AA on body.s | — never use tertiary at body.s |
| `text.tertiary` on quiet | 4.6:1 | AA at body.l only | |
| `text.disabled` on substrate | 3.1:1 | AA-large only | only used for disabled controls |
| `text.inverse` on `accent.A.30` (Brand A) | 7.3:1 | AAA | for primary buttons |
| `text.inverse` on `accent.B.30` (Brand B) | 6.4:1 | AA | for primary buttons |
| `text.inverse` on `accent.C.30` (Brand C) | 6.0:1 | AA | for primary buttons |
| `accent.A.30` on substrate (CTA tertiary) | 5.7:1 | AA | |
| `accent.B.30` on substrate | 5.0:1 | AA-large | use Bold weight for inline CTAs |
| `accent.C.30` on substrate | 7.2:1 | AAA | |
| `semantic.danger` on substrate | 4.9:1 | AA | |
| `semantic.success` on substrate | 7.0:1 | AAA | |
| `semantic.warning` on substrate | 8.4:1 | AAA | |

**Trust tints** are sub-perceptual color shifts intended to remain *below* WCAG-meaningful contrast — they reinforce, but never replace, an explicit textual or material signal. The encryption-shield glyph and verbal LiveRegion announcement carry the meaning; the tint is felt.

## Color is never the only signal

This is the strictest rule, codified at the system level.

| Meaning | Color signal | Non-color signal |
|---|---|---|
| Active tab | accent | weight + scale + spotlight |
| Pressed button | -1.5% lightness | scale 0.97 + inset shadow |
| Error input | bottom border red | shake (one) + helper text + icon |
| Online presence | green dot | dot is **inset** (negative space) — distinct shape |
| Verified contact | warm tint | encryption-shield glyph + textual "Verified" |
| Re-keyed contact | cool tint | shield glyph state + tremor + LiveRegion announcement |
| Unread message | accent dot | cell ordering + no-read-receipts-shown |
| Destructive action | red text | "Delete forever" wording + confirm dialog |

CI lint catches new color usage that has no paired non-color signal.

## Dynamic Type / Font Scale

We support:
- **iOS Dynamic Type** up to `AX5` (200% scale).
- **Android Font scale** up to 200%.
- **Bold Text** (iOS) / **High-contrast text** (Android).

Every type token has a documented behavior at each scale. Body text scales 1:1. Display tokens scale to a maximum of 150% to avoid wrapping past the screen edge. Label tokens scale 1:1 but with intelligent line-break (we wrap to two lines rather than truncate).

We test every primary screen at 100% / 130% / 160% / 200% scale. Layouts re-flow vertically; nothing is clipped; nothing is elided unless the elision has a Semantics-readable expansion (i.e., an AT user gets the full text).

## Reduce Motion

When `MediaQuery.of(context).disableAnimations` is true (mapped from iOS Reduce Motion / Android Remove Animations):

- Every spring becomes a 120 ms cross-fade.
- Parallax disappears.
- Stagger disappears (children arrive simultaneously).
- Auto-play of stories pauses; stories advance only on tap.
- Loader.pulse becomes static.
- The trust-state tremor is removed (the verbal announcement remains).

Layout pre-state and post-state remain identical so screen content is exactly the same; only the *transit* is altered.

## Reduce Transparency

When `MediaQuery.of(context).highContrast` is true (often paired with Reduce Transparency on iOS, Increase Contrast on Android):

- All glass tiers degrade to opaque equivalents (specs in `02-material-tiers.md`).
- 1 px borders gain 2× alpha to remain visible.
- Spotlight modifier becomes a 2-px solid accent border on the active element instead of a radial highlight.

The hierarchy is preserved by lightness step and explicit borders alone. No information is conveyed by transparency in any state.

## Voice Over (iOS) — exact behavior

VoiceOver hint and label conventions per primary surface:

| Element | VO label format |
|---|---|
| FloatingNav tab | "{Tab name}, tab, {selected/not selected}" |
| Conversation list cell | "{name}, {time}, {preview}, {n unread} — Actions available" |
| MessageBubble (own) | "Sent: {body}, {time}, {delivered/read}" |
| MessageBubble (theirs) | "{author}: {body}, {time}" |
| MessageBubble system event | "{event description}" |
| Reaction badge | "Reacted with {emoji} by {n}" |
| Typing indicator | "{name} is typing" — announced once, not looped |
| Trust state change | LiveRegion: "Encryption verified for {conversation}" / "Device key changed for {conversation}" |
| Story progress | "Story {i} of {n}, from {author}, {time remaining}" — announced on advance |
| Voice message | "Voice message from {author}, {duration}, tap to play. Long-press for transcript." |
| Active call participant tile | "{name}, video {on/off}, {muted/unmuted}, {speaking/silent}" |

Custom rotors are exposed where useful:
- "Rooms" rotor in chat list
- "Participants" rotor in active call
- "Story authors" rotor in stories rail

VoiceOver navigation order is the visual reading order in every screen. We do not let DOM structure override visual order.

## TalkBack (Android) — exact behavior

TalkBack uses the same Semantics tree as VoiceOver (Flutter unifies them). We additionally:
- Provide explicit `tooltip` properties for icon-only controls.
- Use `MergeSemantics` only where a multi-widget cell should announce as a single unit (e.g., name + time + preview in one cell).
- Use `BlockSemantics` only where Tier-3 modals present (so the focus is trapped and content below is excluded).
- Honor `MediaQuery.alwaysUse24HourFormat`.
- Honor `MediaQuery.platformBrightness` (we are dark-only at 1.0; we add a clear "Light theme is in development" affirmation in Settings).

Tested with TalkBack on Android 13 and Android 14.

## Switch Control / Switch Access

Every interactive element is reachable via single-switch and dual-switch protocols. Group navigation respects Z-tier (a modal at Z3 traps switch focus until dismissed). The conversation composer exposes a minimal switch-friendly mode (single-button "send" with text spoken via VO before sending).

## Voice Control / Voice Access

Every interactive element has a `Semantics(label)` that is also a sensible voice-navigation target. We avoid duplicates ("Send" never appears twice on screen at once); we use disambiguation ("Send message" vs "Send file") where collision exists.

## Focus order

- Visible focus order = visual reading order.
- Tab key on desktop traverses in this order; arrow keys move within composite controls (`SegmentedControl`, story progress, etc.).
- Focus *trap* on modals and bottom sheets at large detent.
- Focus *return* to the invoking element on dismissal.
- Initial focus on screen open: the first interactive element after the title (e.g., on Settings screen, focus is the first list row, not the title).

## Touch targets

Minimum **48 × 48** logical pixels for any interactive element. Visual size may be smaller; the hit region is enlarged invisibly.

We test this with the Flutter Accessibility Inspector and with platform-specific tools (Accessibility Inspector on Apple, Accessibility Scanner on Android) on every primary screen.

## RTL (right-to-left)

Arabic ships at 1.0. Every layout uses `TextDirection`-aware widgets (`Padding(EdgeInsetsDirectional)`, `Align(Alignment.centerStart)`, etc.). No `EdgeInsets.only(left: ...)` — only directional. CI lint flags non-directional usage.

Specific RTL adjustments:
- Conversation bubble chamfer mirrors (outgoing's chamfer is bottom-left in RTL).
- Story progress strip flows right-to-left.
- Floating nav stays in source order (it represents conceptually unordered tabs).
- Animations: `motion.lateral` mirrors direction (incoming from left in LTR, from right in RTL).

## Captions and transcripts

- Voice messages: on-device speech-to-text transcript available via long-press → Transcribe (Phase 8). Free.
- Video calls: live captions via on-device speech recognition (Phase 8).
- Stories with audio: optional caption track that the author can add.

## Hearing-related

- Visual alternatives to all audio cues. Call ringing has a screen pulse alternative (one full-screen ring at `motion.reveal`).
- Vibration alternatives configurable per-conversation.
- Volume-independent visual indicators (waveform, progress).

## Vestibular / motion sensitivity

- All parallax respects Reduce Motion.
- No infinite parallax loops at any scroll speed.
- Story progress doesn't auto-advance under Reduce Motion (manual tap only).

## Cognitive

- Settings are organized by purpose, not by feature. Every setting has a one-line plain description and a long-form description available via tap.
- Plain language in all microcopy. No idioms in default English; no untranslatable puns.
- "Are you sure?" confirmation appears for destructive actions and is dismiss-by-default.
- Time-sensitive interactions (call answer, voice record release) have a configurable extension under Accessibility settings.

## Testing

Every primary screen passes:
- **Automated.** Flutter `accessibility_test` package: minimum tap target, label coverage, contrast tokens.
- **Manual VoiceOver pass.** Per-screen, recorded, in CI as a play-back artifact.
- **Manual TalkBack pass.** Same.
- **Manual Switch Control pass.** Same, with a hardware switch.
- **Dynamic Type at 130/160/200%.**
- **Reduce Motion + Reduce Transparency** combination.
- **RTL** layout verification.
- **Color-blind simulation** verified for every accent + room-color combination.

These are CI-blocking. Phase 5 development is gated on accessibility tests passing per screen.

## Banned (accessibility)

- Color as the only signal.
- Animations longer than 500 ms (vestibular concern + cognitive load).
- Auto-playing video / audio outside the user's gesture.
- Time-limited interactions without an Accessibility settings extension.
- Custom controls without Semantics composition.
- AT focus that escapes a modal.
- Animations during scroll.
- Drag affordances without an alternative tap-or-key path.

## Statement (public)

We will publish an Accessibility Statement on `velix.app/accessibility` describing exactly what we support, what's in flight, and how to contact us with feedback. The statement is updated quarterly and is a 1.0-launch deliverable.
