import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velix_data/velix_data.dart';
import 'package:velix_domain/velix_domain.dart';

import '../bootstrap/bootstrap.dart';

/// Riverpod root providers. Phase 5 keeps these manual (no codegen) so the
/// shape is obvious; Phase 6 migrates to riverpod_generator alongside the
/// real repositories.
///
/// The bootstrap result is overridden into [bootstrapProvider] in `main.dart`,
/// which seeds every other provider transitively.

final bootstrapProvider = Provider<BootstrapResult>((_) {
  throw UnimplementedError(
    'Override bootstrapProvider in main() with the BootstrapResult '
    'returned by Bootstrap.run().',
  );
});

// ---- Repositories ---------------------------------------------------------

final identityRepositoryProvider = Provider<IdentityRepository>(
  (ref) => ref.watch(bootstrapProvider).identityRepository,
);

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ref.watch(bootstrapProvider).conversationRepository,
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => ref.watch(bootstrapProvider).messageRepository,
);

// ---- Use cases ------------------------------------------------------------

final watchConversationsProvider = Provider<WatchConversationsUseCase>(
  (ref) => WatchConversationsUseCase(ref.watch(conversationRepositoryProvider)),
);

final watchMessagesProvider = Provider<WatchMessagesUseCase>(
  (ref) => WatchMessagesUseCase(ref.watch(messageRepositoryProvider)),
);

final sendMessageProvider = Provider<SendMessageUseCase>(
  (ref) => SendMessageUseCase(
    messages: ref.watch(messageRepositoryProvider),
    identity: ref.watch(identityRepositoryProvider),
  ),
);

final markAsReadProvider = Provider<MarkConversationAsReadUseCase>(
  (ref) => MarkConversationAsReadUseCase(
    ref.watch(conversationRepositoryProvider),
  ),
);

final archiveConversationProvider = Provider<ArchiveConversationUseCase>(
  (ref) => ArchiveConversationUseCase(
    ref.watch(conversationRepositoryProvider),
  ),
);

// ---- Reactive selectors ---------------------------------------------------

final identityProvider = StreamProvider<Identity?>(
  (ref) => ref.watch(identityRepositoryProvider).watch(),
);

final chatListProvider = StreamProvider.autoDispose<List<Conversation>>(
  (ref) => ref.watch(watchConversationsProvider).call(),
);

final conversationProvider =
    StreamProvider.autoDispose.family<Conversation?, ConversationId>(
  (ref, id) => ref.watch(conversationRepositoryProvider).watch(id),
);

final messagesProvider =
    StreamProvider.autoDispose.family<List<Message>, ConversationId>(
  (ref, id) => ref.watch(watchMessagesProvider).call(id),
);

// ---- Accessibility preferences -------------------------------------------

/// On-disk store for accessibility preferences, seeded from bootstrap.
final accessibilityStoreProvider = Provider<AccessibilityPreferencesStore>(
  (ref) => ref.watch(bootstrapProvider).accessibilityStore,
);

/// Reactive accessibility preferences. Seeded from the value bootstrap loaded
/// from disk; updates persist through [AccessibilityPreferencesStore].
final accessibilityPreferencesProvider = StateNotifierProvider<
    AccessibilityPreferencesController, AccessibilityPreferences>(
  (ref) => AccessibilityPreferencesController(
    store: ref.watch(accessibilityStoreProvider),
    initial: ref.watch(bootstrapProvider).accessibilityPreferences,
  ),
);

/// Mutates [AccessibilityPreferences] and persists every change.
class AccessibilityPreferencesController
    extends StateNotifier<AccessibilityPreferences> {
  AccessibilityPreferencesController({
    required AccessibilityPreferencesStore store,
    required AccessibilityPreferences initial,
  })  : _store = store,
        super(initial);

  final AccessibilityPreferencesStore _store;

  Future<void> _update(AccessibilityPreferences next) async {
    state = next;
    await _store.save(next);
  }

  Future<void> setReduceMotion(bool value) =>
      _update(state.copyWith(reduceMotion: value));

  Future<void> setReduceTransparency(bool value) =>
      _update(state.copyWith(reduceTransparency: value));

  Future<void> setHighContrast(bool value) =>
      _update(state.copyWith(highContrast: value));

  Future<void> setLongPressMultiplier(double value) =>
      _update(state.copyWith(longPressMultiplier: value));

  Future<void> setSwipeMultiplier(double value) =>
      _update(state.copyWith(swipeMultiplier: value));

  Future<void> setCaptionsEnabled(bool value) =>
      _update(state.copyWith(captionsEnabled: value));
}
