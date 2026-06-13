# 02 — State Management (Riverpod 2.x)

## Why Riverpod

Riverpod 2.x with code generation gives us:

- **Compile-time safety.** A misspelled provider id, a missing parameter, a type mismatch — caught at build time. The standard `Provider`-of-`ChangeNotifier` model fails at runtime.
- **Scoping and overrides.** `ProviderScope.overrides: [...]` is the entire test mocking story. No registry hacks, no service-locator surgery.
- **Auto-dispose by default.** Providers dispose when no listener remains, which dramatically reduces leaked state and stale data.
- **Family modifiers.** `messagesProvider(conversationId)` produces a per-conversation provider that auto-disposes when the user leaves the conversation. No manual lifecycle management.
- **Reactive selectors.** `ref.watch(provider.select((s) => s.field))` rebuilds only when the selected field changes, not on every state change.

We use the **code-generation** flavor (`@riverpod` annotations + `riverpod_generator`) because hand-written providers are noisier and easier to misuse.

## Notifier types

| Type | Use |
|---|---|
| `@riverpod` (function) | Computed/derived state, simple data fetches |
| `@riverpod` `class XNotifier extends _$XNotifier` | Stateful objects with mutation methods |
| `@riverpod` `class XAsyncNotifier extends _$XAsyncNotifier` (returning `AsyncValue` or `Future`) | Async-loaded state with loading/error/data |
| `@riverpod` `class XStreamNotifier extends _$XStreamNotifier` (returning `Stream`) | Reactive streams from repositories |

Examples by category:

### Read-only computation

```dart
@riverpod
TrustState conversationTrust(Ref ref, ConversationId id) {
  final conv = ref.watch(conversationsByIdProvider(id));
  return conv?.trustState ?? TrustState.unverified;
}
```

### Stream-from-repository

```dart
@riverpod
class ChatList extends _$ChatList {
  @override
  Stream<List<Conversation>> build() {
    final useCase = ref.watch(watchConversationsUseCaseProvider);
    return useCase.call();
  }
}
```

### Stateful with methods

```dart
@riverpod
class ComposerState extends _$ComposerState {
  @override
  ComposerData build(ConversationId id) =>
      const ComposerData(text: '', isRecording: false);

  void setText(String t) => state = state.copyWith(text: t);
  void startRecording() => state = state.copyWith(isRecording: true);
  Future<void> send() async {
    final res = await ref.read(sendMessageUseCaseProvider).call(
          conversationId: id,
          text: state.text,
        );
    res.when(
      ok: (_) => state = const ComposerData(text: '', isRecording: false),
      err: (e) => ref.read(errorReporterProvider).report(e),
    );
  }
}
```

## Reading rules

- Inside `build`, always use `ref.watch`. The notifier rebuilds when watched dependencies change.
- Inside event handlers (button taps, stream listeners), use `ref.read`. Reads do not subscribe.
- In widgets, use `ref.watch(provider.select(...))` for surgical rebuilds.
- Never call `ref.watch` inside an `onPressed` callback. That's a common bug; the watch persists for the closure's lifetime.

## Provider scoping

The application has three named scopes:

1. **Root scope** — `runApp(ProviderScope(...))`. Holds long-lived providers (auth, identity, theme, telemetry).
2. **Authenticated scope** — `ProviderScope(overrides: ...)` mounted after sign-in. Holds the chat list, conversation cache, AI session.
3. **Conversation scope** — implicit via `family`. Each open conversation gets its own message stream, composer state, and reaction picker provider, auto-disposed when the conversation route is popped.

This scoping reflects the data lifetime: account-bound data is in the auth scope; per-conversation data is per-family; everything else is root.

## Lifecycle and disposal

Auto-dispose is the default. Specific exceptions:

- `themeProvider` — `keepAlive` (lives for app session)
- `identityProvider` — `keepAlive` (lives for app session)
- `telemetryProvider` — `keepAlive`
- `chatListProvider` — auto-dispose (rebuilds cheap; we don't pay to keep it warm)
- `messagesProvider(id)` — auto-dispose with a 5-second cache window via `ref.cacheFor(Duration(seconds: 5))` (a custom helper; lets the user navigate away and back without reloading)

## Selectors and rebuild discipline

A widget that reads `state.title` must not rebuild when `state.lastActivityAt` changes. We enforce this with `select`:

```dart
final title = ref.watch(conversationProvider(id).select((s) => s?.title));
```

In practice, every screen has a `Consumer` near the top extracting just what it needs, and child widgets each have their own `Consumer`s for their own slices. We do not pass watched state down through props; we let each subtree subscribe.

## Async handling

`AsyncValue` is the standard wrapper. Patterns:

```dart
final list = ref.watch(chatListProvider);
return list.when(
  data: (conversations) => _ListView(conversations),
  loading: () => const _ChatListSkeleton(),
  error: (e, _) => _ChatListError(error: e),
);
```

The skeleton is a `Loader.pulse` — never a spinner (Phase 2 banned for surfaces opening > 200 ms; we use skeletons for known-shape lists).

## Testing

A representative test:

```dart
test('marks as read when notifier method called', () async {
  final fake = FakeConversationRepository();
  final container = ProviderContainer(overrides: [
    conversationRepositoryProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);

  final notifier = container.read(chatListProvider.notifier);
  await notifier.markAsRead(const ConversationId('c1'));

  expect(fake.markedAsRead, contains(const ConversationId('c1')));
});
```

Every notifier and use case is unit-tested headless. Widget tests substitute the same fakes via `ProviderScope`.

## Banned

- `Provider.value` for shared state (use scoping).
- `setState` in any widget that owns app-state.
- Reading providers inside `build` of a widget that doesn't have a `Consumer` ancestor (causes silent rebuild storms).
- `ref.watch` inside callbacks.
- Storing widgets or BuildContexts in provider state.
- Mixing Riverpod with `provider` package or `get_it` in the same code path.
