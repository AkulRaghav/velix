import 'dart:async';

import 'package:velix_domain/velix_domain.dart';

/// Phase 5 in-memory conversation repository. Drives the chat list and
/// per-conversation metadata. Phase 6 swaps in the drift-backed version.
class InMemoryConversationRepository implements ConversationRepository {
  InMemoryConversationRepository({List<Conversation>? seed}) {
    if (seed != null) {
      for (final c in seed) {
        _store[c.id] = c;
      }
    }
  }

  final Map<ConversationId, Conversation> _store = {};
  final StreamController<void> _all = StreamController<void>.broadcast();

  @override
  Stream<List<Conversation>> watchAll({bool includeArchived = false}) async* {
    yield _snapshot(includeArchived);
    yield* _all.stream.map((_) => _snapshot(includeArchived));
  }

  List<Conversation> _snapshot(bool includeArchived) {
    final all = _store.values.where((c) => includeArchived || !c.archived).toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return List.unmodifiable(all);
  }

  @override
  Stream<Conversation?> watch(ConversationId id) async* {
    yield _store[id];
    yield* _all.stream.map((_) => _store[id]);
  }

  @override
  Future<void> markAsRead(ConversationId id) async {
    final c = _store[id];
    if (c == null || c.unreadCount == 0) return;
    _store[id] = c.copyWith(unreadCount: 0);
    _all.add(null);
  }

  @override
  Future<void> archive(ConversationId id) async {
    final c = _store[id];
    if (c == null) return;
    _store[id] = c.copyWith(archived: true);
    _all.add(null);
  }

  @override
  Future<void> unarchive(ConversationId id) async {
    final c = _store[id];
    if (c == null) return;
    _store[id] = c.copyWith(archived: false);
    _all.add(null);
  }

  @override
  Future<void> updateTitle(ConversationId id, String title) async {
    final c = _store[id];
    if (c == null) return;
    _store[id] = c.copyWith(title: title);
    _all.add(null);
  }

  void dispose() => _all.close();
}
