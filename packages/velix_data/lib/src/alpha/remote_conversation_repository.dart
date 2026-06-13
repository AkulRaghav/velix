import 'dart:async';

import 'package:velix_domain/velix_domain.dart';

import 'alpha_api_client.dart';

/// Repositories backed by the Alpha HTTP server. Polls every [pollInterval]
/// when there is at least one watcher; idle otherwise.
class RemoteConversationRepository implements ConversationRepository {
  RemoteConversationRepository({
    required this.client,
    required this.myAccountId,
    Duration? pollInterval,
  }) : pollInterval = pollInterval ?? const Duration(seconds: 3);

  final AlphaApiClient client;
  final String myAccountId;
  final Duration pollInterval;

  final List<Conversation> _cache = [];
  final StreamController<List<Conversation>> _ctl =
      StreamController<List<Conversation>>.broadcast();
  Timer? _timer;
  int _watchers = 0;

  void _ensurePolling() {
    if (_timer != null) return;
    _timer = Timer.periodic(pollInterval, (_) => _refresh());
    // immediate refresh
    unawaited(_refresh());
  }

  void _maybeStop() {
    if (_watchers <= 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _refresh() async {
    try {
      final list = await client.listConversations();
      _cache
        ..clear()
        ..addAll(list.map(_toDomain));
      _ctl.add(List.unmodifiable(_cache));
    } catch (_) {
      // alpha-grade: drop the error; UI stays on cached state.
    }
  }

  Conversation _toDomain(ConversationDto d) => Conversation(
        id: ConversationId(d.id),
        kind: ConversationKind.direct,
        title: d.title.isEmpty ? d.peerAccountId : d.title,
        roomColorIndex: _hashColor(d.peerAccountId),
        trustState: TrustState.standard,
        lastActivityAt: Instant.fromDateTime(d.lastActiveAt),
        unreadCount: 0,
        archived: false,
        lastMessagePreview: d.preview.isEmpty ? null : d.preview,
      );

  int _hashColor(String s) {
    var h = 0;
    for (final cu in s.codeUnits) {
      h = (h * 31 + cu) & 0x7fffffff;
    }
    return h % 12;
  }

  @override
  Stream<List<Conversation>> watchAll({bool includeArchived = false}) {
    _watchers++;
    _ensurePolling();
    final controller = StreamController<List<Conversation>>();
    final sub = _ctl.stream.listen(controller.add);
    if (_cache.isNotEmpty) controller.add(List.unmodifiable(_cache));
    controller.onCancel = () async {
      await sub.cancel();
      _watchers--;
      _maybeStop();
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<Conversation?> watch(ConversationId id) async* {
    yield* watchAll().map(
      (list) => list.firstWhere(
        (c) => c.id == id,
        orElse: () => Conversation(
          id: id,
          kind: ConversationKind.direct,
          title: id.value,
          roomColorIndex: 0,
          trustState: TrustState.standard,
          lastActivityAt: Instant.epoch,
          unreadCount: 0,
          archived: false,
        ),
      ),
    );
  }

  @override
  Future<void> markAsRead(ConversationId id) async {
    // Alpha server does not track read state.
  }

  @override
  Future<void> archive(ConversationId id) async {}

  @override
  Future<void> unarchive(ConversationId id) async {}

  @override
  Future<void> updateTitle(ConversationId id, String title) async {}

  Future<Conversation> openWith({
    required String peerAccountId,
    String? title,
  }) async {
    final dto = await client.openConversation(
      peerAccountId: peerAccountId,
      title: title ?? peerAccountId,
    );
    await _refresh();
    return _toDomain(dto);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _ctl.close();
  }
}
