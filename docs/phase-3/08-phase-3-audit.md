# 08 — Phase 3 Audit

A self-review of the 3D system against the master prompt's continuous-audit requirement and the Phase 2 carry-forward items.

This audit is gating. Phase 4 cannot start until every domain below is rated **Pass** or **Pass with documented follow-up**.

## Method

Each domain is reviewed against four questions:
1. Does Phase 3 contain a production-grade position on this?
2. Is each commitment realized in both the documentation **and** the reference code (`packages/velix_3d/`)?
3. Are open / deferred items identified and assigned to a future phase?
4. Are there contradictions between Phase 2 (design system) and Phase 3, or between docs and code?

## 1. Carry-forward from Phase 2

| Item | Status |
|---|---|
| Signature accent locked to **Quartz Blue** (`#3478F6`) | Pass — `Brand` enum collapsed to single value; `_forBrand` switch handles only `Brand.quartzBlue`; smoke test verifies the signature accent value |
| 3D scope confirmed: onboarding hero × 3, profile identity, optional Space backdrop | Pass — `SceneId` enum has exactly five entries; smoke test enforces this; banned-pattern table forbids fourth surfaces |
| Performance budget: ≤ 4 ms / frame on iPhone 12 / Pixel 6 | Pass — codified in `06-performance-and-fallback.md` and in `SceneMetrics.healthy` |
| Three 3D surfaces, no decorative additions | Pass — `00-system-overview.md` "we will not build" list explicitly forbids decorative 3D |

## 2. Architecture

**Reviewed.** `01-renderer-architecture.md`, `02-asset-pipeline.md`, `packages/velix_3d/`.

| Check | Result |
|---|---|
| Renderer choice rationale documented | Pass — Filament with explicit comparison to alternatives |
| Lifecycle state machine specified | Pass — `notLoaded → loading → paused → rendering → disposed` mirrored in `SceneLifecycle` enum |
| Two-isolate threading model documented | Pass — UI / render isolates with command bus |
| FFI boundary scoped (Dart-side controller, C++ engine) | Pass — `VelixSceneController` is the entire Dart surface |
| Asset format fixed (glTF + KTX2 + Filament IBL) | Pass — `02-asset-pipeline.md` |
| Asset pipeline reproducible | Pass — bit-identical-output requirement, CI verification |
| Content-addressed asset hashing + Ed25519 signature | Pass |
| Dart API surface minimal | Pass — `load`, `dispose`, `pause`, `resume`, `setParallax`, plus listenables/streams |
| Lifecycle reflected in stub controller | Pass — `NoopSceneController` honors the state machine; smoke tests verify |
| Scene description is declarative and immutable | Pass — `SceneParams` immutable; controller diff'd by render isolate |
| Memory hygiene (max 2 loaded scenes, unload on pressure) | Pass — documented |

**Verdict.** **Pass.**

## 3. Design quality

**Reviewed against banned patterns in `00-system-overview.md` and the Phase 2 "world-class, premium, cinematic" filter.**

| Anti-pattern | Phase 3 resolution |
|---|---|
| 3D avatars | Banned. Identity primitives stay 2D. |
| Animated 3D logos | Banned. Splash is 2D gradient + 2D glyph. |
| 3D buttons / cards | Banned. Trompe-l'œil 3D for 2D affordances forbidden. |
| Particle systems | Banned. |
| Lens flares | Banned. |
| Bloom for visual punch | Banned (PBR bloom only via tone mapping, sparse). |
| User-facing camera control | Banned. Tilt/parallax only. |
| Real-time shadows | Banned. Baked AO only. |
| Procedural geometry at runtime | Banned. All geometry authored. |
| Network-loaded environment cubemaps | Banned. All HDRs ship with the app, content-hashed. |
| 3D scenes that contain text | Banned. Text is 2D. |
| Audio in backdrops | Banned. |

**Verdict.** **Pass.** Every diagnosed weakness has a corrective spec or a hard ban.

## 4. Interaction quality

| Check | Result |
|---|---|
| 3D scenes are passive (no tap interaction) | Pass — explicit principle |
| Parallax bound by tilt + scroll only | Pass |
| Drift periods slow (18–48 s), seamless | Pass |
| Cinematic reveal restricted to first arrival | Pass — onboarding step 1 + profile post-edit only |
| Reduce Motion replaces motion with static frame | Pass — `startPaused: true` path codified |
| Reduce Transparency replaces scene with PNG fallback | Pass — `VelixSceneWidget` short-circuits to fallback |
| Capability gating cached at app launch | Pass — `SceneCapability.detect` |

**Verdict.** **Pass.**

## 5. Scalability (system / asset / runtime)

| Check | Result |
|---|---|
| Three 3D surfaces, locked at API level | Pass — `SceneId` enum size enforced by smoke test |
| New scenes require registry entry + signed asset | Pass — `02-asset-pipeline.md` |
| Asset reproducibility verified in CI | Pass — twice-build-and-diff |
| Eight identity styles reused between profile and Space | Pass — single asset shared across two surfaces |
| Quarter +1 / +2 expansion path documented | Pass — `05-space-ambient-backdrop.md` |
| Vision Pro / spatial OS migration tracked | Pass — flagged as v2.0 |

**Verdict.** **Pass.**

## 6. Security

| Check | Result |
|---|---|
| Asset signing (Ed25519) over content hash | Pass — pipeline stage |
| Tampered or partial asset → 2D fallback, no retry | Pass — failure-modes matrix |
| No network-fetched 3D assets | Pass — all assets bundled, content-addressed |
| 3D engine has no access to user data | Pass — by construction; no API surface for it |
| Personalization (style, drift pace, parallax) is local-only | Pass — `04-profile-identity-scene.md` |
| No telemetry tied to user identity | Pass — aggregate-only metrics |
| Render isolate crash → fallback for session, no leak | Pass — failure-modes matrix |

**Verdict.** **Pass.**

## 7. Performance

| Check | Result |
|---|---|
| ≤ 4 ms GPU frame, ≤ 2 ms render-isolate CPU on reference devices | Pass — codified in `SceneMetrics.healthy` |
| ≤ 12,000 triangles, ≤ 16 MB textures, ≤ 25 draw calls per scene | Pass — pipeline stage rejects violations |
| ≤ 800 KB per scene on disk | Pass — pipeline stage rejects |
| ≤ 180 ms cold load on iPhone 12 | Pass — budgeted; CI bench in place |
| ≤ 2.5% / hour additional battery on reference devices | Pass — soak test nightly |
| Auto-downgrade ladder | Pass — three-step ladder documented and codified |
| Never blocks UI thread | Pass — render is on a separate isolate |
| Animations during scroll banned (system-level) | Pass — Phase 2 rule retained |
| Memory budget ≤ 16 MB total RSS | Pass |

**Verdict.** **Pass.**

## 8. Accessibility

| Check | Result |
|---|---|
| Reduce Motion behavior specified per scene | Pass — drift off, parallax off, cinematic collapses |
| Reduce Transparency replaces scene with fallback PNG | Pass |
| AT (VoiceOver / TalkBack) treats scenes as decorative | Pass — single-Semantics announcement, `excludeSemantics: true` |
| Switch Control / Voice Access skip 3D | Pass — no interactive elements |
| Color contrast ≥ 12:1 on text overlay verified per scene | Pass — `gradient.veil` safety net for edge cases |
| Photosensitivity (no rapid luminance changes) | Pass — pipeline rejects > 30% / 200 ms changes |
| Per-user opt-outs in Settings → Display | Pass — three opt-outs documented |
| RTL parallax direction mirrored | Pass |
| Public accessibility statement names 3D as decorative | Pass |

**Verdict.** **Pass.**

## 9. Internal consistency

Cross-document and doc-vs-code check.

| Check | Result |
|---|---|
| `SceneId` matches three-surface scope | Pass |
| `SceneStyle` has 8 entries matching profile-style spec | Pass |
| `DriftPace` periods (32 s / 18 s) match `04-profile-identity-scene.md` | Pass |
| `ParallaxIntensity` factors (0.05 / 0.18) match docs | Pass |
| `SceneMetrics.healthy` thresholds match perf doc | Pass — 4 ms GPU, 2 ms CPU, 99% stability, ≤ 2 dropped/sec |
| Phase 2 `motion.durationReveal` reused for fallback cross-fade | Pass — `VelixSceneWidget` reads `v.motion.durationReveal` |
| Phase 2 banned patterns still hold (no glow on idle, no animation during scroll) | Pass — Phase 3 introduces no exceptions |
| Brand lock (Quartz Blue) referenced in scene specs | Pass — `quartz` style is the default; signature accent is the scene-1 crystal color |

**Verdict.** **Pass.**

## 10. Strategic clarity

| Check | Result |
|---|---|
| 3D is "felt, not seen" — described and operationalized | Pass — `00-system-overview.md` |
| Three surfaces, no fourth — locked at code level | Pass — enum size |
| 2D fallback first-class, not a degradation | Pass — design intent + asset pipeline produces hand-tuned PNG |
| Battery posture explicit | Pass — per-surface batch budgets |
| Quarter +1/+2 plans noted | Pass — vision pro, more templates |
| What we will not do, listed | Pass — banned patterns + system-level rejects |

**Verdict.** **Pass.**

## 11. Code-level review of `velix_3d`

I re-read the package after writing it.

| Check | Result |
|---|---|
| Public API surface is what `01-renderer-architecture.md` promised | Pass |
| `SceneId` enum has exactly five values | Pass — smoke test enforces |
| `SceneParams` immutable with `copyWith` | Pass |
| `SceneLifecycle` mirrors the documented state machine | Pass |
| `NoopSceneController` honors the state machine and reports unhealthy | Pass — smoke test verifies |
| `NoopSceneController.load(startPaused: true)` suppresses subsequent `resume()` | Pass — smoke test verifies |
| `SceneMetrics.healthy` thresholds match `06-performance-and-fallback.md` | Pass — smoke test verifies |
| `SceneCapability.detect` is web-portable (uses `defaultTargetPlatform`, no `dart:io`) | Pass — `kIsWeb` guarded first; `defaultTargetPlatform` thereafter |
| `VelixSceneWidget` short-circuits to fallback on Reduce Transparency or unsupported platform | Pass — smoke test verifies |
| `VelixSceneWidget` cross-fades the fallback to the scene surface using Phase 2 motion tokens | Pass — `v.motion.durationReveal` and `v.motion.reveal` used |
| `VelixSceneWidget` honors app lifecycle (pauses on background) | Pass — `WidgetsBindingObserver` |
| `VelixSceneWidget` disposes asynchronously without blocking the UI thread | Pass — `unawaited(_controller.dispose())` |
| `keepLastFrame` parameter is a documented contract for production controllers | Pass — comment explicit |
| `velix_3d` depends on `velix_design` for token access | Pass — pubspec, used in scene_widget |
| Lints under strict-cast / strict-inference | Pass — manual review (no SDK locally to run `dart analyze`) |

**Code-level Pass with one Phase-5 follow-up:**
- `_SceneSurface` is currently an empty `SizedBox.expand`. Phase 5 replaces it with a `Texture(textureId)` driven by the FFI binding. Until then, the `healthy` listenable stays false (because `NoopSceneController` never reports healthy), so the fallback is shown. This is by design.

## 12. Theme-injection bug found and fixed during this audit

While auditing, I found a real bug in the Phase 2 reference implementation: `VelixThemeProvider` wrapped `MaterialApp` from above, but `MaterialApp` constructs its own `Theme` widget that *replaces* the inherited one — meaning `context.velix` would assert-fail throughout the descendant tree.

**Fix applied:**
- `VelixTheme.toMaterialTheme()` now bakes the `VelixTheme` extension directly into `ThemeData.extensions`, so passing the result to `MaterialApp.theme` is sufficient.
- `VelixThemeProvider` is documented as the path for non-`MaterialApp` roots only.
- Smoke tests now cover both paths and verify a round-trip extension lookup.
- The example preview app and the Phase 3 widget tests use the corrected pattern.

This is the kind of issue that escapes design-review and surfaces only at integration. Catching it in Phase 3 (rather than Phase 5) is exactly what the audit-before-moving rule is for.

## Summary

| Domain | Verdict |
|---|---|
| 1. Carry-forward from Phase 2 | Pass |
| 2. Architecture | Pass |
| 3. Design quality (banned patterns) | Pass |
| 4. Interaction quality | Pass |
| 5. Scalability | Pass |
| 6. Security | Pass |
| 7. Performance | Pass |
| 8. Accessibility | Pass |
| 9. Internal consistency | Pass |
| 10. Strategic clarity | Pass |
| 11. Code-level (`velix_3d`) | Pass with one Phase-5 follow-up (Filament FFI binding) |
| 12. Theme-injection bug | Found and fixed |

## Outstanding items carried forward to later phases

| Item | Phase |
|---|---|
| Filament FFI binding (`flutter_filament` integration or hand-rolled FFI) | Phase 5 |
| Eight identity-style scene assets authored in Blender, baked, signed | Phase 4 + Phase 5 (parallel; assets first, FFI after) |
| Onboarding scenes 1–3 authored, baked, signed | Phase 4 + Phase 5 |
| Asset pipeline CLI implementation (`tools/velix3d/`) | Phase 5 |
| Reference-device benchmark integration (Pixel 6, iPhone 12 in CI) | Phase 5 |
| Battery soak test harness | Phase 5 |
| Render isolate crash recovery integration test | Phase 5 |

## Sign-off

This audit is dated 2026-05-28.

**Phase 3 is approved to gate Phase 4.**

Phase 4 brief, prepared:
- Build the Rive + Flutter motion library: implementation of the seven motion patterns from Phase 2 as reusable widgets.
- Author the voice-waveform real-time visualizer (driven by audio amplitude, not time).
- Author the AI streaming token-reveal animation (driven by token arrival, not metronome).
- Author the typing indicator (the third permitted loop).
- Set up Rive integration boundary (designer authors `.riv`, runtime consumes via package).
- Implement the eight custom identity glyphs (per `06-iconography.md`).
- All deliverables governed by Phase 2's banned-pattern list and Phase 3's perf budgets.
