import '../entities/message.dart';
import '../repositories/message_repository.dart';
import '../value_objects/ids.dart';

class WatchMessagesUseCase {
  WatchMessagesUseCase(this._repo);
  final MessageRepository _repo;

  Stream<List<Message>> call(ConversationId id) => _repo.watch(id);
}
