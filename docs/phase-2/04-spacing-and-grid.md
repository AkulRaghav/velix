# 04 — Spacing & Grid

Spacing is invisible until it isn't. The single most reliable signal of an undisciplined UI is uneven spacing — gaps that don't relate to each other rationally. We define spacing as a small, named, mathematical scale and then we use only those values.

## Baseline

A **4-logical-pixel baseline grid** governs all vertical rhythm. Every text top-edge, every component height, every gap is a multiple of 4.

We do not use 1 px or 2 px gaps anywhere in the system except for hairline borders.

## Scale

```
space.0    0
space.1    2     micro — only for compensating optical alignment
space.2    4     baseline unit, internal text padding
space.3    6     rare — for inset adjustments inside Tier-3 material
space.4    8     primary inline gap, icon-to-label
space.5   12     compact stack
space.6   16     standard stack, list cell vertical padding
space.7   20     section internal padding
space.8   24     section gap, card internal padding
space.9   32     screen edge inset (default)
space.10  40     hero spacing in onboarding
space.11  48     between-section spacing
space.12  64     screen-top spacing on hero surfaces
space.13  80     reserved for cinematic moments only
```

Numbers between these stops do not exist. A designer asking for 14 px is asking for either 12 or 16; the answer is whichever is closer to the *intent*.

## Semantic stops

Components reach for semantic names, not raw numbers. The semantic table is the contract; the raw numbers are the implementation.

| Semantic | Value | Used for |
|---|---|---|
| `space.inset.xs` | 4 | Tightest internal padding |
| `space.inset.sm` | 8 | Compact controls |
| `space.inset.md` | 12 | Standard control internal |
| `space.inset.lg` | 16 | Card / sheet internal padding |
| `space.inset.xl` | 24 | Section internal padding |
| `space.stack.xs` | 4 | Icon-to-label vertical |
| `space.stack.sm` | 8 | Tight stack |
| `space.stack.md` | 12 | Default stack |
| `space.stack.lg` | 20 | Section internal stack |
| `space.stack.xl` | 32 | Section-to-section |
| `space.gutter.screen` | 24 | Screen edge inset (mobile) |
| `space.gutter.list` | 16 | List cell horizontal padding |
| `space.gutter.dense` | 12 | Compact list horizontal padding |

A component's contract specifies which semantic tokens it consumes. A screen composes components; it does not invent spacing.

## Mobile grid

A mobile screen has a single gutter constant: **24 px** edge inset, **16 px** for dense list cells.

Inside the safe-area-respecting content region:
- Standard layout: full-bleed content with 24 px insets.
- Card layout: full-bleed cards (a card spans the full width of the content region), with 24 px insets.
- 8-column logical grid is available for advanced compositions (settings forms, profile stats), with 8 px gutter between columns.

We do not use 12-column or 16-column grids on mobile. They produce dense, web-like results.

## Tablet & desktop

| Surface | Min width | Gutter | Content max-width |
|---|---|---|---|
| Phone | 0 | 24 | 100% |
| Foldable open | 660 | 32 | 720 |
| Tablet portrait | 760 | 32 | 720 |
| Tablet landscape | 1100 | 32 | sidebar + content |
| Desktop | 1200 | 40 | sidebar + content |
| Desktop wide | 1500 | 56 | sidebar + reading column at 720 |

Above tablet portrait, the navigation moves from floating bottom bar to persistent left sidebar. Reading-column width caps at **720 px** for any text-dense surface; we will not produce 1400-px-wide message threads.

## Vertical rhythm

Headings and body must line up to the baseline grid. We achieve this by composing line-height as `multiple-of-4 / font-size`. The token table in `03-typography.md` is constructed so every line-height is divisible by 4. This means stacking any combination of type tokens preserves rhythm without ad-hoc adjustment.

## Safe area handling

Safe-area top inset is honored implicitly by every screen scaffold. The app shell exposes:
```
SafeArea
  ↳ top inset    : status bar + notch / island
  ↳ bottom inset : home indicator (iOS) / gesture nav (Android)
```

The floating navigation respects bottom safe area; on devices without a home indicator, an additional 12 px is added below the nav so the tap target isn't bottom-edge-flush.

The conversation composer at the bottom of a chat screen pins above the keyboard, with a 12 px gap so the text field never visually touches the keyboard edge.

## Touch targets

- Minimum touch target: **44 × 44 logical px** (Apple HIG) — **48 × 48** on Android (Material guidelines). Velix uses **48 × 48 minimum across all platforms** for consistency.
- This is enforced by component contracts. Buttons, toggles, list cells, etc. each declare a minimum size and the layout cannot violate it.
- Visual size and tap target may differ. A 32 px circular avatar in a list cell still has a 48 px tap region (extended invisibly beyond the visual).

## Per-screen edge insets summary

| Screen class | Edge inset |
|---|---|
| Auth, onboarding hero | 32 (centered, breathing) |
| Home feed | 0 (full-bleed media), 16 inside cards |
| Chat list | 0 (full-bleed cells), 16 horizontal inside cells |
| Conversation | 16 horizontal, 12 vertical |
| Profile | 24 |
| Settings | 24 (groups), 16 (cells inside groups) |
| Modals / sheets | 24 internal |
| Story viewer | 0 (full-bleed) |
| Call | 0 (full-bleed) |

## Banned spacing patterns

- Odd numeric values (3, 5, 7, 9, 11, 13, 14, 15, 17 …) anywhere in component or screen code.
- Negative margins to compensate for incorrect padding (re-derive the correct padding instead).
- Spacing that scales with screen width (we use breakpoint-driven, not fluid, spacing).
- A `SizedBox(height: 10)` anywhere in the codebase. (Lint will flag.)
- Different vertical and horizontal padding on a single container without a reason documented in the component contract.

## Implementation notes

In Flutter, the spacing scale is a typed extension on `BuildContext`:

```dart
// theme.dart excerpt
extension VelixSpaceExtension on BuildContext {
  VelixSpace get space => Theme.of(this).extension<VelixTheme>()!.space;
}

// usage
Padding(padding: EdgeInsets.all(context.space.lg), child: ...)
```

The codebase will lint against `EdgeInsets.all(N)` with a literal — the only allowed usage is `context.space.X`.
