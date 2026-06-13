# 05 — Space Ambient Backdrop

Optional, opt-in, per-Space (community room). Renders at Z-tier 0 inside a Space, providing literal place-ness for what the user conceptually thinks of as "the room."

This is the third of three sanctioned 3D surfaces. It is the most easily abused — a backdrop in a heavily-used surface — so it has the strictest opt-in posture and the tightest performance audit.

## Status

Default state for any Space: **off**. The Space's owner enables it explicitly from Space settings, picks one of the eight templates, and ships. Default-off avoids battery drain for users who don't care, and avoids a crowded look in the catalog of Spaces.

Enabling a backdrop is a per-Space decision, not per-user. The Space owner sets it; members see it.

## When the backdrop is visible

- Inside the Space's home view (the lobby / channel list).
- **Not** inside individual channels within the Space — there, the substrate is the standard `solid` and the channel's content is foregrounded. Reasoning: the backdrop is "the Space's place"; channels are inside that place but don't need redundant visual identity.

## Eight templates

The same eight identity-style scene templates as `04-profile-identity-scene.md`, reused. Reusing assets reduces footprint dramatically and makes the design system feel coherent: a profile and a Space share the same visual vocabulary.

A Space's owner picks the template independently of their personal profile style.

## Why reuse

- One asset budget instead of two.
- Visual coherence.
- Reduces designer authoring load by 50%.
- Performance profile already proven for the profile use case.

## Differences from the profile use

| Aspect | Profile | Space backdrop |
|---|---|---|
| Z-tier | 0 (substrate) | 0 (substrate) |
| Visible duration per visit | 4–8 s | typically 30 s – several minutes |
| Drift period | 18–32 s | always **48 s** (slower; backdrop is calmer) |
| Parallax | tilt + scroll | tilt only (scroll is full of content) |
| Cinematic reveal | 600 ms on first view post-edit | 240 ms on each Space entry, no cinematic reveal |
| Render priority | medium | low (lower than any foreground content) |

Specifically, because Space visits are longer, we slow the drift to avoid the user becoming aware of it. A scene moving slightly is calm; a scene whose motion you've noticed is busy.

## Battery posture

A user can spend significant time in a Space. To keep battery under budget, we apply two strategies:

1. **Reduced render frame rate.** When the Space backdrop is visible at Z0 and a foreground element is being interacted with at Z2, the backdrop drops to **30 fps**. The foreground stays at 60 fps; the eye does not perceive the backdrop's lower rate because it is naturally slow. Saves ~50% backdrop GPU cost.

2. **Static-frame mode after 5 minutes idle.** If the user has not interacted with the Space for 5 minutes (no scroll, no tap), the backdrop pauses to a static frame. Resumes on next interaction. Saves all subsequent backdrop GPU cost.

Combined, these mean a 30-minute Space session costs less than 2.5% additional battery.

## Performance verification

| Constraint | Budget | Per-template |
|---|---|---|
| GPU frame time at full 60 fps | 4 ms | est. 1.5 ms |
| GPU frame time at reduced 30 fps | 2 ms / 33 ms | est. 0.7 ms / 33 ms |
| File size | 800 KB | 380 KB (shared with profile) |
| Cold load | 180 ms | est. 60 ms |

Memory: a single Space is at most 4 MB resident; we deduplicate assets if the user is in multiple Spaces with the same template.

## Tinting

The backdrop is automatically tinted by the Space's room color (one of the twelve), at 8% intensity. This is what makes a `mist` Space feel different from a `coral` Space even when both use the `quartz` template.

## Owner controls

A Space owner can set:
- Template (one of 8) or "Off" (default)
- Tint room color (one of 12, or auto-derived from Space id hash)
- Drift speed (calm / standard / "energetic" — the latter caps at 36 s period; we don't ship anything truly fast)
- Off-by-default for all members regardless of template (members can opt back in personally)

A member can override the owner's choice for themselves: "Disable backdrops for this Space." Their override is local and never leaks to the server.

## Member opt-out

Available globally in Settings → Display: "Disable 3D backdrops in Spaces." This sets the runtime flag that makes every Space backdrop fall back to the 2D static frame for that user, regardless of Space owner setting. Default: enabled. Easily disabled.

## Loading and visibility

- Scene loads on first Space entry; cached for the app lifetime.
- Subsequent entries are instant (no cold load).
- Invisible (paused) when:
  - The user navigates to a channel inside the Space.
  - Reduce Transparency on.
  - Battery saver / Low Power Mode.
  - The user has globally opted out.
  - The Space's owner has chosen "Off."

## Fallback

Each template's existing fallback PNG (from the profile system) is reused. No new assets.

## Failure modes (additional to the global ones)

If a Space owner's chosen template fails its budget audit (it shouldn't — we don't ship broken assets — but defense in depth), the backdrop disables silently for that Space. The Space owner sees a polite "Backdrop unavailable" notice in Space settings; users see only the standard substrate.

## Banned

- Backdrops with content (text, photos, logos). The backdrop is *atmosphere* only.
- Backdrops with rapid motion.
- Backdrops with bright accent colors that overwhelm foreground text. We will reject any custom backdrop that fails the contrast check (`text.primary` on backdrop must exceed 12:1 sampled across the entire surface).
- Per-Space custom 3D assets uploaded by Space owners. Users do not author 3D content in Velix 1.0. We reuse the eight templates.
- Audio. Backdrops are silent.

## Design audit hook

When a new template is added (after 1.0):
- Performance benchmarks run on iPhone 12 and Pixel 6.
- Contrast against `text.primary` verified across 12 tint colors.
- Color-blind simulation verified.
- Reduce Motion fallback validated.
- Designer sign-off against the test-render.

## Quarter +1 / +2 plans

- Allow Space owners to fine-tune drift period and parallax intensity (currently three preset values).
- More templates (target: 12 total in Q+1).
- Vision Pro / spatial OS variants of the templates that exploit real spatial rendering.

We do **not** plan to allow Space owners to upload custom 3D content. The cost / abuse / moderation surface is too large.
