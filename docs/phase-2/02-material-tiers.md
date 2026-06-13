# 02 — Material Tiers

The provided NexusChat reference described one glass material with one blur and one alpha. That is what made it look like every other "futuristic startup." Real spatial design has multiple **materials**: surfaces with distinct optical behavior, used at distinct depths, with distinct interaction grammars.

We define **four tiers** plus three modifiers.

## Tier model

| Tier | Name | Z (logical) | Primary use | Blur | Tint | Saturation modifier | Edge |
|---|---|---|---|---|---|---|---|
| 0 | **Substrate** | -1 | Backdrop, scene | none | `surface.substrate` opaque | 1.0 | none |
| 1 | **Quiet** | 0 | Inline containers, list cells | 0–8 px | `surface.quiet` 88% opaque | 1.0 | 1px @ `white 4%` |
| 2 | **Active** | 1 | Floating nav, hero card, search bar | 24 px | `surface.active` 62% | 1.15 | 1px @ `white 7%` + 1px inset @ `white 3%` (top edge only) |
| 3 | **Lifted** | 2 | Modal, bottom sheet, popovers | 40 px | `surface.lifted` 50% | 1.25 | 1px @ `white 9%` + 1px inset @ `white 5%` (top edge) + 1px inset @ `black 12%` (bottom edge) |

**Saturation modifier** boosts the chroma of color filtering through the material. This is what makes higher-tier glass *feel* glassier — it amplifies the colors behind it slightly (the way real glass does via internal reflection) rather than just blurring them.

**Edge treatments** matter as much as the fill. The 1px inset top-edge highlight at higher tiers is what separates "Apple's translucent material" from "every Bootstrap glass card on Dribbble." It implies a beveled reflection of the light source.

## Modifiers

Modifiers compose with any tier. They never replace it.

### `material.modifier.tint`

Applies a 6–12% color wash through the material, post-blur. Used for:
- Per-conversation room color
- Trust state warmth/cool
- Notification severity (rare)

The tint blends in HSL space using a soft-light blend, not a straight overlay, so it never crushes the content under the material.

### `material.modifier.tremor`

Spatial-time modifier. Adds a sub-pixel surface displacement at 0.5 Hz with amplitude 0.3 px. Used exclusively for the `trust.rekeyed` state. The user does not consciously see it; they feel that something is wrong.

### `material.modifier.spotlight`

A single soft radial highlight at a specified anchor point on the surface. Used:
- On the active tab in the floating nav
- On the focused message bubble during a Tapback gesture
- On the active call participant tile

Spotlight is a 1.5× luminance multiplier in a 120 px radius, falling off via cubic ease.

## Per-platform behavior

### iOS / macOS
We use `BackdropFilter` with `ImageFilter.blur(sigmaX, sigmaY)`. Real-time blur is cheap on Metal/Impeller. On iPhone 12 and newer, even Tier-3 blur during animation is essentially free.

### Android
Real-time blur is acceptable on Android 12+ via `RenderEffect`. On older Android (10, 11), we cache a snapshot blur and re-blur only when the underlying scene changes, with a 250ms debounce. This sacrifices some live-blur fidelity for frame stability.

### Web (PWA)
`backdrop-filter: blur()` with the `Saturate()` filter chained. Tier-3 falls back to a static frosted background on browsers without backdrop-filter (Firefox-on-Linux mostly).

## Layering rules

1. **No more than two glass tiers on screen above substrate.** Tier-1 and Tier-2 may coexist. Tier-3 lives alone at its Z; everything below it is suppressed during its presence.
2. **No glass-on-glass with the same tier.** Two Tier-2 surfaces cannot stack. The one beneath would be visually invalid because it would blur a blur.
3. **Glass over photo content downsamples the photo to 60% saturation, post-blur.** Otherwise the bright underlying image overwhelms the glass tint and the surface ceases to read as a surface.
4. **Glass material respects safe-area insets implicitly.** The blur extends to the screen edge but the visible surface tint stops at the safe-area boundary, so the status-bar region remains readable.

## Glass-substitute degraded mode

If the device is in **Increase Contrast** mode, **Reduce Transparency** mode, or in low-power mode with `MediaQuery.of(context).disableAnimations`, glass materials degrade to opaque equivalents:

| Tier | Degraded fallback |
|---|---|
| Quiet | `surface.quiet` opaque, 1 px border at `white 8%` |
| Active | `surface.active` opaque, 1 px border at `white 12%` |
| Lifted | `surface.lifted` opaque, 1 px border at `white 16%` |

Degraded mode is **fully equivalent in usability**. Hierarchy is preserved by lightness step alone, no information is conveyed by transparency alone.

## Content readability rules

For text **on** a glass material:
- Tier 1: any text size ≥ 12pt at `text.primary`. Tier-1 is opaque enough that this is safe.
- Tier 2: any text size ≥ 13pt at `text.primary`. For text < 13pt, drop to Tier 1.
- Tier 3: minimum 14pt for body text. We do not display 12pt captions on lifted modals.

For text **near** glass material edges, we add a 12 px inset between the edge and any text. The edge is a lighting interface; text crowding it makes the material look thin.

## Trust-state material variants

Each tier has three pre-composed variants for the active conversation surface:

```
material.active.trust.verified     +0.02 chroma (warmer)
material.active.trust.standard     baseline
material.active.trust.unverified   −0.02 lightness, +0.01 chroma toward 250° (cooler)
```

These are intentionally just below the threshold of conscious detection in casual viewing. The user's eye notices "something is different" without yet asking what.

## Performance budget per tier

| Tier | Render cost (frame, on iPhone 13) | Limit per screen |
|---|---|---|
| Substrate | 0.05 ms | always present |
| Quiet | 0.4 ms | up to 6 simultaneous |
| Active | 1.2 ms | up to 2 simultaneous |
| Lifted | 2.5 ms | exactly 1 simultaneous |

Total material budget per frame: **5 ms**. This leaves a comfortable 11.6 ms for everything else inside the 16.6 ms 60-fps budget.

## Common mistakes (we will catch in code review)

- Tier-3 used for an inline card. (Use Tier-1.)
- Tier-1 used for a modal. (Use Tier-3.)
- Glass over a glass without an opaque buffer between them.
- Glass surface with a contrasting border heavier than 1 logical px.
- Blur radius animated during scroll. (Cache the blur; pan the cache.)
- Tier-3 covering less than 60% of the screen. (Sub-page modals should be presented as Tier-2 popovers.)
- Trust tint applied at higher than 12% intensity (the effect should be felt, not seen).
