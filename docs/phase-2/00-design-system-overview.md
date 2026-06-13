# 00 — Design System Overview

## Position

This is not a UI kit. It is a design system in the Apple/Linear/Vision-Pro sense: a small, opinionated set of primitives, materials, and rules from which every screen is composed. The system is the product of the constraint that **everything must remain coherent under a year of feature pressure**. If a feature cannot be expressed within the system, the system is reviewed before the feature is.

## Pillars

The seven pillars below are the reference for every design and code review.

1. **Restraint.** One signature accent. One body type. Three material tiers. Three places we use 3D. Three icon weights. If a value isn't in a token, it doesn't ship.
2. **Material before glyph.** Trust, focus, urgency, and hierarchy are carried by surface (blur, tint, lift), not by symbols. Glyphs reinforce, never lead.
3. **Motion is communication.** Every motion has a job — arrival, departure, lateral travel, Z-lift, Z-settle, parallax, or reveal. Motion without a job is removed.
4. **Calm by default, cinematic on arrival.** Repeated surfaces (chat list, settings) are quiet. First-encounter surfaces (onboarding, profile after edit, call connect) are cinematic. Frequency drives intensity, not the other way around.
5. **Trust is felt, not announced.** Verified contacts have a barely-perceptible warmer material. Re-keyed contacts have a barely-perceptible cooler one. The lock icon is a secondary signal, not the primary one.
6. **Accessibility is not an audit; it is the medium.** Reduce-Motion, Increase-Contrast, Dynamic Type, Voice-Over, TalkBack — the system is designed *into* these, not patched against them.
7. **The system is portable.** Every token is implemented in three places: this documentation, the Flutter `theme.dart`, and the Figma library reference. They are kept in lockstep.

## Token flow

Tokens cascade in this order. Higher tiers can read from lower; the reverse is forbidden.

```
  primitives    → color, radius, spacing, font, easing primitives
       ↓
  semantic      → "surface.lifted", "trust.verified", "text.primary"
       ↓
  material      → 4 named materials composed from semantic + primitive
       ↓
  components    → contracts that compose materials + semantics
       ↓
  screens       → composed of components, never reaching into primitives
```

A component never references a hex value. A screen never references a primitive token. Violation of this rule is a build-blocking lint.

## Naming convention

We use **dot-separated semantic paths** (not Tailwind-style mash):

```
color.surface.substrate
color.surface.quiet
color.surface.active
color.surface.lifted
color.text.primary
color.text.secondary
color.text.tertiary
color.text.disabled
color.accent.signature
color.accent.signature.muted
color.semantic.success
color.semantic.warning
color.semantic.danger
color.semantic.info
color.trust.verified
color.trust.unverified
color.trust.rekeyed
material.substrate
material.quiet
material.active
material.lifted
type.display.l
type.display.m
type.title.l
type.title.m
type.title.s
type.body.l
type.body.m
type.body.s
type.label.l
type.label.m
type.label.s
type.numeric.tabular
type.mono
space.2 / 4 / 6 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64 / 80
radius.xs / sm / md / lg / xl / xxl / pill
shadow.contact / ambient.low / ambient.med / ambient.high
motion.arrive / depart / lateral / lift / settle / parallax / reveal
z.substrate / nav / content / modal
```

In Dart, these become typed paths: `theme.color.surface.substrate`, `theme.material.lifted`, `theme.motion.arrive`.

## What this document does not contain

It does not contain values. Values live in their respective domain documents and in `theme.dart`. This document is the *map*; the territory is the rest of the folder.

## Versioning

The token system follows semver. Token additions are minor. Token removals or semantic-meaning changes are major. We pin major versions on apps (and bump them deliberately), so a Phase-2 design system can evolve safely while screens stay locked to a version.

We will start at `velix.design 1.0.0` once Phase 2 closes.

## Banned patterns (system-level)

These are forbidden across the system. Component-level bans are listed in `09-component-contracts.md` per component.

- More than one signature accent in a single screen.
- Glow halos on idle elements.
- Pulsing or breathing animations on idle elements.
- Loading spinners for operations < 200 ms.
- Decorative animations in surfaces opened > 5 times per day.
- Borders thicker than 1 logical pixel on glass materials.
- Stroked icons mixed with filled icons in a single surface.
- More than four Z-tiers on screen at once.
- Color used as the *only* differentiator for any meaning (accessibility constraint).
- Animation grammar invented per screen. Use the seven, or propose an eighth via formal review.
