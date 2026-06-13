# 07 — Accessibility (3D)

The 3D system is accessibility-first the same way the rest of the design system is. The product is fully usable, equally usable, and on-brand without 3D ever rendering.

## Three states

| State | Trigger | What the user sees |
|---|---|---|
| Full 3D | Default on capable devices | The animated scene with parallax + drift |
| Static 3D | Reduce Motion on | A single static frame of the scene; no drift, no parallax |
| 2D substrate | Reduce Transparency on, low-end device, or user opt-out | The fallback PNG only — no 3D engine running |

All three states present the same composition (the scene's hero arrangement). They differ only in motion fidelity.

## Reduce Motion (iOS) / Remove Animations (Android)

Detected via `MediaQuery.of(context).disableAnimations`.

When on:
- Drift is disabled. Scene shows initial pose.
- Tilt parallax is disabled. Scroll parallax remains because it's gesture-driven.
- Cinematic reveals collapse to a 200 ms cross-fade.
- Scene transitions (between onboarding steps) become 200 ms cross-fades of the *2D fallbacks* — we don't load the 3D engine at all.

The scene's static frame is identical to the 2D fallback PNG. This guarantees consistency between Reduce-Motion users and Full-3D users in terms of layout and overlay positioning.

## Reduce Transparency (iOS) / Increase Contrast (Android)

Detected via `MediaQuery.of(context).highContrast`.

When on:
- The 3D engine is not initialized for any scene.
- Each surface uses its 2D fallback PNG as the substrate.
- Overlay text (the 2D type at Z2) is rendered against the fallback with the same contrast guarantees as against full 3D — verified per scene that contrast ≥ 12:1 across the entire surface.

This mode is fully equivalent in usability and information.

## Low Power Mode

Detected via `Battery` plugin.

Equivalent to Reduce Transparency (2D fallback). User-facing: zero indication; the 3D simply does not appear and the device's battery is preserved.

## Capability fallback

For users on devices below the 3D capability bar, every 3D surface always shows the 2D fallback. This is permanent for that device until the user upgrades hardware. We do not nag.

## VoiceOver / TalkBack behavior

3D scenes are decorative; they do not carry semantic information. The accessibility tree handles this explicitly:

- Each `VelixSceneWidget` exposes a single `Semantics` node with `label: "<surface name> background scene"` and `excludeSemantics: true` for child nodes.
- AT users hear, e.g., "Onboarding step 1, background scene" — once, on screen entry. The textual content of the scene (heading, body, CTA) is announced separately by the foreground 2D Semantics.
- For the profile identity scene, the announcement is "[user name] profile identity" so AT users understand it's their personal scene. The selection of style is exposed in Settings → Profile as a labeled list.

We do **not** describe the visual content of the scene to AT users. The scene is a feeling, not a sentence. AT users get the same identity-affirming role from the textual identity card below the scene.

## Switch Control / Voice Access

3D scenes have no interactive elements. They are excluded from focus traversal. Switch and Voice users skip them implicitly.

The eight identity styles are selectable from a labeled `BottomSheet` in Profile → Edit; each style's name is announced ("Quartz, the default — calm and technical"). No pictorial-only selection.

## Color contrast on scene overlays

For each scene, the foreground 2D type is verified to have ≥ 12:1 contrast against the entire scene surface, sampled at 32×32 grid points across the active scene area.

If a scene template would fail this for a given user (e.g., they pick a custom room tint that washes out), the runtime applies a `gradient.veil` (the same one from `01-color-tokens.md`) at the bottom 30% of the surface to guarantee text legibility. The veil is barely perceptible; it costs no GPU and saves a contrast emergency.

## Vestibular / motion sensitivity

Drift periods are deliberately slow (18–48 s) so the motion is below the threshold that triggers vestibular discomfort for most sensitive users. Even so:

- Reduce Motion is honored without any user action beyond the OS toggle.
- The full opt-out ("Disable 3D entirely") in Settings → Display sits alongside Reduce Motion in the design.
- We do not auto-enable parallax above a fixed amplitude; parallax is bounded.

## Per-user opt-outs

In Settings → Display:
- "Disable 3D backdrops in Spaces" (default: off — backdrops only appear when Space owners enable them anyway)
- "Disable profile identity scenes" (default: off)
- "Reduce parallax" (default: respects OS Reduce Motion; can be force-on)

These are device-local; the server never sees them. They take effect immediately without app restart.

## Photosensitivity

We do not produce flashing, strobing, or rapidly-shifting imagery in any scene. Filament tone mapping ensures gradual lighting transitions. The dawn intensification in onboarding scene 3 ramps over 1.6 seconds (slow enough to be safe by WCAG 2.2 SC 2.3.1 standards).

The asset pipeline includes a "flash detection" check that rejects any scene where global luminance changes more than 30% within 200 ms. Reasonable defense in depth.

## Internationalization

3D scenes have no text in them. They are language-neutral by construction. The 2D type overlay handles all localization.

For RTL languages (Arabic launches at 1.0):
- The scene's parallax tilt direction is mirrored.
- The 2D overlay is positioned per `TextDirection`.
- The cinematic reveal direction (e.g., scene 3's camera dolly) is mirrored where directional.

## Audit checklist (Phase 3 close)

- [ ] Reduce Motion behavior verified for each scene
- [ ] Reduce Transparency behavior verified for each scene
- [ ] Capability fallback verified on Pixel 4a (low-end Android)
- [ ] Low Power Mode behavior verified on iPhone 12
- [ ] AT (VoiceOver and TalkBack) traversal verified — scene announced once, no leaks
- [ ] Switch Control verified — scenes skipped
- [ ] Contrast ≥ 12:1 sampled across each scene with overlay text
- [ ] Photosensitivity check passes for each scene
- [ ] User opt-outs functional and persistent
- [ ] RTL mirroring verified for parallax and reveal directions

## Public commitment

Velix's accessibility statement (published at `velix.app/accessibility`) names 3D as decorative and confirms full feature parity for Reduce-Motion and Reduce-Transparency users. We will not let "look how cool the 3D is" reviews quietly hide the fact that a meaningful fraction of our users will never see it.
