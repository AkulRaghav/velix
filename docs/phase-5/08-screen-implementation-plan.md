# 08 — Screen Implementation Plan

The 15 screens from Phase 2's `10-screen-blueprints.md`. Phase 5 ships a meaningful subset to **production quality**, with the rest as **scaffolds**: real screens with the design system applied and the data flow wired, but missing the long-tail of edge cases that Phase 6+ will address. Every screen is functional; the differentiator is depth.

## Tier

| Tier | Description |
|---|---|
| **A — production hero** | Fully implemented to the Phase 2 blueprint; passes the per-screen audit checklist; CI golden test |
| **B — production functional** | All flows work, all states render, but secondary features (search-within, swipe actions, etc.) may be deferred |
| **C — scaffold** | Screen renders, data flow is wired, design system applied; remaining work is documented in TODO blocks pointing to Phase 2 spec |

## Phase 5 assignment

| # | Screen | Tier | Notes |
|---|---|---|---|
| 1 | Splash | A | Single hero moment; no data dependency |
| 2 | Onboarding | A | 3 steps, 3D scenes wired (placeholders → Phase-3 assets) |
| 3 | Login / Identity | A | Identity creation flow + biometric unlock stub |
| 4 | Home Feed | C | Feed product itself is post-1.0 in Phase 1 roadmap; we render an empty-state and the design |
| 5 | Chats (list) | A | The most-visited surface |
| 6 | Conversation | A | The largest single screen; full E2E flow with stub gateway |
| 7 | Voice Message | B | Recording overlay; envelope generation stubbed (real audio in Phase 6) |
| 8 | Stories | C | Player skeleton; full implementation at story-feature go-live |
| 9 | Profile | A | Identity scene placeholder + edit flow |
| 10 | Notifications | B | Render notifications from local DB; grouping done |
| 11 | Explore | C | Discovery is post-1.0 in roadmap; we render the design's empty states |
| 12 | Settings | A | Hierarchy, navigation, all toggles wired |
| 13 | Privacy | A | Hero card with custom shield glyph + toggles |
| 14 | Video Call | C | Scaffold of the call surface; LiveKit wiring in Phase 6 |
| 15 | AI Assistant | B | Bottom-sheet shell + AIStreamingText hooked up to a stub model |

**Tier A: 7 screens. Tier B: 3 screens. Tier C: 5 screens.** Each Tier-C screen has a clear "what's missing" comment block with a link to the Phase 2 blueprint.

## Per-screen audit checklist (Tier A)

Every Tier-A screen must:

- [ ] Compose only `velix_design`, `velix_motion`, `velix_3d`, and our component library
- [ ] Use ≤ 4 Z-tiers
- [ ] Use ≤ 3 type sizes
- [ ] Have one signature accent application
- [ ] Honor 24 px screen edge inset (or per-screen rule)
- [ ] Have Reduce-Motion variant verified
- [ ] Have Reduce-Transparency variant verified
- [ ] Pass the contrast verification grid for its overlays
- [ ] Use motion patterns from the seven only
- [ ] Have a `Semantics` tree fully composed (no leaks)
- [ ] Have a golden test for the steady state
- [ ] Have a smoke test for at least three states
- [ ] Hide / show the floating nav per the navigation rules
- [ ] Hold no app state in `setState`
- [ ] Have a documented Riverpod provider graph
- [ ] Have a frame-time bench in CI proving 99% inside 16.6 ms

A Tier-A screen that fails any item above is downgraded to Tier B until the item is fixed.

## Per-screen audit checklist (Tier B)

Tier B drops:

- The golden test (smoke only)
- The frame-time bench (developer-side spot check only)
- The full state-coverage smoke test (basic open/close coverage)

Otherwise identical.

## Per-screen audit checklist (Tier C)

Tier C requires:
- Renders with the design system applied
- Has documented `// TODO(phase-N):` comments referencing Phase 2 blueprints
- Empty / skeleton state visible if data is missing
- Smoke test confirms it pumps without throwing

## Component library

Phase 5 implements the components from Phase 2's `09-component-contracts.md`:

| Component | Tier |
|---|---|
| Button | A |
| Input | A |
| GlassCard | A |
| MessageBubble | A |
| Toggle | A |
| Loader | A |
| Modal (delegated to `VelixModal` in `velix_motion`) | A |
| BottomSheet (delegated to `VelixSheet`) | A |
| FloatingNav | A |
| RoomBackdrop | A |
| TrustMaterial | A |
| Spotlight | B |
| AmbientPresence | A |
| WaveformPlayer (delegated to `Waveform` in `velix_motion`) | A |
| ReactionPicker | A |
| IdentityCapsule | A |

All Tier-A. There is no scaffolded component — components must be production from day one because every screen depends on them.

## Asset wiring status

Phase 5 ships:
- The `velix_design` font assets (Inter variable + JetBrains Mono + Vazirmatn + Noto Sans CJK)
- The `velix_motion` realtime widgets (already complete)
- **Placeholder** `.velixscene` files (single-color PNGs in their fallback slot) for the 3D registry — Phase 5 does not author the actual 3D content
- **Placeholder** `.riv` files for the eight glyphs — Phase 5 ships the registry

The `VelixGlyph` widget gracefully falls back to a static SVG (or a unicode symbol) when its `.riv` is missing. This is documented and tested.

## Settings hierarchy

Settings (Tier A) is the most-tested-by-AT screen. Its hierarchy:

```
/profile/settings
├── Privacy & Security        ← hero
├── Devices                    ← list
├── Notifications              ← per-thread defaults
├── Display
│   ├── Theme (dark / light placeholder)
│   ├── Reduce 3D backdrops
│   ├── Reduce parallax
│   └── Disable identity scenes
├── Accessibility
│   ├── Long-press threshold
│   ├── Tap cancellation
│   ├── Pull-to-refresh threshold
│   └── Captions
├── AI
│   ├── On-device only / cloud opt-in
│   ├── Quota meter (when cloud)
│   └── Reset assistant memory
├── Storage
│   ├── Cache used (cleanable)
│   └── Backup
├── Account
│   ├── Handle
│   ├── Email
│   └── Sign out / delete
└── About
    ├── Version
    ├── Open source licenses
    └── Privacy / security paper
```

Each entry is a `VelixSettingsCell` composed from the component library.

## Banned

- Per-screen invented motion (use the seven).
- Per-screen invented colors (use semantic tokens).
- Per-screen `setState` for app state.
- Per-screen `BottomSheet.show*` (use `VelixSheet`).
- Direct route strings (use typed `go_router` route data).
- `setState` after async gap without `if (mounted) return`.
- Hard-coded English strings outside `error_messages.arb` and `app.arb`.
