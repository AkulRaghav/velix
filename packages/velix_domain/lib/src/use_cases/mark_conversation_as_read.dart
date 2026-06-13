import '../errors/app_error.dart';
import '../repositories/conversation_repository.dart';
import '../value_objects/ids.dart';
import '../value_objects/result.dart';

class MarkConversationAsReadUseCase {
  MarkConversationAsReadUseCase(this._repo);
  final ConversationRepository _repo;

  Future<Result<void, AppError>> call(ConversationId id) async {
    try {
      await _repo.markAsRead(id);
      return const Ok(null);
    } catch (_) {
      return const Err(UnknownError());
    }
  }
}
