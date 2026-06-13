import '../entities/message.dart';
import '../value_objects/ids.dart';

abstract interface class MessageRepository {
  Stream<List<Message>> watch(ConversationId conversationId);

  /// Locally insert a new outbound message and enqueue for sync.
  /// Returns the new message id (ULID).
  Future<MessageId> sendText({
    required ConversationId conversationId,
    required IdentityId senderId,
    required String body,
    MessageId? replyToId,
  });

  Future<void> addReaction({
    required MessageId messageId,
    required IdentityId byIdentityId,
    required String emoji,
  });

  Future<void> removeReaction({
    required MessageId messageId,
    required IdentityId byIdentityId,
    required String emoji,
  });

  Future<void> retry(MessageId messageId);

  Future<void> delete(MessageId messageId);
}
