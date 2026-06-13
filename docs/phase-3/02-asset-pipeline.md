# 02 — Asset Pipeline

The pipeline that turns a designer's 3D file into a runtime-ready scene asset shipping inside the app bundle.

## Source format

Designers author in **Blender** (preferred) or **Cinema 4D**, exporting to **glTF 2.0**. We do not accept FBX, OBJ, USD, or proprietary formats as sources. (USDZ may be revisited in v2 for Vision Pro authoring; not 1.0.)

We maintain a **Velix Source Library** in `assets/3d-source/` checked into the monorepo. Each scene has:

```
assets/3d-source/onboarding/step1/
  scene.blend          ← editable source, never shipped
  scene.gltf           ← exported, the pipeline input
  scene.bin            ← geometry buffer
  textures/            ← raw 4K PNG sources
  ibl/                 ← raw .hdr environment
  scene.meta.yaml      ← scene metadata (parallax, drift, fallback color, etc.)
```

## Pipeline stages

```
  source (.gltf + textures + .hdr)
      │
      ▼
  validate          (schema, polygon count, texture sizes, naming)
      │
      ▼
  optimize geometry (Draco compression, vertex dedup, mesh quantization)
      │
      ▼
  optimize textures (downsample to target, color space tag, BasisU encode → KTX2)
      │
      ▼
  bake IBL          (HDR → SH coefficients + reflection cubemap, KTX2)
      │
      ▼
  bundle            (.velixscene single file, content-addressed)
      │
      ▼
  sign              (Ed25519 over the bundle hash)
      │
      ▼
  budget audit      (file size, polygon count, draw-call estimate)
      │
      ▼
  ship              (assets/3d-built/<scene-id>.velixscene)
```

Every stage is a CLI subcommand of `tools/velix3d/`, written in Dart so it lives in the monorepo without a separate toolchain. Stages run in CI on every change to `assets/3d-source/`.

## Format on disk: `.velixscene`

A `.velixscene` is a deterministic ZIP container with a strict layout:

```
manifest.json     ← scene id, format version, asset hashes, signature
scene.glb         ← optimized binary glTF
ibl.ktx          ← Filament-format IBL (SH + reflection cubemap)
fallback.png     ← 2x resolution PNG of the static-frame fallback
metadata.json    ← parallax, drift, camera, exposure
```

`manifest.json` carries an Ed25519 signature over the SHA-256 of every other file. The runtime verifies the signature on load. Tampered or partial assets are rejected and the 2D fallback is shown.

## Polygon and texture budgets, enforced

The pipeline rejects assets exceeding:

| Constraint | Limit | Reason |
|---|---|---|
| Total triangles | 12,000 | GPU vertex shader ceiling on reference devices |
| Vertices (any single mesh) | 8,000 | sub-buffer compatibility |
| UV channels | 2 | albedo + lightmap |
| Materials per scene | 4 | Filament material compile cost |
| Textures per scene | 8 | total |
| Texture max dimension | 1024 px | sample budget on mid-tier mobile GPU |
| HDR cubemap face dimension | 256 px | Filament IBL guidance |
| Shipped file size (.velixscene) | 800 KB | per-scene cap |

A polygon count over budget fails CI with a hard error and an explicit "your scene has X triangles, budget is 12,000" message. Texture violations the same. We do not ship "almost OK" assets.

## Texture handling

- Albedo: BasisU-compressed in KTX2; sRGB color space; UASTC at quality 1 (best).
- Normal: KTX2 RG-only; linear color space; UASTC.
- Roughness/metallic: combined RM-channel KTX2; linear; UASTC.
- Ambient occlusion (when separate): single-channel KTX2; linear.

We do not ship per-platform texture variants. KTX2/BasisU transcodes at load time to ETC2 (Android) or ASTC (iOS, modern Android) using `basis_universal`. Transcode cost is < 30 ms per texture on reference devices, off the UI thread.

## IBL baking

Source HDR (`.hdr` from designer) is baked offline using Filament's `cmgen` tool to:
- 9 spherical harmonic coefficients (diffuse environment)
- 256² roughness-prefiltered reflection cubemap (specular environment)

These are stored together in a single `.ktx` produced by `cmgen`. The asset pipeline wraps `cmgen` as a stage and records the parameters used.

## Fallback bitmap

Each scene ships with a `fallback.png` — a 2× resolution PNG of the scene rendered at its initial pose. This is the image shown when:
- 3D is unavailable (Reduce Transparency, low-power mode, web, low-end device)
- The scene is loading
- The scene reports unhealthy

The fallback is generated automatically by the pipeline (a headless render at 2× device pixel density), then hand-tuned by the designer in Photoshop or equivalent if needed (small tonal adjustments only). The hand-tuned version replaces the auto-generated one and is checked into source.

The fallback is roughly the same size budget as a hero photo: ≤ 200 KB.

## Versioning and content-addressing

Each `.velixscene` carries a content hash in its filename:

```
assets/3d-built/onboarding-step1.<sha256:8>.velixscene
```

The app's scene registry maps `SceneId` to filename + expected hash. A mismatch at runtime is a hard failure that triggers the 2D fallback and reports telemetry. Hash mismatches in production are extraordinarily rare but real (corrupted download, partial OTA update); we handle them quietly.

## Reproducibility

The pipeline must produce **bit-identical output** for the same input. CI verifies this by running the pipeline twice on every change and comparing outputs. Reproducibility prevents "it works on my machine" asset bugs and enables clean auditing of what actually ships in the binary.

## Designer workflow

A designer modifies `scene.blend`, exports glTF, runs:

```
$ tools/velix3d/cli build assets/3d-source/onboarding/step1
```

The CLI:
1. Validates the source.
2. Reports any budget violation with actionable text ("your scene is 13,400 triangles; over budget by 1,400; consider decimating the back wall").
3. Builds the `.velixscene`.
4. Updates the registry.
5. Optionally generates a 30-second video preview for design review (using the Filament desktop renderer).

A `--dev` flag skips signing and ships the asset to a side directory the dev build picks up automatically. Production builds always use signed assets.

## Naming and registry

The registry (Dart enum + map) is the only place scene ids are listed:

```dart
enum SceneId {
  onboardingStep1,
  onboardingStep2,
  onboardingStep3,
  profileIdentity,
  spaceAmbient,
}

final Map<SceneId, SceneAssetRef> sceneRegistry = {
  SceneId.onboardingStep1: SceneAssetRef(
    path: 'assets/3d-built/onboarding-step1.<hash>.velixscene',
    expectedSha256: '...',
    fallbackAsset: 'assets/3d-built/onboarding-step1.fallback.png',
  ),
  // ...
};
```

Adding a new scene means adding a registry entry and a built asset. The codebase will lint against any reference to a `.velixscene` not in the registry.

## CI

On every PR touching `assets/3d-source/**`:
1. Pipeline runs all five scenes.
2. Budget audit runs; any violation fails the build.
3. Reproducibility check runs (build twice, compare).
4. Visual regression: render the fallback and the first 0.5 s of ambient drift, compare against golden images via SSIM > 0.99 threshold.

On a run touching `packages/velix_3d/**` only:
- Unit and integration tests run; no asset regen.
