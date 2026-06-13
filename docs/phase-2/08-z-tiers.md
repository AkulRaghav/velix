# 08 — Z-Tiers (Spatial Layering)

Most "futuristic startup" UIs are flat by accident — every surface lives at the same Z. Vision Pro and visionOS are explicitly spatial. We do not have full 3D on a phone, but we have rigorous Z discipline.

## Four-tier model

```
Z-tier 3 — Modal     (lifted material, sheets, popovers, full-screen overlays)
                ▲
                │  cross-tier transitions: motion.arrive / motion.depart
                ▼
Z-tier 2 — Content   (cards, message bubbles, hero surfaces)
                ▲
                │  cross-tier transitions: motion.lift / motion.settle
                ▼
Z-tier 1 — Nav       (floating bar, persistent header, conversation composer)
                ▲
                │  cross-tier transitions: motion.reveal
                ▼
Z-tier 0 — Substrate (the scene; backdrop; story content; full-bleed media)
```

A surface knows its Z-tier. Its material, shadow, blur, and motion are determined by that Z-tier. We do not author shadows or blurs ad hoc.

## Tier definitions

### Z-tier 0 — Substrate

The scene. The thing the user is "in." Photos, videos, story content, the conversation backdrop, the call view, all live here.

- Material: opaque or full-bleed media
- Shadow: none
- Blur: none
- Motion: parallax-on-scroll, parallax-on-tilt
- Touch: rare; substrate is mostly atmospheric

The substrate is intentionally calm. It establishes mood and place; it does not perform.

### Z-tier 1 — Nav

Persistent navigational chrome that lives above the substrate. The floating navigation bar, the conversation header, the call control bar, the conversation composer.

- Material: Tier-2 active (24 px blur, 62% surface.active, 1.15 saturation)
- Shadow: `elevation.2` (contact + ambient.low)
- Edge: 1 px top inset highlight
- Motion: rarely moves; appears on app open via `motion.reveal`; hides via `motion.depart` when in immersive surfaces (story viewer, full-screen call)

Nav is the only persistent layer. It is the user's anchor.

### Z-tier 2 — Content

The body of any screen: cards, message bubbles, list cells, hero surfaces, settings groups, profile sections.

- Material: Tier-1 quiet (typically) or opaque
- Shadow: `elevation.1` for cards on substrate; `elevation.0` for inline content
- Motion: `motion.arrive` on insertion; `motion.depart` on removal; `motion.lateral` on screen transition

Content is what scrolls. Content is what the user reads, taps, sees. The vast majority of the UI lives here.

### Z-tier 3 — Modal

Surfaces that present *over* the application. Modal dialogs, bottom sheets, popovers, toast notifications, the AI assistant overlay, the reaction picker, the call's-active-participant card.

- Material: Tier-3 lifted (40 px blur, 50% surface.lifted, 1.25 saturation)
- Shadow: `elevation.3` or `elevation.4`
- Edge: 1 px top inset + 1 px bottom inset (full bevel)
- Backdrop: scrim at `surface.scrim` 60% behind the modal (substrate dims, content blurs additionally to 8 px)
- Motion: `motion.arrive` / `motion.depart`

Tier-3 surfaces interrupt the user. They must justify their presence.

## Cross-tier rules

1. **Only one Tier-3 surface visible at a time.** Stacking Tier-3 modals is forbidden. The replacement modal is the same Z; it animates as a content swap, not a new layer.

2. **Tier-3 dims everything below.** Substrate gains an additional 8 px of blur and the entire below-stack desaturates to 70%. This is the most important spatial cue we have on a phone.

3. **Tier-1 (nav) is excluded from Tier-3's dim**. The nav remains crisp behind a modal so the user can navigate away.
   - Exception: **fullscreen modals** (story viewer, voice/video call). These hide the nav via `motion.depart` because they are spatially "elsewhere."

4. **Tier-2 cards do not stack with other Tier-2 cards in a way that their shadows overlap visibly.** If they would, one of them ascends to Tier-3 (becomes a popover) or both descend to Tier-1 (become inline list cells).

5. **Substrate scrolls under Z-tier 1.** The nav always remains in place; substrate moves beneath it. We never push the nav off-screen on scroll except inside immersive surfaces.

## Z-driven materials

This is a tabular reference, derived from `02-material-tiers.md`:

| Z | Material | Blur | Surface | Edge | Shadow |
|---|---|---|---|---|---|
| 0 | Opaque substrate | 0 | substrate | none | none |
| 1 | Active glass | 24 px | active 62% | 1 px top inset | elevation.2 |
| 2 | Quiet glass / opaque card | 0–8 px | quiet 88% | 1 px top inset (faint) | elevation.0–1 |
| 3 | Lifted glass | 40 px | lifted 50% | 1 px top + bottom inset | elevation.3–4 |

## Z-driven motion

Cross-tier motion uses specific patterns:

| From → To | Pattern | Use |
|---|---|---|
| Z0 → Z1 | `motion.reveal` | App open, nav appearance |
| Z1 → Z2 | n/a (Z2 always above Z1; no transition between them) | — |
| Z2 → Z3 | `motion.arrive` (Z3) + dim of Z<3 | Modal open |
| Z3 → Z2 | `motion.depart` (Z3) + un-dim | Modal close |
| Z2 → Z2.5 (lift) | `motion.lift` | Tap-and-hold pickup |
| Z2.5 → Z2 | `motion.settle` | Drop |
| Z1 → off-screen | `motion.depart` (downward) | Nav hidden during immersive surface |
| Z0 (parallax) | `motion.parallax` | Scroll-coupled, ongoing |

Z2.5 is a transient state. A surface in `motion.lift` is between Z2 and Z3 conceptually — visibly elevated but not a modal. Settle returns it to Z2.

## Substrate types

Substrate is not always a single neutral surface. It can be:

| Substrate type | Use |
|---|---|
| `substrate.solid` | Most screens — substrate.surface fill |
| `substrate.media.image` | Conversation with a custom backdrop, story view, call view (background) |
| `substrate.media.video` | Call view (remote video), full-screen story video |
| `substrate.gradient` | Onboarding, splash (the only places `gradient.signature` is the background) |
| `substrate.spatial.scene` | Profile identity scene, persistent room hero (uses Phase-3 3D) |

Choosing a substrate type is a per-screen decision in `10-screen-blueprints.md`.

## Audit rule

A screen with **more than four visible Z-tiers at once** is reviewed. The four are: substrate (always), nav (usually), content (usually), modal (sometimes). If any single screen reaches a fifth tier we have over-engineered the surface.

## Banned patterns

- Cards with shadows competing with each other for the same Z (visual mess).
- Bottom sheets on top of bottom sheets.
- Modal-over-modal except for the deliberate alert-on-modal pattern (a critical confirm dialog over a settings sheet) — and even there, the underlying sheet is visually frozen, not stacked.
- Floating action buttons that overlap content shadows on scroll without a material adjustment.
- Glass-on-glass at the same tier (`Tier-2` over `Tier-2`).
- Surfaces at Tier-3 that are not actually interrupting the user (e.g., a floating "promotional" card pretending to be a modal). Forbidden.
