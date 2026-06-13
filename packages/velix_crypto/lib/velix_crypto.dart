/// Velix cryptographic Dart binding.
///
/// Wraps the cryptocore Rust crate via dart:ffi. Public surface is the
/// minimal API the rest of the app uses; the FFI plumbing is in src/.
library;

export 'src/types.dart';
export 'src/identity.dart';
export 'src/session.dart';
export 'src/sender_keys.dart';
export 'src/sealed_sender.dart';
export 'src/backup.dart';
export 'src/media.dart';
export 'src/livekit.dart';
export 'src/exceptions.dart';
