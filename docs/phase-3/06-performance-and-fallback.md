# 06 — Performance & Fallback

The hard contract for shipping 3D in Velix.

## Reference devices

| Tier | Device | Year | Used as |
|---|---|---|---|
| Premium | iPhone 15 Pro | 2023 | Confirms headroom |
| Reference iOS | iPhone 12 | 2020 | Hard budget |
| Reference Android | Pixel 6 | 2021 | Hard budget |
| Floor Android | Pixel 4a / Galaxy A52 | 2020/2021 | Auto-fallback target |

Budgets are met on the **reference** devices. The premium devices have headroom; the floor devices auto-fall-back to 2D.

## Hard frame-time budgets

| Constraint | Budget |
|---|---|
| GPU frame time, scene actively rendering | ≤ 4.0 ms |
| CPU frame time (UI thread) | ≤ 0.0 ms (the 3D system *does not block* the UI thread; render is on a separate isolate) |
| CPU frame time (render isolate) | ≤ 2.0 ms |
| Total frame budget remaining for foreground 2D | ≥ 10 ms |

These are p99 measurements over 60-second active sessions on reference devices. p100 (worst-frame-ever) may briefly spike during scene load; the load is async and during it the fallback is shown.

## Asset budgets

(Restated from `02-asset-pipeline.md` for one-page reference.)

| Constraint | Limit |
|---|---|
| Triangles per scene | 12,000 |
| Vertices per single mesh | 8,000 |
| UV channels | 2 |
| Materials per scene | 4 |
| Textures per scene | 8 |
| Texture max dimension | 1024 |
| Cubemap face | 256 |
| File size per scene | 800 KB |

## Battery budget

Active 3D scene foreground: ≤ 2.5% / hour additional drain on reference devices, measured at 50% screen brightness, Wi-Fi idle, no other workload.

Background or paused: zero additional drain (renderer is paused, GPU sleeps).

Onboarding: 90 seconds of 3D × 2.5% / hour ≈ 0.06% drain. Acceptable per session.
Profile: average 6 seconds × 30 visits per day ≈ 3 minutes × 2.5% / hour ≈ 0.13% / day. Acceptable.
Space: 30-minute session ≈ 1.25% additional per session. Acceptable. Reduces to ~0.6% with the 30-fps backdrop reduction documented in `05-space-ambient-backdrop.md`.

## Memory budget

| Constraint | Limit |
|---|---|
| Engine baseline (Filament, persistent) | ≤ 6 MB |
| Per-loaded scene resident (geometry + textures + IBL) | ≤ 5 MB |
| Maximum simultaneous loaded scenes | 2 (the visible scene + 1 prefetched) |
| Total 3D RSS | ≤ 16 MB |

When the platform reports memory pressure, all scenes except the currently-visible one are unloaded immediately.

## Auto-downgrade policy

The renderer measures frame time continuously. The downgrade ladder:

| Trigger | Action |
|---|---|
| GPU frame time p99 > 16.6 ms over 30 seconds | Drop drift to 30 fps |
| GPU frame time p99 > 16.6 ms after that, sustained | Pause to static frame, mark scene unhealthy |
| Three "unhealthy" events in one app session | Disable 3D for the rest of this session, route all 3D requests to fallback |
| Six "unhealthy" events across seven days | Disable 3D for this device until the next app version (server-side flag, account-bound) |

The user is not notified of downgrade. The 2D fallback is on-brand and useful; downgrading is silent.

## Capability gating (initial)

Done at app launch, cached for the session.

| Detection | Decision |
|---|---|
| iOS, A12+ | Full 3D |
| iOS, A11 or earlier | 2D fallback |
| Android Vulkan present and `VK_KHR_synchronization2` available | Full 3D |
| Android with GPU score B+ via Filament's compatibility test | Full 3D |
| Android with GPU score C or below | 2D fallback |
| Reduce Transparency on | 2D fallback (regardless of device) |
| Low Power Mode (iOS) / Battery Saver (Android) | 2D fallback |
| Low memory device (< 3 GB RAM) | 2D fallback |
| Web | 2D fallback (always) |

The GPU score is computed by running a 200 ms benchmark on first launch (a known scene rendered at known parameters); we measure frame time and bin into A/B/C/D. The benchmark cost is paid once per device.

## Telemetry (privacy-respecting)

Aggregate metrics, no per-user attribution:
- Per-scene frame stability percentile (p50, p95, p99)
- Cold-load p95
- Auto-downgrade rate per device class
- Memory-pressure unload events per session
- Crash rate of render isolate

Sent through the standard Velix privacy-respecting telemetry pipeline (Phase 7). Tied to anonymous device class, not user.

## CI gating

On every PR touching `assets/3d-source/**`, `packages/velix_3d/**`, or `tools/velix3d/**`:

1. Asset pipeline runs all five scenes; budget violations fail the build.
2. Render benchmark runs on Pixel 6 (cloud device farm) at 60 seconds per scene; p99 frame time recorded; regression > 5% from baseline fails the build.
3. Cold-load benchmark runs; regression > 10% fails the build.
4. Memory benchmark runs; > 20% growth fails the build.
5. Battery soak (10-minute session per scene) runs nightly, not per-PR. Regressions paged to the team.

Reference iPhone 12 testing happens nightly; we do not block PRs on Apple device farm runs because their flakiness is operational drag.

## 2D fallback policy

The 2D fallback is a **PNG image displayed at the substrate (Z-tier 0) of the same surface**. It is not a generic placeholder; it is a per-scene, per-template static image authored by the same designer.

Properties:
- Resolution: 2× device-pixel-ratio.
- Format: optimized PNG (~150 KB typical).
- Color space: sRGB; the runtime applies the same color-correction LUT as the Filament output, so the fallback matches the surrounding 2D UI exactly.
- Aspect ratio: 16:9 wide for landscape contexts, 1:1 square for square contexts. Two assets per scene cover both.

Quality target: a designer reviewing the fallback in isolation should not feel they're looking at a "fallback" — they should feel they're looking at the intended visual. The 3D version adds depth and motion; the 2D version delivers the static composition.

## Failure handling matrix

| Failure | Detection | Response |
|---|---|---|
| Scene asset missing | Manifest lookup returns null | Hard-code default scene, log to crash, fallback shown |
| Asset hash mismatch | Verification fails | Fallback shown, telemetry, no retry |
| Asset signature invalid | Ed25519 verify fails | Hard fail; scene id permanently disabled this session |
| glTF parse error | Loader exception | Fallback shown, telemetry |
| GPU device lost | Vulkan / Metal callback | Engine reset on next foreground; this session uses fallback |
| Render isolate crash | SendPort closed | Fallback for app session, crash reported |
| Frame time sustained > budget | Continuous metric | Auto-downgrade ladder above |
| Memory pressure | Platform notification | Unload all but visible scene |
| OS-level Reduce Motion toggled mid-session | MediaQuery change | Pause to static frame; reload from PNG fallback if needed |
| OS-level Reduce Transparency toggled mid-session | MediaQuery change | Cross-fade to fallback PNG |

## Audit checklist (Phase 3 close)

For each of the three production scenes:

- [ ] Triangles ≤ 12,000
- [ ] Materials ≤ 4
- [ ] Textures ≤ 8 with proper compression
- [ ] File size ≤ 800 KB
- [ ] Cold load ≤ 180 ms on reference iPhone 12
- [ ] GPU frame time p99 ≤ 4 ms on reference iPhone 12
- [ ] GPU frame time p99 ≤ 4 ms on reference Pixel 6
- [ ] Battery cost ≤ 2.5% / hour on reference devices
- [ ] 2D fallback exists, reviewed, on-brand
- [ ] Reduce Motion behavior verified
- [ ] Reduce Transparency behavior verified
- [ ] AT-only experience verified (textual replacement)
- [ ] Color contrast on overlay text ≥ 12:1 (typically AAA for body)
- [ ] Color-blind simulation verified
- [ ] Capability gating tested on a floor device (auto-fallback fires)
- [ ] Auto-downgrade ladder tested via simulated frame stall
- [ ] Memory pressure test passes (large allocation in another app, our engine unloads)
- [ ] No leaks (30-min soak)
- [ ] Render isolate crash recovery works
