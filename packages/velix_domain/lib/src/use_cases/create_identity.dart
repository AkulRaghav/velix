import '../entities/identity.dart';
import '../errors/app_error.dart';
import '../repositories/identity_repository.dart';
import '../value_objects/result.dart';

class CreateIdentityUseCase {
  CreateIdentityUseCase(this._repo);
  final IdentityRepository _repo;

  Future<Result<Identity, AppError>> call({
    String? displayName,
    String? handle,
  }) async {
    if (handle != null && handle.length > 24) {
      return const Err(
        ValidationError(field: 'handle', kind: ValidationErrorKind.tooLong),
      );
    }
    try {
      final ident = await _repo.createOrSignIn(
        displayName: displayName,
        handle: handle,
      );
      return Ok(ident);
    } catch (_) {
      return const Err(CryptoError(kind: CryptoErrorKind.signFailed));
    }
  }
}
