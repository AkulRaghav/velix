# 03 — Typography

Typography is where systems quietly succeed or quietly fail. We design ours to fail gracefully — readable at every size, on every screen, in every language we ship — and to succeed quietly: legible first, beautiful second.

## Type families

| Family | Use |
|---|---|
| **Inter** (variable, with optical sizing) | Default UI face. Body, labels, navigation, controls. |
| **Inter Display** (the same family at display optical size) | Type ≥ 28pt. Used for hero headings only. |
| **JetBrains Mono** | Cryptographic identifiers, version strings, key fingerprints, error codes. *Never* for body text. |

We use Inter (not San Francisco) for cross-platform consistency. SF would be ideal on Apple platforms but we accept a small fidelity loss on iOS to gain pixel-identical rendering on Android, web, and Linux.

Inter is loaded as a **variable font** so we can interpolate weight (300–700) and optical size (12–32) without shipping multiple files. Total footprint: ~340 KB compressed for full Latin + Cyrillic + Greek; localization adds Inter Tight for narrow Thai/Lao/Khmer extensions. Arabic uses **Vazirmatn** (variable, designed to harmonize with Inter).

## Type scale

The scale is **Apple-like in its progression** — irregular, not modular. Pure modular scales feel mechanical at small sizes. Apple's HIG type ramp is what we benchmark against.

| Token | Size / Line height / Letter spacing | Weight | Optical | Use |
|---|---|---|---|---|
| `type.display.l` | 56 / 60 / -1.5% | 600 | 32 | Onboarding hero only |
| `type.display.m` | 44 / 48 / -1.2% | 600 | 28 | Splash, story title overlays |
| `type.display.s` | 34 / 40 / -1.0% | 600 | 28 | Profile name, call status |
| `type.title.l` | 28 / 34 / -0.5% | 600 | 22 | Screen title, story author |
| `type.title.m` | 22 / 28 / -0.3% | 600 | 18 | Section header, sheet title |
| `type.title.s` | 19 / 24 / -0.2% | 600 | 16 | List section, conversation header |
| `type.body.l` | 17 / 22 / 0% | 400 | 14 | Primary body, message bubble (default) |
| `type.body.m` | 15 / 20 / 0% | 400 | 14 | Secondary body, list cell content |
| `type.body.s` | 13 / 18 / +0.1% | 400 | 12 | Caption, meta, timestamps |
| `type.label.l` | 15 / 20 / 0% | 500 | 14 | Button, tab label |
| `type.label.m` | 13 / 18 / +0.2% | 500 | 12 | Compact buttons, chip text |
| `type.label.s` | 11 / 14 / +0.5% | 600 | 12 | Tag, badge, micro-label |
| `type.numeric.tabular` | inherits size of context | inherits | inherits | Timestamps, counters, key fingerprints |
| `type.mono` | inherits size of context | 400 | n/a | Cryptographic strings, code |

Letter spacing is calibrated such that **a four-line message bubble at body.l reads with no visual gravity and no visible kerning irregularities** on iPhone 13 at standard viewing distance. We err toward tighter at larger sizes (display tokens) and slightly looser at the smallest sizes (label.s, body.s) where Inter benefits from breathing room.

## Optical sizing

Variable Inter exposes an `opsz` axis. We bind it explicitly for each token so headings render at the display optical size (closer letterforms, refined detail) and body renders at the text optical size (more open, more forgiving at small sizes). This is the same idea Apple uses for SF Pro Display vs SF Pro Text.

In Flutter, `FontVariation('opsz', value)` is set per `TextStyle`.

## Numerals

Tabular numerals are **on by default** for any `type.numeric.tabular` use, plus by design rule for:
- Chat timestamps (so a column of times aligns)
- Unread counts (so a 1 doesn't shift the badge width)
- Key fingerprints (every digit fixed-width)
- Call duration timer

Tabular numerals are **off** for:
- Inline counters in body text ("3 photos", "12 members")
- Display-size numbers in marketing surfaces

## Language coverage at launch

| Language | Family | Notes |
|---|---|---|
| English, German, French, Italian, Portuguese, Spanish | Inter | Latin |
| Polish, Czech, Hungarian | Inter | Latin extended |
| Russian, Ukrainian, Bulgarian | Inter | Cyrillic |
| Greek | Inter | Greek |
| Arabic | Vazirmatn | RTL — verified for line-height parity with Inter |
| Japanese | Noto Sans JP | Variable, weight 300/400/500/600/700 |
| Korean | Noto Sans KR | Same |
| Simplified Chinese | Noto Sans SC | Same |
| Traditional Chinese | Noto Sans TC | Post-launch |
| Hindi, Bengali, Tamil | Noto Sans (Devanagari/Bengali/Tamil) | Post-launch |

Language fallback chain is deterministic and documented per platform.

## Hierarchy rules

The system enforces hierarchy with **at most three type sizes** per surface, plus optionally one `type.label.s` for badges. Surfaces with more typographic levels read as cluttered.

A standard chat-list cell uses exactly three:
- `type.body.l` for the contact name (top-left)
- `type.body.s` for the message preview (below name)
- `type.numeric.tabular` at `body.s` size for the timestamp (top-right)

A profile screen uses three:
- `type.display.s` for the user's name
- `type.body.m` for the bio
- `type.label.m` for action buttons

We do not use four. If a screen needs four, the design is wrong; redesign.

## Tracking under animation

Letter spacing is not animated. Letter spacing animations across an even small range create perceived "breathing" that is one of the cheaper-looking patterns in the genre. Banned.

## Decorative variants

We have **none**. No italic body. No alternates. No oblique. The product's voice is plainness; the cinematic moments are carried by motion and material, not by typeface gymnastics.

## Color × type pairings

| Pairing | Where allowed |
|---|---|
| `text.primary` on `surface.substrate` | everywhere (body, headings) |
| `text.primary` on `material.quiet` | everywhere |
| `text.primary` on `material.active` | sizes ≥ body.m only |
| `text.primary` on `material.lifted` | sizes ≥ body.l only (Reduce Transparency raises this back to body.m equivalent on opaque fallback) |
| `text.secondary` on any surface | sizes ≥ body.m only |
| `text.tertiary` on any surface | sizes ≥ body.s only, never on glass |
| `accent.signature` on body text | banned (only on labels and CTAs) |

## Reflowing for Dynamic Type / large fonts

Dynamic Type (iOS) and Font Size (Android) are honored. Each token maps to a base size and a **scale factor** that responds to the OS-level setting. We support up to **AX5** on iOS (2.0× scale). Layouts are built so:
- No horizontal truncation occurs for any primary action label up through AX5.
- Stack layouts re-flow vertically when needed.
- No fixed-height surfaces — everything that contains text uses intrinsic height bounded by max-lines policy.

A11y audit (`12-accessibility.md`) certifies this for every primary screen.

## Implementation notes (Flutter)

In `theme.dart`, type tokens are exposed as `TextStyle` objects with explicit `fontVariations` for the optical-size axis. We do not rely on `Theme.of` text theme defaults — those are too easy to override. All consumers reach `theme.type.*` directly.

```dart
// Excerpt — full version in theme.dart
TextStyle bodyL = TextStyle(
  fontFamily: 'Inter',
  fontSize: 17,
  height: 22 / 17,
  letterSpacing: 0,
  fontWeight: FontWeight.w400,
  fontVariations: const [FontVariation('opsz', 14)],
  color: VelixColors.textPrimary,
);
```

## Banned typographic patterns

- All-caps body text. (Labels at `type.label.s` only.)
- Italic for emphasis. Use `type.body.l@600` (semibold inline) instead.
- Underlines for emphasis. (Reserved for hyperlinks.)
- Color-only emphasis (accessibility rule).
- Letter-space animation on idle elements.
- Three or more weights in a single surface.
- Mono used for body. (Mono is an instrument, not a voice.)
