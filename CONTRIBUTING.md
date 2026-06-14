# Contributing to Velix

Thank you for your interest in contributing to Velix.

## Development Setup

### Prerequisites

- Flutter 3.44+ / Dart 3.12+
- Go 1.22+
- Rust (stable, via rustup)
- PostgreSQL 16 (for integration tests)
- NATS Server 2.10+ (for event bus tests)

### Quick Start

```bash
# Backend
cd backend/alpha
go run ./cmd/alpha-server

# Flutter app
cd apps/velix_app
flutter pub get
flutter run --dart-define=VELIX_ALPHA_URL=http://10.0.2.2:8080
```

### Running Tests

```bash
# Go backend
cd backend && go test ./alpha/...

# Flutter
cd apps/velix_app && flutter test

# Dart packages
cd packages/velix_data && dart test

# Rust crypto
cd cryptocore && cargo test
```

## Code Style

- **Dart**: Follow `flutter analyze` with zero issues
- **Go**: `go vet` + `gofmt`
- **Rust**: `cargo clippy` + `cargo fmt`

## Commit Messages

Use conventional commits:
- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation
- `test:` — tests
- `refactor:` — code refactoring
- `perf:` — performance
- `chore:` — maintenance

## Architecture

See `PORTFOLIO.md` for the full architecture overview and `README.md` for the tech stack.

## Security

If you discover a security vulnerability, please report it privately. Do not open a public issue.
