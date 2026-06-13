import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:velix_domain/velix_domain.dart';

import 'alpha_api_client.dart';

/// Message repository backed by the Alpha HTTP server.
///
/// Polls per-conversation while watchers exist. The "ciphertext" is just
/// UTF-8 plaintext bytes for the alpha; Phase 7 wires libsignal at the
/// edges so the in-flight bytes are real ciphertext.
class RemoteMessageRepository implements MessageRepository {
  RemoteMessageRepository({
    required this.client,
    required this.myAccountId,
    Duration? pollInterval,
  }) : pollInterval = pollInterval ?? const Duration(seconds: 2);

  final AlphaApiClient client;
  final String myAccountId;
  final Duration pollInterval;

  final Map<ConversationId, _Channel> _channels = {};

  _Channel _channel(ConversationId id) =>
      _channels.putIfAbsent(id, () => _Channel(id, this));

  @override
  Stream<List<Message>> watch(ConversationId conversationId) {
    return _channel(conversationId).attach();
  }

  @override
  Future<MessageId> sendText({
    required ConversationId conversationId,
    required IdentityId senderId,
    required String body,
    MessageId? replyToId,
  }) async {
    final ct = Uint8List.fromList(utf8.encode(body));
    final dto = await client.sendMessage(
      conversationId: conversationId.value,
      kind: 'text',
      ciphertext: ct,
      preview: body.length > 96 ? body.substring(0, 96) : body,
    );
    // Refresh once so the watcher emits the new message immediately.
    await _channel(conversationId).refresh();
    return MessageId(dto.id);
  }

  @override
  Future<void> addReaction({
    required MessageId messageId,
    required IdentityId byIdentityId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction({
    required MessageId messageId,
    required IdentityId byIdentityId,
    required String emoji,
  }) async {}

  @override
  Future<void> retry(MessageId messageId) async {}

  @override
  Future<void> delete(MessageId messageId) async {}

  void dispose() {
    for (final c in _channels.values) {
      c.dispose();
    }
    _channels.clear();
  }
}

class _Channel {
  _Channel(this.conversationId, this.repo);

  final ConversationId conversationId;
  final RemoteMessageRepository repo;
  final List<Message> _cache = [];
  final StreamController<List<Message>> _ctl =
      StreamController<List<Message>>.broadcast();
  Timer? _timer;
  int _watchers = 0;

  Stream<List<Message>> attach() {
    _watchers++;
    if (_timer == null) {
      _timer = Timer.periodic(repo.pollInterval, (_) => refresh());
      unawaited(refresh());
    }
    final controller = StreamController<List<Message>>();
    final sub = _ctl.stream.listen(controller.add);
    if (_cache.isNotEmpty) controller.add(List.unmodifiable(_cache));
    controller.onCancel = () async {
      await sub.cancel();
      _watchers--;
      if (_watchers <= 0) {
        _timer?.cancel();
        _timer = null;
      }
      await controller.close();
    };
    return controller.stream;
  }

  Future<void> refresh() async {
    try {
      final list = await repo.client.listMessages(conversationId: conversationId.value);
      _cache
        ..clear()
        ..addAll(list.map(_toDomain));
      _ctl.add(List.unmodifiable(_cache));
    } catch (_) {
      // ignore
    }
  }

  Message _toDomain(MessageDto d) {
    final body = utf8.decode(d.ciphertext, allowMalformed: true);
    return Message(
      id: MessageId(d.id),
      conversationId: ConversationId(d.conversationId),
      senderId: IdentityId(d.senderId),
      kind: MessageKind.text,
      body: body,
      sentAt: Instant.fromDateTime(d.sentAt),
      receivedAt: Instant.fromDateTime(d.sentAt),
      status: d.senderId == repo.myAccountId
          ? MessageStatus.sent
          : MessageStatus.delivered,
    );
  }

  void dispose() {
    _timer?.cancel();
    _ctl.close();
  }
}
