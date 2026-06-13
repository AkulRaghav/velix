/// The single error taxonomy across all use cases.
///
/// Errors carry only the information needed to render a useful UX
/// message. They never carry message bodies, contact handles, or
/// other PII. Telemetry scrubs further.
sealed class AppError {
  const AppError();
}

final class NetworkError extends AppError {
  const NetworkError({required this.kind, this.detail});
  final NetworkErrorKind kind;
  final String? detail;
}

enum NetworkErrorKind { offline, timeout, server5xx, unauthorized }

final class AuthError extends AppError {
  const AuthError({required this.kind});
  final AuthErrorKind kind;
}

enum AuthErrorKind { tokenExpired, sessionInvalid, biometricRequired }

final class CryptoError extends AppError {
  const CryptoError({required this.kind, this.opaque});
  final CryptoErrorKind kind;
  final String? opaque;
}

enum CryptoErrorKind {
  signFailed,
  verifyFailed,
  decryptFailed,
  keyMissing,
  keyExpired,
}

final class StorageError extends AppError {
  const StorageError({required this.kind});
  final StorageErrorKind kind;
}

enum StorageErrorKind { dbLocked, diskFull, migrationFailed, corrupted }

final class ValidationError extends AppError {
  const ValidationError({required this.field, required this.kind});
  final String field;
  final ValidationErrorKind kind;
}

enum ValidationErrorKind { tooShort, tooLong, invalid, required }

final class NotFoundError extends AppError {
  const NotFoundError({required this.entity});
  final String entity;
}

final class PermissionError extends AppError {
  const PermissionError({required this.required});
  final String required;
}

final class ConflictError extends AppError {
  const ConflictError();
}

final class UnknownError extends AppError {
  const UnknownError();
}
