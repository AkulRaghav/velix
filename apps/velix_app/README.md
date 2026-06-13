# velix_app

The Velix Flutter client — a privacy-first, end-to-end encrypted messaging app.

This is the application shell; most functionality lives in the workspace
packages (`packages/velix_*`). See the [root README](../../README.md) and
[PORTFOLIO.md](../../PORTFOLIO.md) for the full picture.

## Architecture

Clean architecture across three layers:

- **presentation** (`lib/src/presentation`) — screens, components, the floating
  nav shell. Riverpod for state, go_router for navigation.
- **domain** (`packages/velix_domain`) — entities, use cases, repository
  interfaces. No Flutter or I/O dependencies.
- **data** (`packages/velix_data`) — repository implementations: in-memory
  (offline / first-run) and remote (HTTP alpha client) behind the same
  interfaces.

Cross-cutting:
- `lib/src/bootstrap` — cold-start wiring; chooses in-memory vs remote repos
  based on a persisted session, and loads accessibility preferences.
- `lib/src/di` — Riverpod providers, including the accessibility controller.
- `lib/src/router` — `go_router` config; nav-hiding rules per route.

Design system packages: `velix_design` (tokens, materials, typography),
`velix_motion` (spring physics + haptics), `velix_3d` (scene widget + 2D
fallbacks).

## Run

```bash
flutter pub get

# Against the local alpha server (see backend/alpha):
flutter run --dart-define=VELIX_ALPHA_URL=http://10.0.2.2:8080   # Android emulator
flutter run --dart-define=VELIX_ALPHA_URL=http://127.0.0.1:8080  # iOS sim / desktop
```

## Validate

```bash
flutter analyze     # 0 issues
flutter test        # widget + provider smoke tests
```

## Notable screens

- `splash` — animated scanline reveal + brand mark
- `onboarding` — 3-step flow with 3D scenes and animated progression
- `auth` — registration + HMAC challenge/response sign-in
- `chats` — conversation list with live client-side search and loading/empty states
- `chat` — message thread with optimistic send and 2s polling
- `profile` — identity hero with real account stats
- `settings/accessibility` — reduce motion, high contrast, configurable gesture thresholds
