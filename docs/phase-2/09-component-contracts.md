# 09 — Component Contracts

A **contract** for each primitive: required states, sizes, materials, motion, accessibility, banned patterns. Each component listed here will be implemented in `packages/velix_design/lib/components/` in Phase 5 (and previewed via Storybook-equivalent earlier).

A contract is binding. A component that violates its contract is a build failure.

---

## Button

A primary action surface. There are four button variants. We do not have more.

### Variants

| Variant | Use | Surface | Text |
|---|---|---|---|
| `primary` | Single dominant action per screen | `accent.signature.30` solid | `text.inverse` (auto-derived light/dark for legibility) |
| `secondary` | Affirmative non-dominant action | Tier-2 active material | `text.primary` |
| `tertiary` | Inline / contextual action | transparent, no border | `accent.signature.30` |
| `destructive` | Destructive confirm | `semantic.danger` solid | `text.inverse` |

### Sizes

| Size | Height | Horizontal padding | Type |
|---|---|---|---|
| `sm` | 36 | 16 | `type.label.m` |
| `md` (default) | 48 | 20 | `type.label.l` |
| `lg` | 56 | 24 | `type.label.l` |

### States

`enabled · pressed · disabled · loading`. Each is required.

| State | Visual change |
|---|---|
| pressed | -1.5% lightness on fill, `shadow.inset.soft` overlay, scale → 0.97 (spring 0.8/0.4) |
| disabled | opacity 0.4, no shadow, no press response |
| loading | label hides, `Loader.spinner.sm` centers in place; min-width preserved so the button doesn't shift |

### Motion

- Press / release: `motion.lift` partial (scale only, no Z change)
- State swap (e.g., enabled → loading): `motion.reveal`

### Accessibility

- Minimum hit-target 48 × 48 logical px regardless of visual size.
- Always rendered as `Semantics(button: true, label: ...)`.
- `enabled: false` mapped to `Semantics(enabled: false)` so screen readers announce "dimmed."
- Loading state: `Semantics(label: "{label}, loading")`.
- Color is never the sole differentiator of state.

### Banned

- Outlined buttons (we don't use them; they read as web-y).
- Buttons with a 1-px border + a fill (the border + fill combination is a tell of design weakness).
- Buttons with leading + trailing icon + label all simultaneously (pick at most leading + label, or icon-only).
- Pill-rounded long buttons.
- "Glow" on hover.

---

## Input (text field)

A glass input that respects materials and supports a wide range of compositions.

### Anatomy

```
[ leading-icon? | placeholder / value | trailing-icon? | clear-affordance? ]
```

### Sizes

| Size | Height | Type | Use |
|---|---|---|---|
| `sm` | 40 | `type.body.m` | Inline filters |
| `md` (default) | 48 | `type.body.l` | Forms, search |
| `lg` | 56 | `type.body.l` | Hero search, login |

### Surface

- Material Tier 1 (quiet glass) on dark surfaces; opaque on Tier-3 surfaces.
- Border: 1 px at `white 6%`. On focus: `accent.signature.30` at 1 px outer ring + faint 4-px aura at 18% alpha.
- Radius: `radius.md` for `sm/md`, `radius.lg` for `lg`.

### States

`empty · focused · filled · error · disabled · loading`

- **error** turns the bottom 1 px border to `semantic.danger`, adds a one-line `body.s` helper text below in `semantic.danger`. No red fill.
- **loading** shows a 20-px `Loader.spinner.xs` in the trailing-icon slot.

### Motion

- Placeholder → label transition (Material-style "shrink" pattern): `motion.reveal`, 200 ms.
- Focus ring: `motion.reveal`, 180 ms.
- Error appearance: `motion.arrive` (subtle 4-px shake permitted exactly once on initial error display, never on retry).

### Accessibility

- Connected `Semantics(label, hint, value, focused)`.
- Error helper text linked via `LiveRegion` so AT announces the error.
- Clear button has its own `Semantics(button: true, label: "Clear")`.
- Numeric, email, password use the appropriate `keyboardType` and `obscureText`.
- Password input always has a visibility toggle (eye icon).

### Banned

- Underline-only inputs without a containing surface (web pattern).
- Auto-correct on cryptographic identifier fields.
- Placeholder text used as the only label.

---

## GlassCard

A card surface using one of the three glass tiers. **The most overused component in the genre, and the one we are most disciplined about.**

### Variants

| Variant | Tier | Use |
|---|---|---|
| `quiet` | Tier-1 | Inline cards, settings groups, list-cell containers |
| `active` | Tier-2 | Hero cards, highlighted content |
| `lifted` | Tier-3 | (do not use directly; use `Modal` or `BottomSheet`) |

### Anatomy

```
[ optional header | content | optional footer ]
```

### Padding

`space.inset.lg` (16) by default; configurable to `space.inset.xl` (24) for hero cards.

### Radius

`radius.lg` for default; `radius.xl` for hero card; `radius.md` for compact cards.

### Motion

Cards do not have built-in motion. Their parent (a list, a screen) drives `motion.arrive` on first appearance.

### Banned

- Decorative shadows beyond the elevation token assigned to the tier.
- A glass card directly on top of another glass card.
- Cards with a colored accent stripe along an edge (web pattern).
- Cards with a border > 1 px.

---

## MessageBubble

The most-used surface in the application. Built for typographic legibility, trust signaling, and reaction affordance.

### Variants

| Variant | When |
|---|---|
| `outgoing` | Messages from self |
| `incoming` | Messages from others |
| `system` | Encryption events, "you joined", "you left" |
| `compact` | Reactions only, no body |

### Surface

- **outgoing**: filled with `accent.signature.30` at 92% alpha, `text.inverse` body text. Radius: `radius.lg` with a 4 px chamfer at the bottom-right corner (the "tail" — implicit, no glyph).
- **incoming**: Tier-1 quiet material with 6% conversation-room-color tint, `text.primary` body. Radius: `radius.lg` with 4 px chamfer at bottom-left.
- **system**: no surface fill, centered single line at `body.s` and `text.tertiary`.
- **compact**: pill-shaped reaction cluster, no body bubble.

### Anatomy

```
[ author? (group only) | content | timestamp + delivery state ]
[ reactions row?       | reply context?                        ]
```

### Trust state

A bubble inherits the conversation's trust state. The bubble itself does not carry a glyph; the conversation header does. Bubbles never have a lock icon.

### Motion

- Insert (sent): `motion.arrive` with translation 12 px from below + scale 0.96 → 1.00, 280 ms (subtle, not flashy).
- Insert (received): `motion.arrive` with translation 12 px from below, no scale (slightly less attention-getting).
- Long-press: `motion.lift` to Z2.5, reveal `ReactionPicker` (Z3 popover above the bubble).
- Tapback: spotlight reveal on the bubble + `motion.arrive` of the reaction badge.

### Reactions

Six default emoji + custom (paid feature). Reactions are E2E encrypted. Reaction cluster appears below-left of the message at `radius.pill`, Tier-1 material, with each reaction as a 24 × 24 cell + count.

### Accessibility

- Each bubble is a `Semantics` node with full message text + author + time + delivery state read in order.
- Reactions announced as "reacted with [emoji] by [n] people" or "you reacted with [emoji]."
- Long-press exposed as a custom action ("React, Reply, Copy, Forward").
- Trust-state changes announced via `LiveRegion` once per change ("encryption verified," "device changed").

### Banned

- Read-receipt ticks visible on incoming messages (only outgoing).
- Animated emoji or stickers in the reaction picker (only on send-then-rest).
- Bubbles with internal shadows.
- Bubbles with a border (the surface fill is the boundary).
- Tail glyphs as separate SVG decorations (the chamfer is the implicit tail).

---

## Toggle

A binary switch.

### Anatomy

A pill-shaped 51 × 31 track with a 27 × 27 thumb.

### States

| State | Track | Thumb |
|---|---|---|
| off | `surface.quiet` 80% | `text.primary` 90% |
| on | `accent.signature.30` | `text.inverse` |
| on (verified-paired surface) | `accent.signature.30` with subtle warmth tint | `text.inverse` |
| disabled | track at 40% alpha, no interaction | thumb at 40% |

### Motion

- Thumb travels via `motion.lift` (240 ms spring).
- Track color cross-fades during travel; not a hard switch.
- Press provides 0.5 px thumb compress (depth feel).

### Accessibility

- `Semantics(toggled: bool, label, hint)` mapped automatically.
- AT announces "on" or "off."
- Tap area extends to 48 × 48.
- Custom on/off labels can be provided per instance for context (e.g., "Read receipts on/off").

### Banned

- Toggles with a center label inside the track (a Material 1 anti-pattern).
- Toggles wider than the standard track (use a SegmentedControl instead).
- Color-only differentiation between on/off (track lightness must also differ; see accessibility doc).

---

## Loader

We have **two** loaders. We never invent a third.

### `Loader.spinner`

A circular, anchored, deliberate spinner. Used inline (in buttons, in trailing input slots, in async list cells).

- Sizes: `xs (16) · sm (20) · md (28)`
- Stroke: 2 px
- Color: `accent.signature.30` for primary, `text.tertiary` for inline neutral
- Motion: 1 rev / 1.4 s, ease-in-out, no segment animation (just a clean circular ring with one quarter brighter)

### `Loader.pulse`

A skeleton-shimmer for content placeholders. Used for chat list initial load, profile load.

- Surface: Tier-1 quiet
- Animation: a 24% lightness band sweeping at 1.6 s linear
- Reduce-Motion: degrades to a static surface at the bright end (no sweep)

### Banned

- Spinners as primary feedback for operations < 200 ms (the loader appears mid-operation in that case and looks broken).
- Multi-segment "spinner" animations (loading dots, bouncing balls, etc.). Banned.
- Indeterminate-progress bars across the top of screens.

---

## Modal

A Tier-3 surface presenting over content. Used for confirmations, identity-add flows, settings-step overlays.

### Anatomy

```
[ scrim ]
  [ surface ]
    [ optional title (type.title.m) ]
    [ content ]
    [ optional footer with primary+secondary actions ]
```

### Surface

- Material: Tier-3 lifted
- Radius: `radius.lg` on small screens; `radius.xl` on large
- Width: max 480 logical px on tablet+; full-bleed minus 24 px inset on phone
- Shadow: `elevation.3`

### Motion

- Open: `motion.arrive`
- Close: `motion.depart`
- Backdrop dim: substrate gains 8 px additional blur, scrim fades to 60% alpha

### Dismissal

- Tap scrim to dismiss (default)
- Drag handle absent — modals are not draggable; bottom sheets are.
- Escape key (desktop)

### Accessibility

- Focus is trapped within the modal until dismissed.
- The backing content has `Semantics(excludeSemantics: true)` while the modal is presented.
- The first focusable element in the modal receives focus on present.
- Escape and dismiss have explicit gestures.

### Banned

- Modals on top of modals (except the deliberate alert-on-sheet pattern noted in `08-z-tiers.md`).
- Modals with a "Don't show this again" checkbox (we don't lazily pile UX pressure on the user).
- Promotional modals on app open.

---

## BottomSheet

A draggable Tier-3 surface that rises from the bottom edge. Used for share, quick settings, conversation-info, and AI assistant invocation.

### Detents

A bottom sheet snaps to detents:

| Detent | Height (of viewport) |
|---|---|
| `medium` | 50% |
| `large` | 88% |
| `dismissed` | 0 |

A sheet may declare `[medium, large]` or `[large]` only. If both, the user can drag between them.

### Anatomy

```
[ drag-handle (4 × 36 px, top center, surface.lifted text-tertiary) ]
[ optional title (type.title.m) ]
[ content (scrollable inside) ]
[ optional footer with primary action ]
```

### Surface

- Material: Tier-3 lifted
- Radius: `radius.xxl` top corners only, square bottom (meets screen edge)
- Shadow: `elevation.4`

### Motion

- Present: gesture-driven up to detent, then `motion.arrive` with velocity carry from gesture.
- Detent change: spring transition with velocity carry.
- Dismiss: gesture-driven, with `motion.depart` if released past 30% downward velocity.

### Accessibility

- Drag handle has an explicit `Semantics(label: "Drag to resize")` and supports `Semantics.onIncrease` / `onDecrease` for AT-driven detent change.
- Inside content gets a focus trap while sheet is at `large`.

### Banned

- Bottom sheets that don't respect bottom safe-area inset.
- Sheets with content extending behind the drag handle.
- Sheets that obscure the floating nav without explicit reason (most do; `medium` detent leaves nav visible above the sheet, which is the design goal).

---

## FloatingNav

The persistent bottom navigation. Five tabs at most.

### Anatomy

A pill-shaped (`radius.pill`) Tier-2 active material, 64 px tall, with 5 tab targets. Spotlighted active tab.

### Tabs (1.0)

`Home · Chats · Explore · Notifications · Profile`

### States

- Inactive: Regular-weight icon at `text.secondary`, no label.
- Active: Bold-weight icon at `accent.signature.30`, scale 1.04, spotlight material highlight.
- Pressed: `motion.lift` partial.

### Motion

- Tab switch: spotlight slides between tabs via `motion.lateral` (single 360 ms spring).
- Active icon swap: `tab-active` icon motion.
- Hide on immersive surfaces (story viewer, full-screen call): `motion.depart` downward.

### Accessibility

- `Semantics(label: "{tab}, tab", selected: bool, button: true)` per tab.
- `selected` state announced.
- Min hit-target 48 × 48 per tab; full bar is wider but each cell respects the constraint.

### Banned

- Labels under active icons. (Visionariness: visionOS doesn't, iOS DCs do — we choose visionOS).
- More than 5 tabs.
- Center-elevated FAB tab. Banned (the "+1 in the middle" pattern).
- Color shifts on tab change (only weight + scale + spotlight).

---

## Spatial primitives (new in Velix)

These do not exist in the NexusChat reference. They are the mechanism by which the design system carries spatial intent on a phone.

### `RoomBackdrop`

A per-conversation ambient backdrop. Lives at Z-tier 0.

- Type: `solid` | `media.image` | `media.video` | `gradient.derived` | `spatial.scene` (Phase-3 3D)
- Default: `gradient.derived` from the conversation's room color (extremely subtle radial wash, almost imperceptible)
- The backdrop responds to device tilt with `motion.parallax` at 0.7× factor
- Audit: backdrop must never reduce text legibility below 12:1 contrast; tested per backdrop instance

### `TrustMaterial`

A wrapper that takes a child surface and applies the appropriate material modifier based on the conversation's trust state.

- States: `verified | standard | unverified | rekeyed`
- Verified: +0.02 chroma (warm)
- Unverified: -0.02 lightness, +0.01 chroma toward 250° (cool)
- Rekeyed: standard tint + `material.modifier.tremor`

### `Spotlight`

A radial light highlight applied via the `material.modifier.spotlight`.

- Anchored to a child by `Alignment` or by gesture position
- Radius and intensity configurable but with brand defaults
- Used for: active nav tab, focused message bubble during Tapback, active call participant

### `AmbientPresence`

A presence dot system used in lists (avatar bottom-right). Not visually a "dot" — it's a 6 × 6 inset notch in the avatar's circular frame, filled with the presence color. No animation; presence transitions cross-fade.

### `WaveformPlayer`

The audio-amplitude-driven 7-bar voice visualizer. Used in voice-message bubbles and during recording. Bars are sampled from the actual audio amplitude, not random.

### `ReactionPicker`

A Tier-3 popover that arrives on long-press of a `MessageBubble`. Six emoji at `icon.lg`, plus a "+" for custom.

- Animation: arrives 12 px above the source bubble's top edge with spring.
- The source bubble lifts to Z2.5; everything else dims to 70% saturation (Tier-3 pattern).
- Selecting a reaction: the chosen emoji animates from picker location into the message's reaction cluster via a Hero-equivalent.

### `IdentityCapsule`

The compact representation of a user identity. Avatar + handle + verified glyph (if verified). Used in: chat list, profile previews, story author overlay, call participant tile.

- Sizes: `xs (28) · sm (40) · md (56) · lg (96)`
- Verified glyph: custom encryption-shield in Bold weight at `icon.xs` for `xs` capsule, `icon.sm` for `sm`+

---

## Component dependency graph

```
Button
Input
Loader
Toggle           ──► (atomic)

GlassCard        ──► uses material tiers
MessageBubble    ──► uses GlassCard, Loader, IdentityCapsule
Modal            ──► uses GlassCard
BottomSheet      ──► uses GlassCard
FloatingNav      ──► uses GlassCard, Spotlight
ReactionPicker   ──► uses GlassCard, Spotlight
WaveformPlayer   ──► atomic
TrustMaterial    ──► wraps any child
RoomBackdrop     ──► atomic
AmbientPresence  ──► atomic
IdentityCapsule  ──► uses TrustMaterial
Spotlight        ──► atomic, applied via parent provider
```

Components reach **down** the graph, never up. A `Modal` cannot import a `MessageBubble`; a screen composes both.

## Implementation cadence

In Phase 5, components are built bottom-up:
1. Atomic (Button, Input, Loader, Toggle, AmbientPresence, RoomBackdrop, WaveformPlayer, Spotlight)
2. Composite (GlassCard, IdentityCapsule, TrustMaterial)
3. Surface (MessageBubble, Modal, BottomSheet, ReactionPicker)
4. Layout (FloatingNav)

Each component ships with golden-image tests and Reduce-Motion / Reduce-Transparency variants verified.
