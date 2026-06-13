# 06 — Iconography

Icons are the most opinionated piece of any UI system. A mismatched icon is jarring in a way most users can't name but always feel.

## Library choice

We use **Phosphor Icons** as our base set, with a curated subset (~120 icons) at 1.0. Phosphor is chosen because:
- Variable weights (Thin, Light, Regular, **Bold**, Fill, Duotone) ship as separate sets, giving us systematic control.
- The icons are designed on a 24×24 grid with consistent corner radius and stroke termination, so they read as a family.
- Open license; we can fork and customize.

We do **not** use Material Icons (off-brand, mismatched stroke), Heroicons (excellent but well-trodden), Lucide (slightly inconsistent terminations across icons), or Apple SF Symbols (license restricted to Apple platforms).

We will custom-design **eight identity icons** in-house (logo glyph, key/identity glyph, room glyph, AI assistant glyph, voice glyph, call glyph, story glyph, encryption-shield glyph) so the brand has a small set of icons no other product can have.

## Icon weights

We use exactly **two weights** systemwide:

| Weight | Where used |
|---|---|
| **Regular** (Phosphor `regular`, 1.5 px stroke at 24px) | Primary inline icons, list cells, navigation |
| **Bold** (Phosphor `bold`, 2.0 px stroke at 24px) | Active states, primary CTAs, focused tabs |

Fill, Duotone, Thin, and Light are **not** part of the system. The only place we use a *filled* glyph is the floating-nav active indicator, where it reads as "this tab is currently selected" — and that's a single-pixel-different toggle, designed in custom rather than swapped from Phosphor's fill set.

The active vs. resting state of a tab icon is therefore communicated by **weight + scale (1.0 → 1.04) + spotlight material**, not by an arbitrary fill swap. This is the same posture iOS and visionOS take.

## Sizes

```
icon.xs    16    inline glyphs in body text, badges
icon.sm    20    list cell trailing actions, chip icons
icon.md    24    primary system size, nav, buttons (default)
icon.lg    28    hero/empty-state icons
icon.xl    40    onboarding, achievement, identity
icon.xxl   56    splash glyph only
```

Icons are designed on the 24-grid; sizes other than 24 use exact integer scaling (16, 20, 24, 28). 22, 26, 30 do not exist.

## Optical alignment

Phosphor's grid is consistent; even so, certain icons (especially circular or asymmetrically-weighted glyphs) need a 1 px optical nudge to align with text x-height in a row. The rule:

- The **visual center** of an icon aligns with the **x-height center** of adjacent text, not the bounding-box center.
- For curved-only glyphs, add 1 px upward offset.
- For glyphs with a tall ascender (key, lock, hanger), no adjustment.

We bake this into the `Icon` component contract: optical centering is the default, never the bounding-box centering Flutter ships.

## Pairing rules

- **Never mix stroke and filled icons in the same surface** unless the filled is exactly the same icon at active state.
- **Never mix Regular and Bold weights in the same row**, unless the row is a tab strip where Bold is the selected indicator.
- **Never combine Phosphor with another icon pack.** If we need an icon Phosphor doesn't have, we extend Phosphor or commission a match.

## Color

Icons inherit from the surface. Specifically:
- `text.primary` for active controls and selected states.
- `text.secondary` for inline meta icons.
- `text.tertiary` for inactive trailing icons in dense lists.
- `accent.signature` only on the active floating-nav tab and on the primary CTA button glyph.
- `semantic.danger` only on destructive-action confirmations.

**Two-color or duotone icons are banned.** Color is a single channel of meaning.

## Icon motion

Icons have a small grammar of allowed motion. Each is built into the `Icon` component contract.

| Motion | Trigger | Token |
|---|---|---|
| `tap-bounce` | Press | scale 1.0 → 0.92 → 1.0, 220 ms, spring(0.7, 0.3) |
| `swap-fade` | Active state change | cross-fade with 1 px scale, 180 ms, ease-out |
| `swap-rotate` | Available specifically for chevrons & disclosure | 180° rotate, 240 ms, ease-in-out |
| `tab-active` | Floating-nav tab selection | weight + 1.04 scale + spotlight, 280 ms, spring |
| `pulse-once` | New-message incoming on chat tab | 1.0 → 1.10 → 1.0 scale, 320 ms, single iteration |

We do **not** loop pulse, breathe icons, or rotate them indefinitely. A loading spinner is a separate `Loader` component, not an animated icon.

## Custom identity glyphs

Eight glyphs we design in-house. Each has its own working file and is reviewed against the Phosphor metric.

1. **Velix mark** — the wordmark glyph. Used in splash and at the smallest a-letter sizes. Designed as a custom letterform pair, not an SVG combinatorial.
2. **Identity key** — the icon for cryptographic identity, used in the security center, identity-add flows, and any UI that touches an account's key.
3. **Room** — the icon for a persistent voice/space room. Custom because Phosphor has no apt metaphor.
4. **AI assistant** — a single-glyph spark.
5. **Voice** — waveform variant tuned to our 7-bar visualization.
6. **Call connect / call end** — split into two custom glyphs that match LiveKit semantics rather than the Phosphor "phone" cliché.
7. **Story / reel** — a custom variant of a circle-segment that animates around the ring during playback.
8. **Encryption shield** — the trust-state primary glyph. Replaces the lazy lock icon. Designed so the shield can carry a sub-pixel tremor in `trust.rekeyed` state.

Each custom glyph ships in Regular and Bold to match the system.

## File format & build

Icons ship as **a single sprite SVG** (one symbol per glyph) that is split at build time into Flutter `Icons.svg` references. We do not ship Material's `Icons.icon` font for these — fonts disable per-icon styling beyond color.

A build step verifies that every icon used in code exists in the inventory file. Icons added without that file entry fail CI.

## Inventory at 1.0

We ship 120 icons at 1.0. Subsets:

- **Navigation (10):** home, chats, explore, notifications, profile, search, back, close, more, share
- **Communication (12):** message, voice, video, call, mic, mic-off, speaker, speaker-off, headphones, group, broadcast, room
- **Trust & security (10):** [identity key], [encryption shield], lock, key, fingerprint, eye, eye-slash, screenshot, app-lock, verified-check
- **Actions (16):** plus, minus, edit, delete, copy, paste, save, send, attach, image, document, location, gif, sticker, emoji, reaction
- **Status (10):** check, check-double, clock, error, warning, success, info, bolt, sparkle, ai-spark
- **Media (12):** image, video, file, document, mic-record, play, pause, stop, skip-forward, skip-back, volume-up, volume-down
- **Spaces (10):** room, channel, broadcast, hash, megaphone, gavel (mod), shield (mod), users, user-plus, user-minus
- **System (12):** settings, theme, language, accessibility, help, info, question, search, filter, sort, refresh, sync
- **Stories & reels (8):** story, reel, capture, flash, flip-camera, timer, layers, color-edit
- **Misc (20):** chevron-up, chevron-down, chevron-left, chevron-right, arrow-up, arrow-down, arrow-left, arrow-right, drag-handle, expand, collapse, pin, star, bookmark, archive, mute, do-not-disturb, qr-code, copy-link, external

Every icon has a stated semantic name and a documented use; `iconography-inventory.json` carries the mapping.

## Common mistakes

- Material Design icons leaking in via a third-party widget. Forbidden.
- Filled and stroked variants of the same glyph in adjacent positions.
- Free-tier icon sets ("Iconfinder freebies") used as placeholders that ship.
- Bold weight icons used for inactive states (only Regular for inactive).
- Two-color icons. Banned.
- Animated icons used as decoration on idle screens.
