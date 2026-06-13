# Phase 3 — 3D Experience System

Status: in progress. Gates Phase 4.

## Locked scope

Three surfaces. No more.

1. **Onboarding hero scenes** — three steps, three scenes, used during first-run only.
2. **Profile identity scene** — the top 320 px of the user's own profile (and optionally other users' profiles in Quarter +1).
3. **Optional Space ambient backdrop** — the per-Space scene rendered at Z-tier 0 inside Spaces (community rooms). Opt-in per Space; defaults to a `gradient.derived` fallback.

We do **not** add 3D to:
- Splash (it's 2D gradient + a glyph)
- Chat list, conversation, settings, notifications, explore, stories, calls, AI assistant
- Avatars (they remain 2D `IdentityCapsule`)
- Any decorative surface

If a future product brief requests a fourth 3D surface, it goes through a formal design review against the budget below.

## Hard budget

Every 3D surface obeys these limits, measured on iPhone 12 (A14, 2020) and Pixel 6 (Tensor G1, 2021) — our reference mid-tier devices.

| Constraint | Budget |
|---|---|
| GPU frame time | ≤ 4.0 ms |
| CPU frame time | ≤ 2.0 ms |
| Total triangles per scene | ≤ 12,000 |
| Texture memory per scene | ≤ 16 MB |
| Draw calls per frame | ≤ 25 |
| Cold start cost (one-time scene load) | ≤ 180 ms |
| Battery cost (active 3D foreground) | ≤ 2.5% / hour additional |
| File size on disk per scene | ≤ 800 KB (compressed glTF + KTX2) |

All numbers are upper bounds. Each scene is benchmarked individually and the budgets are enforced in CI.

## Renderer choice

**Filament via the `flutter_filament` plugin (or our own thin Dart FFI binding to the Filament C++ library).**

Why Filament:
- Google's open-source PBR engine. Shipping in production at Google for years.
- Native iOS (Metal) and Android (Vulkan/OpenGL ES 3) backends, with automatic feature-level fallback.
- Has a credible Flutter binding path, and even without it the C++ surface is small enough to wrap in Dart FFI.
- The PBR pipeline matches Vision Pro's material sensibility (image-based lighting, energy-conserving BRDFs), unlike older OpenGL toolkits.
- Compiles down to a small runtime (~1.8 MB on Android, ~2.4 MB on iOS).

Why not the alternatives:
- `flutter_3d_controller` (model_viewer wrapper) — useful for prototyping, not for production-quality lighting.
- `flame_3d` — too young, single-maintainer.
- `webgl-via-WebView` — disqualified for performance, security posture, and platform inconsistency.
- Native `SceneKit` / `Sceneform` — would fork iOS / Android implementations.
- Unity / Unreal — utterly disproportionate to the scope.

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [3D System Overview](./00-system-overview.md) | Philosophy, scope, what we will not build |
| 01 | [Renderer Architecture](./01-renderer-architecture.md) | Filament integration, lifecycle, threading |
| 02 | [Asset Pipeline](./02-asset-pipeline.md) | glTF + KTX2, optimization, signing |
| 03 | [Onboarding Scenes](./03-onboarding-scenes.md) | The three onboarding scenes spec'd to the polygon |
| 04 | [Profile Identity Scene](./04-profile-identity-scene.md) | Top of profile screen |
| 05 | [Space Ambient Backdrop](./05-space-ambient-backdrop.md) | Per-Space scene, opt-in |
| 06 | [Performance & Fallback](./06-performance-and-fallback.md) | Budgets, telemetry, 2D fallback policy |
| 07 | [Accessibility](./07-accessibility.md) | Reduce Motion, Reduce Transparency, AT alternatives |
| 08 | [Phase 3 Audit](./08-phase-3-audit.md) | Self-review, gates Phase 4 |

## Reference implementation

`packages/velix_3d/` — a Flutter package that defines:
- `VelixSceneController` — the single Dart-side handle for any 3D surface
- `VelixScene` — abstract scene definition (composition of camera, lights, models, parallax bindings)
- Hooks for `MediaQuery.disableAnimations` (Reduce Motion) → static-frame fallback
- Hooks for `MediaQuery.highContrast` (Reduce Transparency) → 2D gradient fallback
- An empty placeholder for each of the three production scenes

This package compiles standalone but the actual scene assets ship in Phase 4 once the asset pipeline is set up. Phase 3 establishes the bones.

## Reading order

If you have ten minutes: 00 → 06 → 08.
If you're implementing: 01 → 02 → 03–05 in parallel.
If you're auditing: 08 → 06 → 07 → everything else.
