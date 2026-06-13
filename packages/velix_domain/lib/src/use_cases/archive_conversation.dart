import '../errors/app_error.dart';
import '../repositories/conversation_repository.dart';
import '../value_objects/ids.dart';
import '../value_objects/result.dart';

class ArchiveConversationUseCase {
  ArchiveConversationUseCase(this._repo);
  final ConversationRepository _repo;

  Future<Result<void, AppError>> call(ConversationId id) async {
    try {
      await _repo.archive(id);
      return const Ok(null);
    } catch (_) {
      return const Err(UnknownError());
    }
  }
}
