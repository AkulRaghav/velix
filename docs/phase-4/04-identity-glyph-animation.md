# 04 — Identity Glyph Animation (Rive)

The eight custom identity glyphs from Phase 2's `06-iconography.md`. Authored in Rive 2.0 (state-machine version). Loaded via a registry; consumed via a single `VelixGlyph` widget.

This is the only place in Velix where Rive is used. The boundary is deliberate.

## The eight glyphs

| # | Glyph | States | Triggers |
|---|---|---|---|
| 1 | Velix mark | `idle` (no motion) | none — splash widget invokes one-shot reveal |
| 2 | Identity key | `idle`, `creating`, `created` | identity-creation flow advances state |
| 3 | Room | `idle`, `entering`, `entered` | user opens / leaves a Space |
| 4 | AI assistant spark | `idle`, `thinking`, `responding` | AI gateway state changes |
| 5 | Voice mic | `idle`, `listening`, `paused` | recording state |
| 6 | Call connect / call end | `connecting`, `connected`, `ending`, `ended` | LiveKit call lifecycle |
| 7 | Story | `unwatched`, `watching`, `watched` | viewer state |
| 8 | Encryption shield | `verified`, `standard`, `unverified`, `rekeyed` | trust-state state machine |

Each glyph is a single `.riv` artboard with a state machine and a typed Dart enum mirroring its states.

## Authoring contract

Designers authoring `.riv` files must:

- Use only the colors from `velix_design` semantics. We expose accent + text + semantic colors as Rive view-model inputs the runtime injects, so the glyph's color follows the brand at runtime, not at authoring time.
- Use only the seven Phase-2 motion patterns as transition timing references. State transitions match the system's curve / spring grammar.
- Stay inside 24×24 logical-pixel artboards (matching `06-iconography.md`'s 24-grid).
- Provide a single Bold-weight artboard when the glyph supports a Bold state; no separate Regular file.
- Author all transitions to be **interruptible** — re-entering a state midway through transition does not pop or restart; Rive 2's state machine handles this if authored correctly.
- Provide a static-frame variant per state for Reduce-Motion users (Rive supports this via a "static" state machine input).

## Runtime contract

```dart
VelixGlyph(
  glyph: VelixGlyphId.encryptionShield,
  state: TrustGlyphState.verified,
  size: 24,
  weight: GlyphWeight.regular, // or .bold
)
```

The widget:

1. Loads the `.riv` file from a content-addressed registry the first time the glyph is requested. Subsequent uses share the cached artboard.
2. Maps the typed state to the Rive state-machine input.
3. Transitions occur via the state machine's authored timing.
4. Honors `MediaQuery.disableAnimations` — when on, the artboard is forced to its static state for the requested logical state.
5. Honors `MediaQuery.highContrast` — when on, switches to a higher-contrast variant if the glyph provides one (encryption-shield's `rekeyed` becomes a 2-px solid stroke instead of the tremor).

## Why Rive (and not hand-coded)

For these eight specifically:

- They're character-motion: the glyph itself has personality and timing that benefits from a designer's direct control.
- They have multiple states with crafted transitions; hand-coding each transition is expensive and easy to get visually wrong.
- Designers iterate without engineering involvement.

For everything else, hand-coded wins on integration with Phase 2 tokens, Phase 4 springs, and Phase 9 haptics.

## Why not Lottie

We considered Lottie. Rejected because:

- Lottie is After-Effects-shaped; designers without AE struggle.
- Lottie state machines are bolted on; Rive's are first-class.
- Rive's runtime is smaller (~1.4 MB vs ~2.0 MB) and faster on mobile.
- Rive natively supports view-model inputs that we use to inject brand colors.

## Asset budget

Each glyph:
- File size: ≤ 18 KB compressed `.riv`
- Vertices in any single shape: ≤ 200
- States: ≤ 6
- Transitions: ≤ 20

The eight glyphs combined: ≤ 144 KB total. CI lint enforces.

## Asset pipeline

`.riv` files live in `assets/glyphs/source/`. The Phase-3 asset pipeline (`tools/velix3d`, generalized to `tools/velix_assets`) gains a Rive stage:

```
source (.riv from designer)
    ↓
validate (state machine input names match enum, color inputs only from semantics)
    ↓
optimize (Rive's CLI compress)
    ↓
sign (Ed25519 over hash)
    ↓
ship (assets/glyphs/built/<id>.<sha8>.riv)
```

The registry maps `VelixGlyphId` to filename + expected hash, parallel to the Phase-3 scene registry.

## Banned

- Authoring colors directly in the `.riv` (must use view-model inputs).
- States outside the documented enum per glyph.
- Transitions longer than 480 ms (the longest Phase-2 grammar except cinematic reveal).
- Idle "breathing" or rotation in any glyph's `idle` state.
- Loops in `idle` — only state transitions are animated.
- Audio in glyphs.
- Text inside glyphs.
- Customization beyond the documented inputs.

## Glyph integration with materials

Two glyphs interact with material:

1. **Encryption shield's `rekeyed` state** — the state machine drives the shield's outline opacity in pulse, which is composed in widget code with the conversation surface's `material.modifier.tremor`. The combined effect is the sustained ambient signal documented in Phase 2.

2. **Voice mic's `listening` state** — the glyph itself does not animate the recording-button halo; the halo is owned by the `Waveform` widget's parent. The mic glyph state changes color tone via accent inputs.

This separation prevents the glyph from being a self-contained "box" the rest of the system can't reach into.

## Performance contract

Per-glyph at any visible size:

- Paint cost: ≤ 0.2 ms / frame on iPhone 12
- Memory: ≤ 200 KB resident per loaded artboard
- Disk: ≤ 18 KB per file

A surface with ten visible glyphs (chat list with verified-shield on each cell) costs ≤ 2 ms / frame total.

## Accessibility

All glyphs are decorative when they appear next to descriptive text. They are *informative* only when they carry meaning the text doesn't.

| Glyph | Decorative or informative? |
|---|---|
| Velix mark | decorative (splash) |
| Identity key | informative (identity flows; AT label "Identity key") |
| Room | decorative (rooms have names beside them) |
| AI assistant spark | informative ("AI assistant") |
| Voice mic | informative ("Recording" / "Listening" / "Paused") |
| Call connect/end | informative ("Connect call" / "End call") |
| Story | informative ("Unwatched story" / "Watched story") |
| Encryption shield | informative ("Encryption verified" / "Encryption standard" / "Encryption unverified" / "Encryption changed") |

Informative glyphs always have a `Semantics(label: ...)` attached and never rely on the visual alone.

## Reduced-motion variants

Each `.riv` has a Reduce-Motion variant baked in. When `MediaQuery.disableAnimations` is true:

- Static glyph for `idle` and steady states.
- Transitions become 120 ms cross-fades between static frames (Rive supports this directly).
- The encryption shield's tremor is replaced by a single subtle outline shift (not animated; just a different static asset).

## Phase 5 follow-up

Phase 4 ships the `VelixGlyph` widget contract and the registry mechanism with placeholder assets. Phase 5 ships the actual `.riv` files authored by the designer.
