import '../errors/app_error.dart';
import '../repositories/identity_repository.dart';
import '../repositories/message_repository.dart';
import '../value_objects/ids.dart';
import '../value_objects/result.dart';

class SendMessageUseCase {
  SendMessageUseCase({
    required MessageRepository messages,
    required IdentityRepository identity,
  })  : _messages = messages,
        _identity = identity;

  final MessageRepository _messages;
  final IdentityRepository _identity;

  Future<Result<MessageId, AppError>> call({
    required ConversationId conversationId,
    required String body,
    MessageId? replyToId,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const Err(
        ValidationError(field: 'body', kind: ValidationErrorKind.required),
      );
    }
    if (trimmed.length > 8000) {
      return const Err(
        ValidationError(field: 'body', kind: ValidationErrorKind.tooLong),
      );
    }

    final ident = await _identity.watch().first;
    if (ident == null) {
      return const Err(AuthError(kind: AuthErrorKind.sessionInvalid));
    }

    try {
      final id = await _messages.sendText(
        conversationId: conversationId,
        senderId: ident.id,
        body: trimmed,
        replyToId: replyToId,
      );
      return Ok(id);
    } catch (_) {
      // The repository wraps drift errors; anything raw here is an unknown.
      return const Err(UnknownError());
    }
  }
}
