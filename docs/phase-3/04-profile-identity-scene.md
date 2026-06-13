# 04 — Profile Identity Scene

The top 320 px of the user's profile screen, plus 40 px overlap into the identity card below. A persistent, slow, auto-personalized scene that gives a profile a place. Visible during typical 4–8 second profile views; loaded on demand, paused when off-screen.

## Why 3D here

A profile is the most identity-laden surface in the app. A flat banner photo is the cheapest way to communicate "this is me," and it ages poorly. A spatial scene tied to the user's identity carries personhood — a user-controlled visual signature that responds to their device, that belongs uniquely to them, and that we never demand a photograph for.

This is the second of three places we use 3D. Battery cost is bounded by the brevity of profile visits.

## Composition

A single shared scene template, parameterized per user. The user picks (or auto-derives) one of **eight** identity styles, each a different abstract scene.

| Style | Mood | Visual |
|---|---|---|
| `quartz` | Default — calm, technical | A slow-drifting cluster of three quartz-blue prisms |
| `aurora` | Warm, expressive | A gentle aurora gradient on a low horizon |
| `forest` | Quiet, considered | An abstract canopy of soft green shapes |
| `mist` | Misty, atmospheric | Layered semi-transparent planes |
| `coral` | Warm, vivid | A soft coral light dome |
| `iris` | Subtle, blooming | A floating cluster of low-poly iris petals |
| `slate` | Neutral, grounded | A low-relief stone landscape |
| `pacific` | Cool, deep | A horizon over a calm dark sea |

Each style:
- Reuses the same renderer pipeline.
- Costs ≤ 800 KB on disk.
- Comes with two color variants tied to the user's chosen room palette (mist, sage, etc.) so the scene's accent harmonizes with the rest of the user's UI.

The user can change style from a sheet in Profile → Edit. They can also accept the default `quartz`. We do **not** auto-pick from a profile photo or other PII; the auto-derivation is a hash of the user's account id mod 8, fully deterministic and content-free.

## Per-user parameters

| Parameter | Source | Default |
|---|---|---|
| Style | User choice or `hash(account) mod 8` | `quartz` |
| Hue shift | User-selected room color | 240° (Quartz Blue) |
| Drift period | User can pick "calm" (32s) or "alert" (18s) | calm |
| Parallax intensity | User can pick "still" (0.05) or "responsive" (0.18) | responsive |

These parameters are stored client-side, encrypted, never relayed to the server. We do not need them to render — they are personalization, not identity.

## Geometry budgets per style

Designers are constrained to:

- ≤ 4,000 triangles total
- ≤ 4 materials
- ≤ 6 textures
- ≤ 600 KB file size

The `quartz` default uses 1,200 triangles and 380 KB.

## Lighting

- IBL: each style has a dedicated baked environment (256² cubemap, ~50 KB compressed).
- Fill: an optional single directional, color and angle per style.
- Real-time shadows: off.

## Camera

- FOV 30° across all styles.
- Camera is positioned and angled per style; on-mount, it does a 1.2-second slow zoom-in from 110% to 100% (the cinematic reveal). Subsequent visits skip the zoom and start at 100%.
- Tone mapping: ACES, exposure 0.0.

## Motion

### Drift

Style-specific drift, in the 18–32 s range. The default `quartz` drifts the prism cluster around a vertical axis at one revolution per 28 s.

### Parallax

Tilt-factor 0.05–0.18 (user-controlled). Scroll-factor 0.40 (the scene moves slightly with the profile scroll, integrating it into the user's larger gesture).

### Cinematic reveal

On first view post-edit, the scene materializes via a 600 ms `motion.cinematicReveal` (the second sanctioned use in the system). On normal subsequent views, it's a standard 240 ms fade-in.

## Identity card overlay

The identity card overlaps the bottom of the scene by 40 px. Behind the card, the scene continues — the bottom of the rendering blurs and fades to the substrate via a 60 px gradient, so the card sits "on top of" the scene rather than at a hard edge. This is a subtle but important detail.

## Fallback

Each style has a fallback PNG (~120 KB) — the static-pose render. Used in:

- All cases under Reduce Transparency
- Web client (always)
- Low-end devices
- Cold-start: shown for the brief moment between widget mount and scene ready

The fallbacks are not generic — each style has its own. A `quartz` profile and a `forest` profile look different even with 3D off.

## Performance verification

| Constraint | Budget | quartz default |
|---|---|---|
| GPU frame time | 4 ms | est. 1.5 ms |
| CPU frame time | 2 ms | est. 0.5 ms |
| Cold load | 180 ms | est. 60 ms |
| Triangles | 12,000 | 1,200 |
| File size | 800 KB | 380 KB |

The other seven styles are budgeted equivalently and benchmarked individually.

## Lifecycle

```
profile screen mount
  → controller.load(SceneId.profileIdentity, params)
    → 60 ms async load (fallback shown during)
  → controller.resume()
profile screen scroll out of view
  → controller.pause(keepLastFrame: true)
profile screen unmount
  → controller.dispose()
```

If the user navigates away from Profile and comes back within 30 seconds, the scene is hot — already loaded, just paused. If beyond 30 seconds, we re-load (the cost is small and memory hygiene is more important).

## Reduce Motion

- Drift disabled.
- Tilt parallax disabled (scroll parallax retained).
- Cinematic reveal collapses to a 200 ms fade.

## Reduce Transparency

- Scene replaced by fallback PNG as a static substrate background.
- The 40 px overlap of the identity card stays visually correct (same gradient blend works on a flat image).

## Privacy and identity

- Style choice never leaves the device.
- The IBL environment is bundled with the app; no per-user content is downloaded.
- The 3D engine never accesses any data beyond the user's selected parameters.
- AT users see the identity card as a fully-described `Semantics` surface; the scene is announced as decorative ("Profile identity scene, [style name]") and skippable.

## Cross-account: viewing another user's profile

In Quarter +1, the same scene template is used when viewing other users' profiles, parameterized by the *viewed user's* style choice (encrypted to the viewer in the existing E2E channel). The scene asset itself is the same — we don't ship per-user 3D assets, only per-style variants.

## Banned

- Any style with text in it. Profiles have textual identity in 2D.
- Any style with photographs as textures. We synthesize.
- Animated cycles longer than 32 seconds (the user notices).
- Loops with a visible "snap back to start" frame. Drifts are seamless.
- Real-time shadows or particles on this surface (or any other).
