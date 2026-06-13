# 10 — Design Evolution Direction

This document is a directive for Phase 2. It diagnoses what is wrong with the uploaded NexusChat design (and the whole genre of "futuristic startup messenger" UIs it represents), and sets a concrete bar for the Apple-grade visual system we will build.

## What the uploaded design got right

The NexusChat reference established a few decisions we keep:
- Pure-black backgrounds as the substrate
- Glassmorphism as a primary surface treatment
- A purple-blue-cyan accent family
- Component-based architecture with reusable primitives
- 15-screen IA that maps cleanly to our roadmap

These are competent choices for a 2024 futuristic startup template. They are not yet a world-class product.

## What the uploaded design got wrong

Honest diagnosis. Each of these is a known anti-pattern in the "futuristic SaaS" genre.

### 1. Generic gradient overload
The provided palette uses indigo, purple, and cyan simultaneously across `--gradient-primary`, `--gradient-secondary`, `--gradient-neon`. Three competing gradients in one product is visual noise. Apple's color discipline is the opposite: one signature, applied with restraint.

**Fix.** One signature gradient. Two muted accent neutrals. Full stop.

### 2. Glassmorphism applied uniformly, not hierarchically
`--glass-bg: rgba(18, 18, 27, 0.4)` and a single `--glass-blur: 20px` describe one glass material. Real spatial design has *materials*, plural — surfaces at different depths with different translucency, blur, and tint behavior depending on what's behind them.

**Fix.** A four-tier material system. We define them in Phase 2. Each material has different blur, saturation, lightness response, and shadow.

### 3. Neon abuse
`--neon-purple`, `--neon-blue`, `--neon-cyan`, `--neon-pink` simultaneously is exactly the "cyberpunk cliché" the master prompt warned against. Real cinematic UI (Vision Pro, Linear, Arc) uses neon **once or twice** in a screen — to draw the eye to a single high-meaning element.

**Fix.** Reserve our signature accent for *one* purpose per screen, typically the active state of a single primary action. Replace incidental neon with **luminance changes** — making something brighter, not coloring it differently.

### 4. Border radius inflation
`rounded-2xl` and `rounded-3xl` everywhere produces a soft, candy aesthetic. Apple's bar is more disciplined: corner radii follow a Fibonacci-like progression tied to component scale, and structural elements have *less* radius than incidental ones.

**Fix.** A 6-step radius scale (4, 8, 12, 16, 24, 32 px) where each tier has a defined use. No `2xl` everywhere.

### 5. Spacing without rhythm
The provided tokens use Tailwind defaults without a documented vertical rhythm. The result feels visually flat.

**Fix.** A spacing scale tied to a baseline grid (4px increments, with 8/16/24/32/48/64 as primary stops). Vertical rhythm enforced via line-heights that align to this grid.

### 6. Shadow as decoration, not depth
Generic `shadow-xl`-style tokens render as dark fuzz under elements. They imply depth without behaving like depth. Vision Pro's shadows are **environmental** — they respond to where the surface sits in the scene.

**Fix.** Two shadow systems. (1) Ambient shadow for floating elements, with realistic light-source modeling. (2) Contact shadow for elements pressed against the substrate. Both are layered; both adapt to material tier.

### 7. Typography without optical care
Default Tailwind type scale, no optical-size handling, no tabular numerals for chat timestamps, no consideration of how text behaves at small sizes against varying backgrounds.

**Fix.** A typography system using **Inter Display** (or Inter optical variant) for headings, **Inter** for body, **JetBrains Mono** for technical surfaces (cryptographic identifiers, version strings). Tabular numerals enforced for timestamps and counts. Optical sizing via `font-variation-settings` where supported.

### 8. Motion is missing or generic
The reference describes "smooth animations" without specifying physics, easing, or grammar. Apple's motion has **rules**: presentations spring up, dismissals decelerate down, navigation slides horizontally, modal overlays cross-fade with a slight scale. Each pattern is consistent.

**Fix.** A motion grammar of seven patterns, fully specified in Phase 4, each with cubic-bezier coefficients or spring constants.

### 9. The encryption signal is a lock icon
A literal lock-icon glyph is the laziest way to communicate trust. Vision Pro communicates state through *material*. Linear communicates state through *typography weight and spacing*.

**Fix.** Trust state changes the ambient material of the conversation surface, not just an icon. Verified contacts get a subtle warmer-tinted material. Unverified or freshly-rekeyed contacts get a barely-colder one. The lock icon stays, but it's the secondary signal.

### 10. No spatial sensibility
The reference is flat by accident — every surface lives at the same Z. Vision Pro and visionOS are explicitly spatial.

**Fix.** A four-tier Z-system: substrate (the background scene), navigation (floating bar), content (cards and bubbles), modals (lifted surfaces). Each tier has its own elevation, blur depth, and shadow behavior. Transitions are **between Z-tiers**, not just lateral.

## The Apple/Vision Pro bar (concrete targets)

| Property | Phase 2 target |
|---|---|
| Color signature | One signature accent. We will choose it in Phase 2 from a curated set including a deep ultraviolet (`#5B3DF5` family), a quartz blue (`#3478F6` family), or a warm aurora (`#FF6A6A` family). |
| Material tiers | 4: substrate, low-translucent, medium-translucent, high-translucent. Each with documented blur, saturation, and tint behavior. |
| Typography | Inter / Inter Display, with optical sizing, tabular numerals, language-specific kerning. |
| Spacing | 4px baseline grid; primary stops 8/16/24/32/48/64. |
| Radius | 6-step scale (4/8/12/16/24/32). Structural radii smaller than ornamental. |
| Shadow | Two-layer (ambient + contact), with light-source modeling. |
| Motion | 7-pattern grammar with explicit easing curves and spring constants. |
| Z-tiers | 4 explicit tiers with cross-tier transition rules. |
| Trust signaling | Material-borne, not glyph-borne. |
| 3D | 3 surfaces only: onboarding spatial scene, profile identity scene, optional ambient backdrop per Space. |

## Banned patterns (Phase 2+)

- Multiple competing accent colors on one screen
- Borders thicker than 1 px on rounded glass surfaces
- `rounded-2xl` or larger on structural elements (only ornamental ones)
- Glow halos around buttons unless triggered by explicit action
- Pulsing or breathing animations on idle elements
- Loading spinners as the primary feedback for any operation that completes in < 200 ms
- Fake "scanning" or "encrypting" animations as decoration. We do not lie about what the system is doing.
- Stock UI icons used unmodified (we design or curate every icon to match our metric).
- More than 5% of pixels at any single hue value in a screen
- Animation purely for delight in surfaces that are visited > 5 times/day. (Animation in repeated surfaces becomes friction.)

## "Calm + cinematic" applied

| Surface | Calm posture | Cinematic moments |
|---|---|---|
| Chat list | Quiet. No animations on idle. | Pull-to-refresh has a single elegant spring. |
| Conversation | Quiet. Bubbles arrive with a brief, decisive scale. | First-message-sent ever has a subtle ambient shimmer. |
| Onboarding | Cinematic. This is a hero moment. | Every step. |
| Settings | Quiet. Like Linear's settings. | None. |
| Story viewer | Cinematic. Vertical immersive. | Every transition. |
| Voice / video call | Calm by default. Cinematic on call connect / disconnect. | Connect: scene materializes. Disconnect: scene dissolves. |
| Profile | Cinematic on first view post-edit. Quiet on subsequent. | Identity scene with a single subtle 3D element. |
| Notifications | Always quiet. | Never cinematic. |
| AI assistant | Quiet by default. | Streaming response has a subtle attention indicator. |

## Output of Phase 2

When Phase 2 finishes, this directive is realized as:

1. `docs/phase-2/00-design-system-overview.md`
2. `docs/phase-2/01-color-tokens.md` (signature, neutrals, semantic, with hex, OKLCH, and rationale)
3. `docs/phase-2/02-material-tiers.md` (4 tiers, full specs)
4. `docs/phase-2/03-typography.md` (full type ramp, optical sizing, language coverage)
5. `docs/phase-2/04-spacing-and-grid.md` (baseline, scale, vertical rhythm)
6. `docs/phase-2/05-radius-and-shadow.md`
7. `docs/phase-2/06-iconography.md` (system, weights, set inventory)
8. `docs/phase-2/07-motion-grammar.md` (7 patterns, specified)
9. `docs/phase-2/08-z-tiers.md`
10. `docs/phase-2/09-component-contracts.md` (every primitive: states, sizes, materials)
11. `docs/phase-2/10-screen-blueprints/` (one file per primary screen)
12. A reference Flutter `theme.dart` implementing the full token set

## Audit hook

When Phase 2 concludes, we will run a checklist verifying that **every banned pattern in this document** is absent, and **every concrete target above** is met. Phase 2 cannot ship until that audit clears.
