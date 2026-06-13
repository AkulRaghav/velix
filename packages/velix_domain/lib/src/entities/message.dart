import 'package:meta/meta.dart';

import '../value_objects/ids.dart';
import '../value_objects/instant.dart';

enum MessageKind {
  text,
  voice,
  image,
  video,
  file,
  reaction,
  systemEvent,
}

enum MessageStatus {
  /// Locally written; awaiting outbound dispatch.
  pending,

  /// Acknowledged by the gateway.
  sent,

  /// Acknowledged by every recipient device.
  delivered,

  /// At least one recipient has read it.
  read,

  /// Permanent failure; the user should retry or remove.
  failed,
}

@immutable
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.sentAt,
    required this.receivedAt,
    required this.status,
    this.replyToId,
    this.reactions = const [],
  });

  final MessageId id;
  final ConversationId conversationId;
  final IdentityId senderId;
  final MessageKind kind;

  /// Decrypted text (or media metadata) for display. Wire ciphertext
  /// is handled by `velix_data` mappers and never reaches this entity.
  final String body;

  final Instant sentAt;
  final Instant receivedAt;
  final MessageStatus status;

  final MessageId? replyToId;
  final List<MessageReaction> reactions;
}

@immutable
class MessageReaction {
  const MessageReaction({
    required this.emoji,
    required this.byIdentityId,
    required this.at,
  });

  final String emoji;
  final IdentityId byIdentityId;
  final Instant at;
}
