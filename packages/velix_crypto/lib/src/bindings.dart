import 'dart:ffi';
import 'dart:io' show Platform;

/// Dynamic library lookup for cryptocore.
///
/// On iOS the static library is linked into the app binary; lookup uses
/// `DynamicLibrary.process()`. On Android the library is shipped as
/// `libvelix_crypto_core.so`. On macOS it is statically linked.
DynamicLibrary _open() {
  if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libvelix_crypto_core.so');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libvelix_crypto_core.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('velix_crypto_core.dll');
  }
  throw UnsupportedError('cryptocore: unsupported platform');
}

/// Lazily-opened dylib handle. Loaded on first FFI call.
final DynamicLibrary cryptocore = _open();

/// ABI version exported by cryptocore. Bumped on every breaking change;
/// Dart compares at startup and treats a mismatch as fatal.
typedef _AbiVersionC = Uint32 Function();
typedef _AbiVersion = int Function();

final _AbiVersion _abiVersion =
    cryptocore.lookupFunction<_AbiVersionC, _AbiVersion>('velix_abi_version');

/// Reads the cryptocore ABI version. Compared against [expectedAbiVersion]
/// at app startup.
int abiVersion() => _abiVersion();

/// The ABI version Dart was built against. Increments alongside `cryptocore`.
const int expectedAbiVersion = 1;

/// Asserts the loaded cryptocore matches the expected ABI version. Called
/// once during bootstrap.
void assertAbiCompatible() {
  final got = abiVersion();
  if (got != expectedAbiVersion) {
    throw StateError(
      'cryptocore ABI mismatch: dart expects $expectedAbiVersion, got $got',
    );
  }
}

/// Ping export exposed by the FFI module; used for smoke tests.
typedef _PingC = Int32 Function();
typedef _Ping = int Function();

final _Ping ffiPing =
    cryptocore.lookupFunction<_PingC, _Ping>('velix_ffi_ping');
