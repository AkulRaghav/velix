# 01 — Color Tokens

We work in **OKLCH** for all color math. OKLCH is perceptually uniform: equal Lightness numbers look equally bright; equal Chroma numbers look equally saturated, regardless of hue. Hex is provided for engineering reference only.

Dark-only at 1.0. Light theme is acknowledged as a v1.5 deliverable and the token names are designed to accept it without rename.

## Substrate philosophy

Velix's substrate is not pure `#000000`. Pure black on OLED creates two problems:
- Drop-shadow systems become invisible (nothing to shade against).
- Gradient transitions banding becomes unhide-able.

We use **graphite-true** substrate at OKLCH `L=0.07` with a hint of cool blue, then layer materials above it. True OLED black is preserved only for cinematic full-black moments (splash, story-viewer letterbox).

```
color.surface.void       OKLCH(0.00, 0,    0)      #000000   true OLED black, used sparingly
color.surface.substrate  OKLCH(0.07, 0.01, 250)    #08090C   primary background
color.surface.quiet      OKLCH(0.11, 0.012,250)    #11131A   inline cards, low-emphasis containers
color.surface.active     OKLCH(0.15, 0.014,250)    #1A1D27   floating bars, primary surfaces
color.surface.lifted     OKLCH(0.19, 0.016,250)    #24283A   modals, sheets, hovered surfaces
color.surface.scrim      OKLCH(0.05, 0,    0)/0.6  rgba(8,9,12,0.6) modal underlay
```

## Neutral text ramp

Built on the same hue, climbing in lightness with very low chroma to keep text neutral against any tinted material.

```
color.text.primary       OKLCH(0.97, 0.005, 250)  #F2F4FA   ≈ 95% — body and primary headings
color.text.secondary     OKLCH(0.78, 0.005, 250)  #B7BBC9   ≈ 72% — supporting copy
color.text.tertiary      OKLCH(0.62, 0.005, 250)  #898DA0   ≈ 55% — meta, timestamps
color.text.disabled      OKLCH(0.42, 0.005, 250)  #555967   placeholder, disabled
color.text.inverse       OKLCH(0.07, 0.005, 250)  #08090C   for accent-on-accent contexts only
```

**Contrast verification.** Every pairing is verified against WCAG 2.2 in `12-accessibility.md`. Body-on-substrate exceeds 16:1; body-on-lifted exceeds 12:1.

## Signature accent — locked

End of Phase 2: the signature accent is locked to **Quartz Blue**. The other two candidates (deep ultraviolet, warm aurora) considered during Phase 2 review have been retired from the codebase.

Quartz Blue reads as instrumentation: calm, technical, trustworthy. It survives glass filtering well, sits comfortably under photos and avatars, and stays comfortable on a 30-minute call. It is also the lowest OLED burn-in risk of the three candidates.

```
accent.s50    OKLCH(0.92, 0.04, 240)   #D4E0FF   subtle backgrounds, very-muted accents
accent.s40    OKLCH(0.78, 0.10, 240)   #93B5FF   muted application, disabled accents
accent.s30    OKLCH(0.62, 0.18, 240)   #3478F6   primary — buttons, focus rings, active states
accent.s20    OKLCH(0.48, 0.16, 240)   #1F58C8   pressed state
accent.s10    OKLCH(0.34, 0.13, 240)   #0F3A8E   deep — solid accent backgrounds
```

Convenience aliases:
- `accent.signature` → `accent.s30`
- `accent.signatureMuted` → `accent.s40`

The implementation in `theme.dart` is `Brand.quartzBlue` and there is currently no other variant. We will not add new variants without an explicit design review.

## Per-conversation accent palette

Beyond the signature, each conversation has a *room color*. The user can pick from twelve, or one is auto-derived from the contact identity hash (deterministic so two users see the same color for the same conversation).

These are tuned for use as ambient tints, not as hero colors. Chroma is intentionally low.

```
room.01 — Mist        OKLCH(0.68, 0.07, 220)  #8FB1D6
room.02 — Sage        OKLCH(0.70, 0.07, 150)  #92C2A5
room.03 — Linen       OKLCH(0.78, 0.06, 75)   #D7C898
room.04 — Coral       OKLCH(0.72, 0.10, 25)   #E89779
room.05 — Petal       OKLCH(0.74, 0.08, 350)  #DCA7B6
room.06 — Iris        OKLCH(0.62, 0.10, 290)  #9B83C0
room.07 — Pacific     OKLCH(0.55, 0.10, 230)  #4A7CA8
room.08 — Forest      OKLCH(0.50, 0.08, 145)  #4D8266
room.09 — Sand        OKLCH(0.65, 0.09, 60)   #B59B6A
room.10 — Ember       OKLCH(0.58, 0.13, 30)   #B96B43
room.11 — Plum        OKLCH(0.52, 0.10, 320)  #875E80
room.12 — Slate       OKLCH(0.55, 0.02, 260)  #7E818E
```

These are used at very low intensity — typically as a 6–12% tint mixed into Tier-2 active material, plus a slightly stronger 18–24% tint on the conversation's hero header.

## Semantic colors

Restrained. No emergency-room reds.

```
color.semantic.success   OKLCH(0.74, 0.12, 152)   #6FB58D
color.semantic.warning   OKLCH(0.78, 0.13, 80)    #DABA6E
color.semantic.danger    OKLCH(0.66, 0.16, 25)    #D86F5A
color.semantic.info      uses signature accent (no separate color)
```

Each of the three semantic colors has a `.muted` variant at L+0.04 / C×0.4 for backgrounds and a `.deep` variant at L−0.18 / C×0.85 for solid-fill cases.

**Use rules:**
- `success` is reserved for *completion of user-initiated action*. Never for "hello, the system is OK."
- `warning` is reserved for non-blocking caution. Never for marketing.
- `danger` is reserved for destructive confirmations and security-state regressions. Never for "you have unread messages."

## Trust tints

The system's most distinctive color move. Trust is communicated by a sub-perceptual tint shift on the conversation surface — readable on close inspection, *felt* without conscious awareness.

```
trust.verified.tint      OKLCH delta: ΔL=+0.00, ΔC=+0.02, ΔH=±0     — a subtle warming
trust.standard.tint      OKLCH delta: 0,0,0                          — no tint
trust.unverified.tint    OKLCH delta: ΔL=−0.02, ΔC=+0.01, ΔH=+250    — a subtle cooling
trust.rekeyed.tint       OKLCH delta: animated tremor on the surface — see motion grammar
```

The "tint" applies to the conversation header material and to the accent of the conversation, not to the message bubbles. Bubbles stay in the standard color ramp so quoted screenshots remain readable out of context.

## Status & presence

```
presence.online          uses semantic.success at 80% chroma
presence.recently        uses text.tertiary
presence.offline         no dot
typing.indicator         uses signature accent at 50% lightness, animated
```

## Gradients

We have **two**. That is the entire gradient inventory.

```
gradient.signature       linear from accent.30 → accent.10, 135°
                         used: launch animation, hero CTA in onboarding only

gradient.veil            linear from substrate (top) → substrate at 0% alpha (bottom)
                         used: above status bar to ensure legibility on bright media
```

That is all. Three-stop gradients, neon gradients, and rainbow gradients are banned across the system.

## Color audits performed

- WCAG 2.2 AA contrast verified against every text/background pairing in [`12-accessibility.md`](./12-accessibility.md).
- Color-blind simulation (Deuteranopia, Protanopia, Tritanopia) verified for the three accent candidates and all twelve room palettes against text and against each other.
- OLED burn-in risk assessed per accent candidate.
- Tint deltas for `trust.*` verified to be visible to >95% of the population while remaining sub-perceptual on first glance.
