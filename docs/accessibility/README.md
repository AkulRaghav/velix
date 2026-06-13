# Accessibility

Velix commits to **WCAG 2.2 AA**. This index points to the canonical sources.

## Documents

| Doc | Purpose |
|---|---|
| [Phase 2 doc 12 — Accessibility System](../phase-2/12-accessibility-system.md) | Internal implementation contract |
| [Phase 11 doc 06 — Accessibility Statement Draft](../phase-11/06-accessibility-statement-draft.md) | The public statement at velix.app/accessibility |

## Implementation references

- `velix_design` package: contrast-ratio-validated tokens; locked at AA per Phase 2 doc 12.
- `velix_motion` package: respects `MediaQuery.accessibleNavigation` and `MediaQuery.disableAnimations`.
- `apps/velix_app`: every interactive widget has a Semantics label.
- Settings UI: per-feature accessibility toggles (Phase 4 doc 10).

## Test fixtures

| Tool | Use |
|---|---|
| Flutter `accessibility_test.dart` | Per-screen Semantics tree assertion |
| Manual VoiceOver pass | iOS pre-release |
| Manual TalkBack pass | Android pre-release |
| Switch Control / Voice Access | Floor-device QA pre-release |

## Annual cadence

- External accessibility consultant audit, annually.
- Public statement updated each cycle with current findings + remediations.
- Inbox for accessibility issues: accessibility@velix.app.
