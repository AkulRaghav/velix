import 'dart:async';
import 'dart:math' show Random;

import 'package:velix_domain/velix_domain.dart';

/// Phase 5 in-memory message repository. Phase 6 swaps in a drift-backed
/// implementation; the API surface is identical.
class InMemoryMessageRepository implements MessageRepository {
  InMemoryMessageRepository({Map<ConversationId, List<Message>>? seed}) {
    if (seed != null) _store.addAll(seed);
  }

  final Map<ConversationId, List<Message>> _store = {};
  final Map<ConversationId, StreamController<List<Message>>> _watchers = {};
  final Random _rng = Random();

  @override
  Stream<List<Message>> watch(ConversationId conversationId) {
    final ctl = _watchers.putIfAbsent(
      conversationId,
      () => StreamController<List<Message>>.broadcast(),
    );
    // Emit the current snapshot synchronously after subscription.
    Future<void>.microtask(() => ctl.add(_messagesOf(conversationId)));
    return ctl.stream;
  }

  List<Message> _messagesOf(ConversationId id) =>
      List.unmodifiable(_store[id] ?? const []);

  @override
  Future<MessageId> sendText({
    required ConversationId conversationId,
    required IdentityId senderId,
    required String body,
    MessageId? replyToId,
  }) async {
    final newId = MessageId('m${_rng.nextInt(1 << 32).toRadixString(16)}');
    final now = Instant.now();
    final msg = Message(
      id: newId,
      conversationId: conversationId,
      senderId: senderId,
      kind: MessageKind.text,
      body: body,
      sentAt: now,
      receivedAt: now,
      status: MessageStatus.pending,
      replyToId: replyToId,
    );
    _store.putIfAbsent(conversationId, () => <Message>[]).add(msg);
    _emit(conversationId);
    // Simulate the gateway round-trip: switch to sent after 400 ms.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      _replace(
        conversationId,
        newId,
        (m) => Message(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          kind: m.kind,
          body: m.body,
          sentAt: m.sentAt,
          receivedAt: m.receivedAt,
          status: MessageStatus.sent,
          replyToId: m.replyToId,
          reactions: m.reactions,
        ),
      );
    });
    return newId;
  }

  @override
  Future<void> addReaction({
    required MessageId messageId,
    required IdentityId byIdentityId,
    required String emoji,
  }) async {
    _mutateReaction(messageId, (existing) {
      if (existing.any((r) => r.byIdentityId == byIdentityId && r.emoji == emoji)) {
        return existing;
      }
      return [
        ...existing,
        MessageReaction(emoji: emoji, byIdentityId: byIdentityId, at: Instant.now()),
      ];
    });
  }

  @override
  Future<void> removeReaction({
    required MessageId messageId,
    required IdentityId byIdentityId,
    required String emoji,
  }) async {
    _mutateReaction(
      messageId,
      (existing) => existing
          .where((r) => !(r.byIdentityId == byIdentityId && r.emoji == emoji))
          .toList(),
    );
  }

  @override
  Future<void> retry(MessageId messageId) async {
    _store.forEach((convId, list) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx == -1) return;
      final m = list[idx];
      list[idx] = Message(
        id: m.id,
        conversationId: m.conversationId,
        senderId: m.senderId,
        kind: m.kind,
        body: m.body,
        sentAt: m.sentAt,
        receivedAt: m.receivedAt,
        status: MessageStatus.pending,
        replyToId: m.replyToId,
        reactions: m.reactions,
      );
      _emit(convId);
    });
  }

  @override
  Future<void> delete(MessageId messageId) async {
    _store.forEach((convId, list) {
      final n = list.length;
      list.removeWhere((m) => m.id == messageId);
      if (list.length != n) _emit(convId);
    });
  }

  void _replace(
    ConversationId convId,
    MessageId msgId,
    Message Function(Message) f,
  ) {
    final list = _store[convId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == msgId);
    if (idx == -1) return;
    list[idx] = f(list[idx]);
    _emit(convId);
  }

  void _mutateReaction(
    MessageId msgId,
    List<MessageReaction> Function(List<MessageReaction>) f,
  ) {
    _store.forEach((convId, list) {
      final idx = list.indexWhere((m) => m.id == msgId);
      if (idx == -1) return;
      final m = list[idx];
      list[idx] = Message(
        id: m.id,
        conversationId: m.conversationId,
        senderId: m.senderId,
        kind: m.kind,
        body: m.body,
        sentAt: m.sentAt,
        receivedAt: m.receivedAt,
        status: m.status,
        replyToId: m.replyToId,
        reactions: f(m.reactions),
      );
      _emit(convId);
    });
  }

  void _emit(ConversationId id) {
    _watchers[id]?.add(_messagesOf(id));
  }

  void dispose() {
    for (final c in _watchers.values) {
      c.close();
    }
    _watchers.clear();
  }
}
