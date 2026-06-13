# 01 — Clean Architecture

## Why clean architecture for Velix

Velix is a long-lived product. We expect to swap the network layer, swap the encryption library, change persistence engines, port to spatial OS, and refactor the AI gateway over the next three years. Clean architecture treats those swaps as local, scoped changes — the interface stays, the implementation shifts.

We pay a small upfront cost in indirection. We earn freedom to evolve any layer without rewriting the others.

## Three layers

### Domain (`packages/velix_domain/`)

Pure Dart. No Flutter, no platform dependencies, no network, no database. Domain models, value objects, use cases, repository **interfaces**. This layer is testable headless and runs in milliseconds.

Examples:

```dart
// Entity
@immutable
class Conversation {
  final ConversationId id;
  final String title;
  final TrustState trustState;
  final Instant lastActivityAt;
  // ... value-typed fields only
}

// Value object
extension type const ConversationId(String value) {
  factory ConversationId.generate() => ConversationId(_uuid.v7());
}

// Repository interface
abstract interface class ConversationRepository {
  Stream<List<Conversation>> watchAll();
  Future<Conversation?> findById(ConversationId id);
  Future<void> markAsRead(ConversationId id);
}

// Use case
class MarkConversationAsReadUseCase {
  MarkConversationAsReadUseCase(this._repo);
  final ConversationRepository _repo;

  Future<Result<Unit, AppError>> call(ConversationId id) async {
    return Result.guard(() => _repo.markAsRead(id));
  }
}
```

### Data (`packages/velix_data/`)

Implements domain interfaces. Owns the database, secure storage, and gateways (network). Translates domain entities to/from persistence and wire formats.

Repository implementations live here:

```dart
class DriftConversationRepository implements ConversationRepository {
  DriftConversationRepository(this._db);
  final VelixDatabase _db;

  @override
  Stream<List<Conversation>> watchAll() {
    return _db.conversations
        .select()
        .watch()
        .map((rows) => rows.map(_toEntity).toList());
  }
  // ...
}
```

Data layer composes: drift database, secure storage, gateway (gRPC stub for Phase 5; real gRPC in Phase 6), serializers, mappers.

### Presentation (`apps/velix_app/lib/src/presentation/`)

Riverpod notifiers and selectors over use cases; widgets that compose `velix_design`/`velix_motion`/`velix_3d` primitives.

Notifiers don't call repositories directly — they call use cases:

```dart
@riverpod
class ChatListNotifier extends _$ChatListNotifier {
  @override
  Stream<List<Conversation>> build() {
    return ref.read(watchConversationsUseCaseProvider).call();
  }
}
```

Use cases are the seam between presentation and domain. Anything that crosses the layer goes through one.

## Use cases as first-class citizens

Every operation has a use case. Use cases are:
- Single-purpose (one verb each)
- Pure (no Flutter)
- Composable (a use case can call another use case)
- Tested in isolation with mocked repositories

Catalog excerpt (the full list lives in `velix_domain/lib/src/use_cases/`):

| Use case | Returns |
|---|---|
| `WatchConversationsUseCase` | `Stream<List<Conversation>>` |
| `WatchMessagesUseCase` | `Stream<List<Message>>` (per conversation) |
| `SendMessageUseCase` | `Result<MessageId, SendError>` |
| `MarkConversationAsReadUseCase` | `Result<Unit, AppError>` |
| `ArchiveConversationUseCase` | `Result<Unit, AppError>` |
| `CreateIdentityUseCase` | `Result<Identity, CryptoError>` |
| `AddDeviceUseCase` | `Result<Device, PairingError>` |
| `RotateConversationKeysUseCase` | `Result<Unit, CryptoError>` |
| `SearchUseCase` | `Stream<List<SearchResult>>` |
| `ExportConversationUseCase` | `Result<Bytes, AppError>` |

A use case never returns a domain error directly — it returns a `Result<Success, Error>` with named error types. Presentation maps errors to UX via `errors.dart` (Phase 5 doc 08).

## Dependency direction in detail

```
   ┌──────────────────────────────────────────────┐
   │  Presentation (apps/velix_app)               │
   │   Notifiers, Selectors                       │
   │   Widgets composing design/motion/3d         │
   └──────────────┬───────────────────────────────┘
                  │ calls use cases via providers
   ┌──────────────▼───────────────────────────────┐
   │  Domain (velix_domain)                       │
   │   Entities, Value objects                    │
   │   Use cases                                  │
   │   Repository interfaces                      │
   └──────────────▲───────────────────────────────┘
                  │ implements interfaces
   ┌──────────────┴───────────────────────────────┐
   │  Data (velix_data)                           │
   │   DriftDatabase, SecureStorage,              │
   │   GatewayClients, Mappers                    │
   └──────────────────────────────────────────────┘
```

Riverpod providers in the `apps/velix_app/lib/src/di/` layer wire data implementations into the domain interfaces. Tests substitute fakes via `ProviderScope.overrides`.

## Why not BLoC

We considered BLoC. Specifically:
- BLoC's event/state model is verbose for the per-screen state we have.
- Riverpod's `family` providers are a cleaner per-conversation state model than spawning BLoC instances.
- Riverpod's testing story (provider override at `ProviderScope`) is simpler than BLoC's `BlocProvider` overrides.
- We want code-generation, and Riverpod's codegen is better-maintained than BLoC's.

## Why not get_it / GetX

Service-locator patterns hide dependencies. Riverpod makes them explicit at the call site (every read uses `ref.read` or `ref.watch`). When we refactor, the compiler tells us. With `get_it`, we'd find issues at runtime.

GetX additionally entangles state, routing, and DI in a way that crosses our layer boundaries.

## Inter-feature dependencies

Sometimes a feature needs another feature's data. Example: the AI assistant might want to read the current conversation's recent messages.

Rule: **cross-feature reads happen at the presentation layer**, not the domain layer. The AI feature's notifier reads the conversation feature's `messagesProvider(conversationId)`. The two domains stay decoupled — each can be tested without the other.

If two features genuinely share domain logic, the shared logic moves into a `velix_domain/shared/` subdirectory.

## File-system layout per layer

Each layer follows the same structure:

```
domain/
  src/
    entities/
    value_objects/
    repositories/        ← interfaces
    use_cases/
    errors/
    extensions/
  velix_domain.dart      ← public surface
```

```
data/
  src/
    db/                  ← drift schema, dao, migrations
    secure_storage/
    gateways/            ← gRPC clients (stubs in P5)
    repositories/        ← drift-backed implementations
    mappers/             ← entity ↔ db row, entity ↔ wire
  velix_data.dart
```

```
apps/velix_app/lib/src/presentation/
  screens/
    splash/
      splash_screen.dart
    onboarding/
      onboarding_screen.dart
      _hero.dart
  components/
    button/
    glass_card/
    message_bubble/
```

Each screen has its own folder. Components have their own folders. Private helpers prefix with `_`.

## Audit hooks

CI runs:
- `dart analyze` with strict mode
- A custom `tools/import_lint.dart` enforcing layer boundaries
- `dart_code_metrics` for cyclomatic complexity (max 12 per function), duplicate code detection, and unused-import elimination
- `dart pub deps` graph check that no `data/*` package imports from `presentation/*`

## What this enables

- Headless tests of every use case in milliseconds.
- Repository swaps (in-memory ↔ drift ↔ remote) by changing one provider override.
- Phase 6 backend wiring is a *swap*, not a *rewrite* — replace `FakeMessageGateway` with `GrpcMessageGateway` and the rest of the app is unchanged.
- Phase 7 encryption layering is similarly swap-shaped.
