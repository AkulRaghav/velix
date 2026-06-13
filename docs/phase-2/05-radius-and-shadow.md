# 05 — Radius & Shadow

These two systems carry most of what makes a UI feel cheap or expensive. We over-invest here.

## Radius

A 6-step scale. Each step has a defined use.

```
radius.xs    4    Hairline tags, small badges, segment-control internals
radius.sm    8    Compact inputs, chip rows, dense list cells
radius.md   12    Standard buttons, default inputs, dense cards
radius.lg   16    Cards, modals on small screens
radius.xl   20    Sheets, hero cards
radius.xxl  28    Bottom sheets at full open, splash card, profile hero
radius.pill 9999  Avatars, status pills, on/off toggles
```

### Rules

1. **Structural elements get smaller radii than ornamental ones.** A hero card holding a single image is more ornamental than a settings cell holding a row of controls; the hero card uses `radius.xl`, the settings cell uses `radius.md`.

2. **Radius compounds inwardly, never outwardly.** A child's outer radius must be ≤ its parent's inner radius. If a sheet has `radius.xxl` outer and 24 px internal padding, a card inside it has `radius.lg` (16) — anything more becomes a visual collision.

3. **Concentric radii.** When two surfaces nest tightly without padding (rare; usually only for split-button compositions), the inner radius equals the outer radius minus the wall thickness. We tag these explicitly in component contracts.

4. **Pill radius is for circular things.** Pill on a long button is a 2017 trend we are not bringing back. Buttons use `radius.md`. Tabs use `radius.sm`. Pills are reserved for things that are conceptually rounded (avatars, status dots, micro-toggles).

5. **No radius ≥ `radius.lg` on text-heavy surfaces.** A modal full of body text at `radius.xxl` reads as a balloon. The modal stays at `radius.lg` on small screens, `radius.xl` on large.

### Asymmetric radius

We use it once: bottom sheets. Only the top corners are rounded (`radius.xxl`); the bottom is square because it meets the screen edge.

Otherwise, asymmetric radius is forbidden. It reads as "creative" and breaks system rhythm.

## Shadow

The single biggest reason "futuristic startup UI" looks cheap is *decorative shadows*. A `box-shadow: 0 8px 32px rgba(0,0,0,0.5)` is a stage prop, not a light interaction.

We model shadow as **light**. Every floating element exists in a scene with a soft overhead light source. Shadow is the absence of that light blocked by the element. There are two layers:

### Layer 1 — Contact shadow

The hard, close shadow directly under an element. It tells the user the element is *resting on* something. Tight, dense, low spread.

### Layer 2 — Ambient shadow

The soft, far shadow that tells the user the element is *raised*. Wide, low intensity, large blur.

Real elements have both. UI elements that sit *on* the substrate have only contact. UI elements that *float above* have both.

## Tokens

```
shadow.contact
  offset:  0, 1
  blur:    1.5
  spread:  0
  color:   rgba(0, 0, 0, 0.32)

shadow.ambient.low
  offset:  0, 6
  blur:    16
  spread:  -4
  color:   rgba(0, 0, 0, 0.32)

shadow.ambient.med
  offset:  0, 12
  blur:    32
  spread:  -8
  color:   rgba(0, 0, 0, 0.40)

shadow.ambient.high
  offset:  0, 24
  blur:    64
  spread:  -16
  color:   rgba(0, 0, 0, 0.48)
```

### Composed presets

Real surfaces get **two-layer shadow**: one contact, one ambient. The presets bind them:

```
elevation.0    none
elevation.1    contact
elevation.2    contact + ambient.low
elevation.3    contact + ambient.med
elevation.4    contact + ambient.high
```

| Preset | Where used |
|---|---|
| 0 | Inline content, list cells, paragraphs |
| 1 | Quiet card resting on substrate |
| 2 | Floating navigation, hero card |
| 3 | Modal, popover |
| 4 | Bottom sheet at full open, full-screen overlay |

### Negative-space inset shadows

For buttons in pressed state and for inset components (search field, segmented control track), we use a **soft inset shadow**:

```
shadow.inset.soft
  offset:  0, 1
  blur:    2
  spread:  0
  color:   rgba(0, 0, 0, 0.24) inset
```

Applied when a component reports `pressed = true`, combined with a 1.5% lightness reduction on the surface fill.

## Glow (rare, restricted)

Glow is the cheapest shadow variant. It is allowed in exactly two contexts in Velix:

1. **Active call participant** — a 12 px glow at signature accent, 24% intensity, on the avatar of the participant currently speaking. Animated in/out via `motion.lift`.
2. **Voice-message recording** — a sub-pixel-shifting halo around the record button while recording, signature accent at 18% intensity. Driven by audio amplitude, not by time.

Outside these two cases, glow is **banned**. No glow on hover, no glow on idle, no glow on hero CTAs.

## Shadows under glass material

A Tier-2 or Tier-3 material has its **own** shadow system that differs from opaque elements:

- The contact shadow is reduced 30% (because glass is partly transparent and a hard contact reads as fake).
- The ambient shadow is intensified 15% (because glass elements need to read as obviously floating).
- A 1 px **inset highlight** is added at the top edge of the surface — not a shadow, but a near-white at 6–10% alpha — to imply a reflective bevel from the overhead light source.

This top-edge inset highlight is the most underused trick in glass-UI design. It is also what visually separates Apple's translucent material from imitations.

## Shadow under animation

Shadow scales with elevation during animation. A modal spring-presenting from `elevation.0` to `elevation.3` interpolates the shadow tokens, not the underlying primitives. We expose the interpolation as a Flutter `BoxShadow.lerp` chain in `theme.dart`.

We do **not** animate shadow blur for "breathing" effects. That is a banned pattern.

## Per-platform shadow rendering

| Platform | Implementation |
|---|---|
| iOS / macOS / Web (Impeller) | Native `BoxShadow` with `blurStyle: BlurStyle.outer`. Free. |
| Android (Skia legacy) | Two concrete `BoxShadow`s. Slight perf penalty (~0.3 ms per shadow). Acceptable. |
| Older Android (≤ 10) | Ambient shadow only; contact shadow is a 1px dark border at 30% alpha as a tasteful fallback. |

## Common mistakes (lint-flagged)

- A single ambient shadow without a contact shadow.
- A shadow with offset.x ≠ 0 (we shadow downward only — light is overhead).
- A shadow with the same blur and spread (loses the soft-edge falloff).
- A shadow on a surface that is also at Z-tier `substrate` (substrate elements don't float).
- A glow in any context outside the two listed.
- A shadow color that isn't `rgba(0,0,0,*)`. (Tinted shadows are reserved for the rare brand moment, in the splash only.)
