import '../entities/conversation.dart';
import '../repositories/conversation_repository.dart';

class WatchConversationsUseCase {
  WatchConversationsUseCase(this._repo);
  final ConversationRepository _repo;

  Stream<List<Conversation>> call({bool includeArchived = false}) =>
      _repo.watchAll(includeArchived: includeArchived);
}
