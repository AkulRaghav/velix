import '../entities/conversation.dart';
import '../value_objects/ids.dart';

/// Conversation persistence interface. Implemented in `velix_data` by
/// `DriftConversationRepository`. Composes with the local DB stream
/// for offline-first reads.
abstract interface class ConversationRepository {
  Stream<List<Conversation>> watchAll({bool includeArchived = false});

  Stream<Conversation?> watch(ConversationId id);

  Future<void> markAsRead(ConversationId id);

  Future<void> archive(ConversationId id);

  Future<void> unarchive(ConversationId id);

  Future<void> updateTitle(ConversationId id, String title);
}
