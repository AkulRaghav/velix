# Phase 2 — Design System

Status: in progress. Gates Phase 3.

## Carried forward from Phase 1

1. Signature accent decision **deferred** to live mockup review. All three candidates (deep ultraviolet, quartz blue, warm aurora) are fully specified; the Flutter theme exposes a `Brand` enum so any of the three drops in atomically. Phase 3 cannot start until one is locked.
2. Reference `theme.dart` produced with complete token set.
3. Accessibility implementation document added (see `12-accessibility.md`).

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [Design System Overview](./00-design-system-overview.md) | Philosophy, principles, how tokens flow |
| 01 | [Color Tokens](./01-color-tokens.md) | Substrate, accent candidates, neutrals, semantics, trust tints |
| 02 | [Material Tiers](./02-material-tiers.md) | The 4-tier glass + opaque material system |
| 03 | [Typography](./03-typography.md) | Type ramp, optical sizing, language coverage |
| 04 | [Spacing & Grid](./04-spacing-and-grid.md) | 4px baseline, semantic stops, vertical rhythm |
| 05 | [Radius & Shadow](./05-radius-and-shadow.md) | 6-step radius, two-layer shadow system |
| 06 | [Iconography](./06-iconography.md) | Stroke discipline, set inventory, motion bindings |
| 07 | [Motion Grammar](./07-motion-grammar.md) | The 7-pattern motion language |
| 08 | [Z-Tiers](./08-z-tiers.md) | The 4-tier spatial system |
| 09 | [Component Contracts](./09-component-contracts.md) | Every primitive, fully spec'd |
| 10 | [Screen Blueprints](./10-screen-blueprints.md) | All 15 screens, evolved past NexusChat reference |
| 11 | [Phase 2 Audit](./11-phase-2-audit.md) | Self-review, gating Phase 3 |
| 12 | [Accessibility](./12-accessibility.md) | WCAG 2.2 AA implementation, AT behavior |

## Reference implementation

`packages/velix_design/lib/theme.dart` — complete Flutter token set as `ThemeExtension`s, ready for Phase 5 to consume without re-derivation.

## Reading order

If you have ten minutes: 00 → 10 → 11.
If you're implementing a screen: 09 → 10 → theme.dart.
If you're auditing: 11 → 12 → everything else.
