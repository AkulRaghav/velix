# 00 — 3D System Overview

## Position

3D in Velix is a **restraint discipline**, not a feature discipline. The temptation to add "futuristic 3D elements" everywhere is exactly what the master prompt warned against, and it's how products in this genre cheapen themselves. Vision Pro is spatial because the platform is spatial. iOS apps are *not* spatial; they live on a flat 6.1-inch display and any 3D in them must justify its own existence twice over.

We use 3D in three places. Each has a job that 2D cannot do better.

## Pillars

1. **Three surfaces, no exceptions.** Onboarding hero, profile identity, optional Space backdrop. Adding a fourth requires a formal design review and a budget reallocation.
2. **Always optional, never load-bearing.** Every 3D scene has a 2D fallback that delivers the same information. If 3D fails to load, fails to render at 60 fps, or the user has Reduce Motion enabled, the 2D fallback is used. The product is fully usable without ever showing a 3D frame.
3. **PBR or nothing.** Physically based rendering is the only acceptable lighting model. We don't ship Phong or unlit shading because they are how budget 3D looks budget. Filament's IBL + microfacet BRDF is the floor.
4. **Mobile-first asset budgets.** Every scene fits inside the constraint table in `06-performance-and-fallback.md`. We do not ship a scene that "almost fits."
5. **No interaction during animation.** 3D scenes are passive (parallax-on-tilt, slow ambient drift). They do not respond to taps because that creates expectations of full 3D interactivity that we don't meet on a phone.
6. **Battery is part of the design.** A 3D scene runs for a finite, named duration (onboarding: under 90 s of total app lifetime; profile: ≤ 8 s active per visit; Space: only while the user is in the Space). Idle states render a single static frame and pause the renderer.
7. **Accessibility is non-negotiable.** Reduce Motion replaces parallax and ambient drift with a single static frame. Reduce Transparency replaces the entire scene with a 2D gradient. AT users get a textual identity affirmation in place of the visual.

## What we will not build

A list of patterns we explicitly refuse, because each is a known failure mode in mobile 3D UI.

| Banned | Why |
|---|---|
| 3D avatars | Avatars are identity primitives. They must work as 24-px IdentityCapsules in chat lists. |
| Animated 3D logos | Decorative, idle, battery-draining, off-brand. |
| 3D buttons / cards | Trompe-l'œil 3D for 2D affordances reads as gimmickry. |
| Particle systems | The cheapest "futuristic" pattern; banned. |
| Lens flares | Ditto. |
| Bloom for visual punch | Banned outside of correctly applied PBR bloom (which we use sparingly). |
| User-facing camera control | Tilt/parallax only. No pinch-zoom, no orbit. |
| Real-time shadows from dynamic lights | Static baked lighting only; one optional dynamic point light per scene. |
| Environmental cubemaps loaded over the network | All assets ship with the app or are content-addressed and verified. |
| Procedurally generated geometry at runtime | All geometry is authored, optimized, and shipped. |

## What 3D actually does for us

Each surface answers: "what can 3D communicate that 2D cannot?"

### Onboarding

Spatial cinematography establishes that this is a serious, considered product before the user sees a single feature. It pays off the brand promise of "calm + cinematic" at the moment when first impressions cost nothing. **Replaces:** flat illustration carousel.

### Profile

The identity scene is a quiet, slow-drifting visual signature attached to the user. It makes the profile feel like a place, not a settings tab. **Replaces:** banner image (a Twitter-era pattern that has aged poorly).

### Space backdrop

A Space (community room) is conceptually a place. A spatial scene at Z0 makes that conceptual model literal. **Replaces:** flat color or stretched header image.

In each case, 3D earns its budget. If a future surface wants 3D and cannot answer that question, it doesn't get 3D.

## The "felt" 3D vs the "seen" 3D

Velix's 3D is usually *felt*, not *seen*. The user is rarely conscious of the depth — a slow camera drift over baked geometry, the parallax response to tilt, the way light moves across a surface as the device moves. It's the same posture Apple takes with Dynamic Island and visionOS surfaces: depth communicates calmly, never performs.

When 3D is "seen" — clearly perceived as 3D — that is a deliberate cinematic moment, used at first arrival of the surface. Subsequent visits damp it down to a near-static pose.

## Token cascade for 3D

We extend the Phase-2 token system minimally:

```
scene.lighting.ibl       (intensity, exposure)
scene.lighting.fill      (color, intensity)
scene.parallax           (tilt-factor, scroll-factor)
scene.drift              (period, amplitude, axis)
scene.fov                (degrees)
scene.background         (color | hdr-image)
```

These are exposed as Dart records in `velix_3d` and bound per-scene.

## Performance posture

The hard rule: **no 3D scene allowed to drop a frame** in normal usage. Telemetry collects frame stability per scene; any scene that crosses a 99th-percentile frame time of 16.6 ms in production triggers an automatic downgrade for that user (the 2D fallback is shown until the next app launch).

Performance is enforced at three layers:
- **Asset-time** — the asset pipeline (Phase 3, doc 02) rejects assets exceeding budget.
- **Build-time** — CI runs render benchmarks against reference devices.
- **Runtime** — the scene controller measures and reports. Auto-downgrade if it slips.

## Audit hook

When Phase 3 closes, we verify:
- Every banned pattern above is absent from the implementation.
- Every budget in the budget table is met for all three production scenes.
- Every scene has a verified 2D fallback.
- Every scene passes the accessibility checklist.
- Battery telemetry shows ≤ 2.5% / hour additional drain on reference devices.
- The renderer is hot-reloadable in development without leaks.
