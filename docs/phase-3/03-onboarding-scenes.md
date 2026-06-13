# 03 — Onboarding Scenes

Three steps, three scenes. Used during first-run only; subsequent app launches never load these. Total budget for the three combined: ≤ 540 KB on disk, ≤ 12 ms cold-start cost (one initial load, then cross-fade between cached scenes).

The scenes set the brand voice. The user has 90 seconds with them — they need to feel intentional in every frame.

## Scene 1 — "Yours, end to end."

Theme: trust, dawn light, slow gravity.

### Composition

A single quartz-blue (`#3478F6`) crystalline form, faceted, occupying the center 60% of the frame. The form sits on an implied horizon — a barely-visible plane reflecting the form at low contrast. The substrate gradient (Quartz Blue → deep navy) backs the scene with sub-pixel grain to defeat OLED banding.

The form has 12 facets, deliberately irregular (not a regular icosahedron). This makes it feel hand-crafted rather than generated.

### Geometry

- Crystal: 1,800 triangles
- Implied horizon plane: 4 triangles
- Total: **1,804 triangles** (well under 12k budget)

### Materials

- Crystal: PBR — base color signature accent (`#3478F6`), metallic 0.05, roughness 0.18, transmission 0.2 (slight refraction). Single albedo + normal + roughness texture, all 512².
- Plane: dark gradient, no PBR (single flat material).

Material count: **2** (under 4 budget).

### Lighting

- IBL: a custom HDR baked from a curated "dawn studio" environment. Predominantly cool with a warm rim from camera-right. 256² cubemap.
- Fill light: a single warm directional (5500K) at -45° azimuth, 25° elevation, intensity 0.4. Adds the rim that catches the crystal's right facets.
- No real-time shadows.

### Camera

- FOV 32° (slightly telephoto, gives the crystal weight)
- Position: 2.4 m from origin, at 12° elevation
- Target: origin (the crystal's center of mass)
- Tone mapping: ACES, exposure -0.3 stops (slight crush in shadows)

### Motion

- **Drift:** crystal rotates around its vertical axis at one revolution per 32 seconds. Sine-wave damped at the start so it eases into motion as the scene appears.
- **Parallax:** tilt-factor 0.18 (subtle), scroll-factor 0 (no scroll on onboarding scenes).
- **Cinematic reveal:** on first frame, crystal scales 0.92 → 1.00 over 600 ms via `motion.cinematicReveal`, with a synchronized 600 ms fade-in of the IBL exposure (-1.5 → -0.3 stops), simulating dawn arriving.

### Type overlay (2D, Z2)

- Display.M: "Yours, end to end."
- Body.L: "Velix is built on Signal-grade encryption. Your messages are readable only by you and the people you message."
- Bottom: a quiet "Continue" CTA at `type.label.l`.

### Fallback (2D)

The fallback PNG is the scene rendered at its initial pose (after the cinematic reveal completes), 2× retina, ~120 KB. It carries the same emotional weight in 2D.

### Budget realized

| Constraint | Budget | This scene |
|---|---|---|
| Triangles | 12,000 | 1,804 |
| Textures | 8 | 4 (albedo, normal, roughness, IBL cubemap) |
| Texture memory | 16 MB | 1.4 MB |
| File size | 800 KB | est. 220 KB |
| GPU frame time | 4 ms | est. 1.6 ms (iPhone 12) |

---

## Scene 2 — "Calm by default."

Theme: notification quiet, floating rooms, ambient depth.

### Composition

Five "rooms" — translucent, frosted glass forms — drift slowly in a loosely vertical column. Each room is a simple rounded rectangle prism (think a softened iPhone-shaped tile, edge-on to camera). They have a subtle internal pulse of the conversation room palette (four of the twelve room colors are used: mist, sage, iris, sand).

The rooms occupy the right two-thirds of the frame, leaving the left third for type overlay.

### Geometry

- 5 rooms × 80 triangles each (rounded prism, low-poly with smoothed normals): 400
- Background plane: 4
- Total: **404 triangles**

### Materials

- Room (one shared material with per-instance color override via `KHR_materials_variants`): translucent PBR, transmission 0.6, roughness 0.4. The translucency gives the rooms a frosted-glass feel that matches the 2D material tier system.
- Background: gradient.

Material count: **2**.

### Lighting

- IBL: a softer, neutral environment ("white-room studio"). 256² cubemap. Less directional than scene 1.
- Fill: a single cool directional (8000K), low intensity 0.2, simulating ambient sky reflection on the rooms.

### Camera

- FOV 28°
- Position 3.0 m, slight 5° elevation
- Slowly orbits around vertical at 0.3°/s (so over a 24-second drift period, 7° of arc — barely perceptible)

### Motion

- **Drift:** the five rooms float vertically with offset phases (each room is offset by 0.2 of the period from the next). Period 24 s. Amplitude 8 cm in scene-space (~0.04 of the room's height).
- **Parallax:** tilt-factor 0.22.
- **Cinematic reveal:** rooms appear staggered, one every 80 ms over 400 ms, each via a fade + 0.95 → 1.00 scale.

### Type overlay (2D)

- Display.M: "Calm by default."
- Body.L: "We respect your attention. Notifications are quiet unless you mark a thread as Priority. No badge dots, no streaks."
- Bottom: "Continue."

### Fallback

PNG at the moment all rooms have completed their reveal. ~140 KB.

### Budget realized

| Constraint | This scene |
|---|---|
| Triangles | 404 |
| Textures | 3 (translucent material + IBL cubemap + roughness LUT) |
| Texture memory | 1.0 MB |
| File size | est. 180 KB |
| GPU frame time | est. 1.4 ms |

---

## Scene 3 — "Let's begin."

Theme: identity, commitment, dawn intensifies.

### Composition

A single horizon line — flat, warm, a Quartz Blue gradient sky meets a near-black plane. From below the horizon, a slow dome of warm light rises (a single hemisphere of soft radiance, not the sun). On the plane, a small cluster of three subtly-textured "stones" sit in foreground — abstract, low-poly, suggesting permanence.

The composition is intentionally still. It pays off the user's commitment to creating their identity by feeling like *arrival*.

### Geometry

- Horizon plane: 4 triangles
- Light dome: 1,200 triangles (low-poly hemisphere)
- 3 stones, ~600 triangles each: 1,800
- Total: **3,004 triangles**

### Materials

- Plane: simple matte
- Dome: emissive only (no PBR shading; we light it directly)
- Stones: PBR with shared albedo + normal + ao, 512² textures

Material count: **3**.

### Lighting

- IBL: a "dawn rising" environment baked specifically for this scene, with strong warm light below the horizon line and cool above. 256².
- Fill: a single warm directional (3500K, sunrise-y), tracking the dome's center.

### Camera

- FOV 24° (more telephoto, a contemplative focal length)
- Position: 3.6 m back, low elevation 4° (almost horizon-aligned)
- Static for the first 2 seconds, then a 6 mm horizontal dolly over the next 12 s — almost imperceptible, gives the scene literal arrival.

### Motion

- **Drift:** dome's intensity slowly increases from 0.35 → 0.55 over 8 s, then holds. The horizon line's brightness rises proportionally. Stones do not move.
- **Parallax:** tilt-factor 0.10 (very subtle — the scene is nearly still).
- **Cinematic reveal:** scene starts dark; over the first 1.6 s the IBL exposure rises from -2.0 stops to -0.4 (the dawn). Synchronized with the type appearing.

### Type overlay (2D)

- Display.M: "Let's begin."
- Body.L: "Create your cryptographic identity. It's yours, generated on this device, and it never leaves you."
- Bottom: a primary CTA "Create my identity" at `type.label.l`.

### Fallback

PNG at the post-dawn state. ~160 KB.

### Budget realized

| Constraint | This scene |
|---|---|
| Triangles | 3,004 |
| Textures | 5 |
| Texture memory | 2.8 MB |
| File size | est. 280 KB |
| GPU frame time | est. 2.0 ms |

---

## Total onboarding 3D budget

| Constraint | Budget | All three scenes |
|---|---|---|
| Disk | 800 KB × 3 | est. 680 KB |
| Texture memory (peak, only one resident at a time) | 16 MB | 2.8 MB |
| Cold start (first scene only — others lazy-loaded during step 1) | 180 ms | est. 80 ms |
| Battery (90s onboarding session) | 0.06% expected drain | acceptable |

## Transition between scenes

Step transitions happen via a 380 ms `motion.lateral` of the 2D type overlay layer combined with a cross-fade of the 3D scene (next scene fades in over 240 ms, previous fades out 180 ms; overlap by 100 ms). The previous scene is paused immediately on cross-fade start to free GPU.

## Reduce Motion behavior

- Drift disabled (scene shows initial pose statically).
- Parallax disabled.
- Cinematic reveal collapses to a single 200 ms cross-fade.
- Step-to-step transitions become a 200 ms cross-fade of the 2D fallback PNGs only — the 3D scene loader is skipped entirely.

## Reduce Transparency behavior

- All three scenes replaced by their 2D fallback PNGs as the substrate.
- The PNGs are designed to read as on-brand without 3D — the crystal in scene 1 reads as a distinctive flat illustration, etc.

## Authoring notes for the designer

- Scenes are authored in Blender 4.0 Cycles with a 256-sample baked path-trace as reference, then ported to Filament's PBR by hand-tuning parameters.
- Each scene has a checked-in test-render at 4K that documents the intended look. Implementation matches the test-render to ΔE2000 < 4 under standardized lighting.
- We never ship a scene that the designer has not signed off on against the test-render.
