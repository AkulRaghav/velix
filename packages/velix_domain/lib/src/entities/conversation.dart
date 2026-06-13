import 'package:meta/meta.dart';

import '../value_objects/ids.dart';
import '../value_objects/instant.dart';
import 'trust_state.dart';

enum ConversationKind { direct, group, channel, space }

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.kind,
    required this.title,
    required this.roomColorIndex,
    required this.trustState,
    required this.lastActivityAt,
    required this.unreadCount,
    required this.archived,
    this.lastMessagePreview,
    this.avatarUrl,
  });

  final ConversationId id;
  final ConversationKind kind;
  final String title;

  /// 0–11 index into the room palette (Phase 2 `01-color-tokens.md`).
  /// Deterministic per conversation.
  final int roomColorIndex;

  final TrustState trustState;
  final Instant lastActivityAt;
  final int unreadCount;
  final bool archived;
  final String? lastMessagePreview;
  final String? avatarUrl;

  Conversation copyWith({
    String? title,
    TrustState? trustState,
    Instant? lastActivityAt,
    int? unreadCount,
    bool? archived,
    String? lastMessagePreview,
  }) =>
      Conversation(
        id: id,
        kind: kind,
        title: title ?? this.title,
        roomColorIndex: roomColorIndex,
        trustState: trustState ?? this.trustState,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
        unreadCount: unreadCount ?? this.unreadCount,
        archived: archived ?? this.archived,
        lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
        avatarUrl: avatarUrl,
      );
}
