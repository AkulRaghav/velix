# 06 — Accessibility Statement (Draft)

> **Status:** Draft. Awaits accessibility consultant review.
>
> **Will be published at:** `velix.app/accessibility`
>
> **Length:** Target 3–5 pages.
>
> **Audience:** Users with disabilities, accessibility advocates, regulators (Section 508, EN 301 549).

---

# Velix Accessibility

## Our commitment

Velix is built so that everyone can use it. Accessibility is not an audit pass we tack on at the end; it is the medium through which the design system is built.

Specifically:

- We meet **WCAG 2.2 AA** for every primary flow.
- We exceed AA — reaching AAA — for body text against the substrate, because of our color choices.
- We support every assistive technology that ships with the operating systems we target.
- We treat accessibility issues as production bugs.

This document describes what works today, what is in flight, and how to reach us if something does not work for you.

## What we support today

### Screen readers

- **VoiceOver** (iOS, macOS): Every interactive element is labeled. Reading order matches visual order. Custom rotors are exposed for "Rooms" (in chat list) and "Participants" (in active calls). LiveRegion announcements for trust-state changes, AI streaming completions, and incoming notifications.
- **TalkBack** (Android): Same Semantics tree as VoiceOver via Flutter's unified accessibility surface. Explicit `tooltip` properties for icon-only controls. Focus traps on modals and bottom sheets.

### Switch Control / Switch Access

Every interactive element is reachable via single-switch and dual-switch protocols. Group navigation respects our Z-tier system: a modal at the top tier traps switch focus until dismissed. Custom Semantics actions are exposed for swipe-only operations (archive, react, dismiss-story) so switch users can complete the same actions without performing a swipe.

### Voice Control / Voice Access

Every interactive element has a unique, voice-friendly label. We avoid duplicate labels on the same screen. Where collision could occur (two "Send" buttons, for example), we disambiguate with context-specific labels ("Send message" vs "Send file").

### Dynamic Type / Font Scale

We support iOS Dynamic Type up to **AX5** (200% scale) and Android font scale up to 200%. Body text scales 1:1; display text caps at 150% to avoid horizontal truncation; label text wraps to two lines rather than truncates. Layouts re-flow vertically; nothing is clipped without an accessible expansion.

### Reduce Motion

When the operating system reports Reduce Motion, every animation in Velix's seven-pattern motion grammar collapses to a 120 ms cross-fade. Layout pre-state and post-state remain identical; only the transit changes. Parallax (tilt and scroll) is disabled. The 3D scenes used in onboarding and profile become single static frames; the visual composition is preserved.

### Reduce Transparency / Increase Contrast

When the operating system reports Reduce Transparency or Increase Contrast, glass materials degrade to opaque equivalents. Borders gain stronger alpha to remain visible. The trust-state material tints (which carry meaning sub-perceptually) are supplemented with explicit textual indicators so the meaning is preserved without depending on translucency.

### Color contrast

Every text-on-surface pairing meets WCAG 2.2 AA. Most exceed AAA. We verified the contrast in advance against:
- Body text on every material tier.
- Button text on every accent-color step.
- Status text in semantic colors (success, warning, danger).
- Trust-state surfaces against text.

The full contrast table is published at `velix.app/accessibility/contrast`.

### Color is never the only signal

Every state that has a color also has a non-color signal:
- Active tabs: weight + scale + spotlight, in addition to accent color.
- Pressed buttons: scale change + inset shadow, in addition to color shift.
- Error inputs: shake animation + helper text + icon, in addition to color.
- Online presence: an inset notch shape, in addition to color.
- Verified contacts: warm material + custom shield glyph + textual "Verified" label, in addition to subtle hue shift.
- Re-keyed contacts: cool material + glyph state + sustained tremor + LiveRegion announcement.

Users who cannot perceive color differences receive the same information through other channels.

### Touch targets

Every interactive element has a hit region of at least **48 × 48 logical pixels**, regardless of its visual size. A 32-pixel avatar, for example, has a 48-pixel hit region extending invisibly beyond its visible boundary.

### Right-to-left languages

Arabic ships at 1.0 with full RTL support. Layouts mirror correctly. Animations mirror direction (page push slides from the right in RTL contexts). Story progress flows right-to-left.

Other RTL languages (Hebrew, Persian) are tested but not in launch locales; we welcome reports if mirroring is incomplete in any RTL context.

### Captions

Voice messages can be transcribed on-device by long-pressing the message and selecting Transcribe. Live captions on calls are available in supported locales (English at 1.0; more languages in subsequent releases) — the captions are generated on your device and never sent to our servers.

### Configurable gesture thresholds

Some users find default gesture thresholds difficult. In Settings → Accessibility → Gestures, you can adjust:

- Long-press threshold: 320 / 500 / 750 / 1000 milliseconds.
- Tap cancellation distance: 16 / 24 / 36 / 48 pixels.
- Pull-to-refresh threshold: 60 / 80 / 120 pixels.
- Swipe-to-archive threshold: 48 / 64 / 96 pixels.
- Edge-swipe-back threshold: 30% / 40% / 50% screen width.

Each adjustment takes effect immediately and applies across the app.

### Vestibular sensitivity

Beyond Reduce Motion (which removes parallax and bounce), we cap bounce overshoot at 8% across the system, well below thresholds known to trigger vestibular discomfort. No animation auto-replays without a gesture. The 3D system's drift is slow (18–48 second cycles) and bounded in amplitude.

### Photosensitivity

No animation produces global luminance changes greater than 30% within 200 milliseconds. Our asset pipeline rejects 3D scenes that violate this. We have no flashing or strobing imagery in the application.

### Cognitive load

Settings are organized by purpose, not by feature. Every setting has a one-line plain description and a long-form description available via tap. Microcopy uses plain language; we do not use idioms or untranslatable puns. Time-sensitive interactions (call answer, voice record release) have configurable extensions in Accessibility settings.

### Hearing-related

Visual alternatives exist for every audio cue. Call ringing has an accompanying screen-pulse animation. Vibration alternatives are configurable per-conversation. Volume-independent visual indicators (waveform, progress) are present where audio is involved.

## Testing

Every primary screen passes:
- Automated accessibility checks in our continuous integration.
- Manual VoiceOver pass per release.
- Manual TalkBack pass per release.
- Manual Switch Control pass with hardware switch.
- Verification at Dynamic Type 130%, 160%, and 200%.
- Reduce Motion + Reduce Transparency combined.
- RTL layout verification.
- Color-blind simulation for every accent and per-conversation room palette.

Annual review is performed by an external accessibility consultant. The first review's results will be published at `velix.app/accessibility/audits/[date]`.

## What is in flight

The following accessibility work is scheduled but not in 1.0:
- Additional caption languages beyond launch locales.
- Decoy / panic mode for users in coercive situations (vestibular and cognitive review pending).
- Customizable color palettes beyond the twelve provided room colors.
- Specialized large-text mode beyond Dynamic Type AX5.

## How to reach us

- Accessibility issues: `accessibility@velix.app`. We respond within 7 days; production bugs are triaged within 48 hours.
- General feedback: `support@velix.app`.

If a specific assistive technology does not work for you, please tell us. Our test matrix covers the most common configurations; we may not have covered yours, and we want to.

## What we will never do

- Treat accessibility as a feature to be unlocked.
- Charge for accessibility settings.
- Disable assistive technology compatibility "for security" — every security feature has an AT-compatible path.
- Ship features without accessibility review.
- Ignore accessibility bug reports.

Every release blocks on its accessibility tests passing. A regression in screen-reader compatibility is treated with the same urgency as a regression in encryption.

---

> **End of accessibility statement.**
>
> Reviewer notes: this draft commits Velix to WCAG 2.2 AA for primary flows, with AAA where naturally achieved, and to specific assistive technology behaviors. The accessibility consultant should verify (a) every claim is implementable today, (b) the configurable thresholds in Settings → Accessibility match what we actually expose, (c) the "what is in flight" section is honest about where we are vs where we are going. Note that this statement should be re-published with audit results once the first external accessibility audit completes.
