# 01 — Renderer Architecture

The 3D system has a small surface area on purpose. Most of its weight lives outside Dart — in Filament's C++ runtime — and the Dart layer is a controller, not an engine.

## Layers

```
  Dart (velix_3d)                                  ← scene description, lifecycle, telemetry
        │ FFI
  Filament (C++)                                   ← renderer, scene graph, BRDFs
        │ platform binding
  iOS Metal  /  Android Vulkan or GLES 3.2  /  macOS Metal  /  Windows D3D11/12 / Linux GLES3
```

Web (PWA) does not get 3D. The web client falls back to the 2D substrate for all three surfaces. We do not ship a WebGL second-source.

## Public Dart API

`velix_3d/lib/velix_3d.dart` exposes a deliberately small surface:

```dart
class VelixSceneController {
  /// Loads a scene by id. Returns when the scene is ready or the load fails.
  Future<void> load(SceneId id);

  /// Releases all resources. Required on widget dispose.
  Future<void> dispose();

  /// Pauses rendering and snapshots a single frame. Used when the surface
  /// scrolls out of view or the device enters Reduce-Motion.
  void pause({bool keepLastFrame = true});

  void resume();

  /// Updates parallax inputs (gyro, scroll). Throttled internally.
  void setParallax({required double tiltX, required double tiltY, double scrollY = 0});

  /// Reports current performance: frame stability, GPU/CPU time, dropped frames.
  Stream<SceneMetrics> get metrics;

  /// Whether 3D is healthy. Watched by the host widget; on `false`, the
  /// 2D fallback is shown until the next app launch.
  ValueListenable<bool> get healthy;
}

enum SceneId {
  onboardingStep1,
  onboardingStep2,
  onboardingStep3,
  profileIdentity,
  spaceAmbient,
}
```

The host widget (`VelixSceneWidget`) wraps a controller and a fallback:

```dart
VelixSceneWidget(
  scene: SceneId.profileIdentity,
  fallback: const ProfileIdentityFallback(),
  // Optional binds; system gyro is the default tilt source.
  scrollController: scrollCtrl,
)
```

If the controller reports unhealthy, the widget cross-fades to `fallback` via `motion.reveal`.

## Lifecycle

```
  ┌─────────────────┐
  │  not loaded     │  initial state
  └─────────┬───────┘
            │ load(id)
            ▼
  ┌─────────────────┐
  │  loading        │  GPU upload in progress; widget shows fallback
  └─────────┬───────┘
            │ ready
            ▼
  ┌─────────────────┐
  │  paused         │  one static frame, no GPU work
  └────┬────────▲───┘
       │resume  │pause
       ▼        │
  ┌─────────────────┐
  │  rendering      │  active 3D, frame loop running
  └─────────┬───────┘
            │ dispose()
            ▼
  ┌─────────────────┐
  │  disposed       │
  └─────────────────┘
```

Rules:
- A scene is `paused` whenever its containing widget is not visible (off-screen, app backgrounded, system Reduce Motion enabled). The renderer holds the last frame as a 2D bitmap and consumes zero GPU time.
- Loading begins when the widget mounts, runs in a background isolate so the Dart UI thread is unblocked.
- Disposal is mandatory; we leak-test in CI.

## Threading

We use **two isolates** for 3D:

1. **UI isolate** — the normal Flutter UI thread. Runs the controller's API surface. Sends commands to the render isolate via SendPort. Never blocks on render work.
2. **Render isolate** — owns the Filament `Engine` instance. Receives commands, executes the render loop. Computes parallax interpolation and frame metrics here.

Asset loading happens in a third short-lived isolate per load. glTF parse + KTX2 transcode are CPU-bound and easily moved off the UI thread.

This isolate split costs ~3 MB of memory per active scene but eliminates the worst class of jank: a Filament render-stall blocking the Flutter UI build.

## Scene composition

A scene is a Dart description that the render isolate translates to Filament entities.

```dart
class VelixScene {
  final SceneId id;
  final List<Mesh> meshes;
  final Lighting lighting;     // IBL HDR + optional fill light
  final Camera camera;
  final Drift? drift;          // ambient passive motion
  final ParallaxBinding? parallax;
  final Color background;
  // tone-mapping, exposure, dithering policy
  final ToneMapping tone;
}
```

Scenes are **declarative and immutable**. The render isolate diffs against the previously loaded scene; common assets (HDRs, brand-color materials) are deduplicated.

## Ambient drift

Most scene motion is ambient drift — slow continuous transformation that gives the surface life without demanding attention. Drift is parameterized:

```dart
class Drift {
  final Duration period;     // typically 18–32 s, deliberately slow
  final double amplitude;    // small, in scene-space units
  final Axis axis;           // tilt, rotate, translate
  final Curve curve;         // sine wave by default
}
```

Drift never accumulates error (returns to start within tolerance after each period). It pauses with the scene.

## Parallax

Parallax pulls scene-space camera offset from gyro and from scroll position. The function is defined per scene but uniform across the system:

```dart
finalOffset = clamp(
  tilt * scene.parallax.tiltFactor + scrollY * scene.parallax.scrollFactor,
  -maxParallax, +maxParallax
)
```

Tilt is sampled at the system's gyro rate (60 Hz on most phones), low-pass-filtered with a 120 ms time constant to prevent jitter, and damped via critically-damped spring toward the current target.

When the device is flat on a table, parallax is zero. When the user holds the device naturally and shifts orientation, parallax tracks gently. Reduce-Motion zeroes out tilt parallax (scroll parallax remains because it's gesture-driven by the user).

## Asset format

- Geometry & material graph: **glTF 2.0** with the Khronos `KHR_materials_*` extensions Filament supports.
- Textures: **KTX2** with BasisU compression. We support ETC2 (Android) and ASTC (iOS+modern Android) at runtime; the asset pipeline emits both.
- HDR for image-based lighting: **`.ktx2`** spherical harmonic + reflection cubemap, or Filament's pre-baked `.ktx` IBL files.
- No FBX, OBJ, USDZ, or 3MF. They either lack PBR or carry too much variability.

## Lighting

Each scene uses **image-based lighting (IBL)** as its primary light source. The HDR is a low-resolution (256² cubemap, ~50 KB compressed) environment baked from a real or designer-curated HDR map.

A second, optional **fill light** at the scene's "warm side" can be added for character. It is a directional light with no shadows. We do not use spot or area lights; both have unfavorable mobile cost / quality ratios.

Real-time shadows: **off**. Shadows are baked into albedo and ambient occlusion textures at asset time. This is what every shipping mobile 3D pipeline does for performance and what Filament can achieve cleanly.

## Tone mapping

Filament's `ACES` tone-mapping operator, with a per-scene exposure constant. We do not enable bloom in production scenes; it is an easy way to make a scene look cheap if mis-tuned.

## Color management

The Velix substrate is OKLCH `#08090C`. Filament outputs sRGB; we configure the Filament output to match the device's default color space. On iOS, that's typically Display P3; we map sRGB scene output through Filament's color-correction LUT into P3 to keep the substrate visually identical to the surrounding 2D UI.

## Compatibility / capability gating

On launch, the controller queries the platform for renderer capabilities. The matrix:

| Device class | Decision |
|---|---|
| iOS Metal, A12 or newer (iPhone XS, 2018+) | Full 3D |
| iOS Metal, A11 or older | 2D fallback |
| Android Vulkan, with `VK_KHR_synchronization2` and `feature_level >= 1` | Full 3D |
| Android GLES 3.2, OpenGL ES driver score ≥ B (heuristic) | Full 3D |
| Android GLES 3.0 / 3.1, low-end GPU | 2D fallback |
| Battery saver mode | 2D fallback |
| Low Power Mode (iOS) | 2D fallback |
| Reduce Motion | Static-frame snapshot mode |
| Reduce Transparency | 2D fallback |
| Web | 2D fallback (always) |

The 2D fallback is **first-class**, not a degradation. Our visual designs ensure the fallback is itself polished and on-brand.

## Memory hygiene

The render isolate holds:
- Filament `Engine` (one per app, persistent for app lifetime)
- Per-scene resources (geometry, textures, materials) released when the scene unloads

When the device reports memory pressure, we unload all scenes except the currently visible one, force a full GC in the render isolate, and report telemetry.

## Failure modes

| Failure | Detection | Response |
|---|---|---|
| Asset load fails | Future completes with error | Show 2D fallback; no retry |
| Render isolate crash | SendPort closes unexpectedly | Show 2D fallback; mark unhealthy for app session; report Sentry crash |
| Frame time > 16.6 ms p99 | Continuous metric stream | Auto-downgrade to 2D fallback, mark unhealthy for session |
| Memory pressure | Platform notification | Unload all scenes, retain fallback only |
| GPU device lost (Vulkan) | Vulkan callback | Recreate engine on next foreground; this app session uses fallback |

The principle: **3D is never the reason a screen breaks**. If anything is wrong, we silently fall back; the user keeps using the product.

## Telemetry (privacy-respecting)

We collect:
- Per-scene frame stability percentile (aggregate, not per-user)
- Cold-load time (aggregate)
- Battery delta during active 3D vs not (opt-in, anonymous)
- Auto-downgrade rate

We do **not** collect:
- Which scenes specific users see
- User-specific render performance attached to identity

Telemetry routes through our standard privacy-respecting pipeline (Phase 7).

## Testing

- **Unit:** scene description constructors, parallax math, drift period correctness.
- **Integration:** scene load, frame metric reporting, fallback transition.
- **Golden:** static-frame snapshots compared pixel-by-pixel for each scene at fixed gyro/scroll values, on a deterministic Vulkan software rasterizer in CI.
- **Bench:** GPU/CPU frame time on reference iPhone 12 and Pixel 6, in CI on physical-device cloud (BrowserStack App Live or similar). Budgets enforced.
- **Soak:** 30-minute idle scene runs under telemetry to verify no leaks and battery within budget.
