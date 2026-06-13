# 04 — libsignal Binding

The integration boundary between the Flutter client and Signal Foundation's `libsignal-protocol-rust`. The `velix_crypto_core` Rust crate is the only place that links libsignal; everything else uses our typed Dart surface.

## Crate layout

```
cryptocore/
├── Cargo.toml
├── build.rs                  ← per-platform link configuration
└── src/
    ├── lib.rs                ← public C ABI; the only `extern "C"` surface
    ├── ctx.rs                ← per-process Rust runtime + storage handles
    ├── identity.rs           ← create_identity, import_identity
    ├── session.rs            ← X3DH + Double Ratchet wrappers
    ├── sender_keys.rs        ← group session management
    ├── sealed_sender.rs      ← envelope wrap/unwrap
    ├── backup.rs             ← Argon2id-wrapped DEK + DB key handling
    ├── media.rs              ← per-message DEK + per-recipient wrapping
    ├── livekit.rs            ← Insertable Streams frame encrypt/decrypt
    ├── types.rs              ← typed buffers (zeroized on drop)
    ├── error.rs              ← error code → C int mapping
    └── csprng.rs             ← single source of randomness
```

## Build & link

- libsignal-protocol-rust is a Cargo dependency, version-pinned.
- We do not vendor or fork. We track upstream releases.
- The crate compiles to a `staticlib` per target platform.
- Each Flutter platform's build pulls the appropriate static library:
  - iOS: `.a` for arm64 + simulator targets, packaged in xcframework.
  - macOS: same, plus arm64 / x86_64 universal.
  - Android: `.a` per ABI (arm64-v8a, armeabi-v7a, x86_64).
  - Windows: `.lib`.
  - Linux: `.a`.
  - Web: not supported (E2E on web is post-1.0; client falls back to no-3D, no native crypto wisdom — see Phase 5 capability gating).

Reproducible build: `cargo build --release` with pinned dependencies, no build-time network access. The hash of the resulting static library is published per release.

## C ABI surface

The C ABI is intentionally tiny. Every function:

- Returns an `int32_t` error code (0 = success).
- Takes input buffers as `(const uint8_t *ptr, size_t len)` pairs.
- Writes output to caller-allocated buffers; returns required length on too-small via a single error variant.
- Holds no global mutable state except the singleton `Ctx` initialized once.

Example (illustrative, not the full set):

```c
// Returns 0 on success; non-zero error code otherwise.
int32_t velix_create_identity(
    const uint8_t *passphrase_ptr,
    size_t         passphrase_len,
    const uint8_t *handle_ptr,         // optional; null permitted
    size_t         handle_len,
    uint8_t       *out_identity_blob,  // serialized identity material
    size_t         out_capacity,
    size_t        *out_written
);

int32_t velix_encrypt_for_recipient(
    const uint8_t *session_ptr,
    size_t         session_len,
    const uint8_t *plaintext_ptr,
    size_t         plaintext_len,
    uint8_t       *out_ciphertext,
    size_t         out_capacity,
    size_t        *out_written
);

int32_t velix_decrypt_envelope(
    const uint8_t *session_ptr,
    size_t         session_len,
    const uint8_t *envelope_ptr,
    size_t         envelope_len,
    uint8_t       *out_plaintext,
    size_t         out_capacity,
    size_t        *out_written
);

// Backup: wraps the DB key with an Argon2id-derived key from the passphrase.
int32_t velix_export_backup(
    const uint8_t *passphrase_ptr,
    size_t         passphrase_len,
    const uint8_t *db_key_ptr,        // 32 bytes
    uint8_t       *out_blob,
    size_t         out_capacity,
    size_t        *out_written
);
```

## Error codes

Defined once in `error.rs`:

```
0    OK
1    INVALID_ARGUMENT
2    BUFFER_TOO_SMALL          (out_written set to required size)
3    DECRYPT_FAILED            (generic; no information leak)
4    SIGNATURE_INVALID
5    SESSION_NOT_FOUND
6    PROTOCOL_ERROR            (deserialize, unknown version, etc.)
7    KEY_MISSING
8    KEY_EXPIRED
9    INTERNAL                  (unexpected; never expose details to caller)
```

The Dart side maps these to `CryptoError` instances. We deliberately do NOT distinguish "wrong key" from "tampered ciphertext" — both are `DECRYPT_FAILED`. Distinguishing leaks information.

## Memory hygiene

Every buffer holding a private key, plaintext, or session secret is wrapped in a `Secret<T>` type:

```rust
struct Secret<T: Zeroize>(T);

impl<T: Zeroize> Drop for Secret<T> {
    fn drop(&mut self) {
        self.0.zeroize();
    }
}
```

We use the `zeroize` crate. Buffers are zeroed on drop; not just freed.

Plaintext returned to Dart is in a caller-allocated buffer; the Dart side immediately copies into a managed `Uint8List` and instructs the FFI layer to zero the C buffer.

The Dart side does not hold plaintext in any long-lived state. Plaintext lives in the rendering frame and is dropped at the next garbage collection.

## FFI marshalling on the Dart side

```dart
class _NativeBinding {
  _NativeBinding(this._lib);
  final ffi.DynamicLibrary _lib;

  late final velix_create_identity = _lib.lookupFunction<
      ffi.Int32 Function(
          ffi.Pointer<ffi.Uint8>, ffi.IntPtr,
          ffi.Pointer<ffi.Uint8>, ffi.IntPtr,
          ffi.Pointer<ffi.Uint8>, ffi.IntPtr,
          ffi.Pointer<ffi.IntPtr>),
      int Function(
          ffi.Pointer<ffi.Uint8>, int,
          ffi.Pointer<ffi.Uint8>, int,
          ffi.Pointer<ffi.Uint8>, int,
          ffi.Pointer<ffi.IntPtr>)>('velix_create_identity');
}
```

Every FFI call goes through a `using` block that allocates the input buffers, invokes the C function, copies the output, and frees the input buffers — including a final `memset(0, len)` over the input on the Rust side.

## Threading

The Rust core's `Ctx` is `Send + Sync` (libsignal's storage traits are designed for it). The Dart side calls FFI functions from a dedicated background isolate (`crypto_isolate`) so the UI thread never blocks on cryptographic work.

The crypto isolate is spawned at app start, communicates via `SendPort`, and is the only Dart isolate that may call into the FFI binding.

## Storage interface

libsignal exposes traits for prekey, signed prekey, session, sender-key, identity-key, and protocol-store storage. We implement these in Rust, backed by the SQLCipher database that the Dart side opens. The database connection is passed to Rust at startup via a file path + the SQLCipher key (which is read from the OS keychain).

The Rust side does NOT open SQLCipher itself; it receives a typed handle from Dart. This keeps the file-system interaction in Dart where the platform integrations are.

## Versioning

The C ABI is itself versioned via a 1-byte prefix in every input blob and a `velix_abi_version()` function returning a string. Dart checks the ABI version at startup; mismatches are fatal.

ABI v1 is the only deployed version at Phase 7 ship. Future ABI changes are additive (new functions); breaking changes bump the major version and require both Dart and Rust to agree.

## Test surface

The Rust crate has its own test suite:

- Unit tests on each wrapper.
- Wycheproof vectors for AEAD primitives (verifies the underlying libsodium binding doesn't drift).
- libsignal upstream test vectors (verifies our wrapping doesn't break the protocol semantics).
- Property tests on serialization round-trips.

Plus an integration test that runs the full Dart FFI binding against the compiled crate, exercising:

- Create identity → export → import (round-trip).
- Pair device → exchange messages → verify integrity.
- Group send via Sender Keys → 5 recipients → all decrypt.
- Backup → restore → verify all sessions intact.
- Sealed Sender wrap/unwrap.

## Logging

The Rust crate has zero logging output. By construction, it cannot leak via logs because no `log::` or `eprintln!` calls exist in the crate.

Errors propagate via the C ABI return code only.

## Build reproducibility

- Cargo.lock pinned.
- libsignal version pinned.
- Build environment specified (Rust 1.78+, specific toolchain).
- CI builds twice, hashes the static library, requires the hashes to match.
- Per-release artifact hash published at `velix.app/security/builds`.

## What's NOT in the Rust crate

- **HTTP / network code.** The crate is offline; bytes go in, bytes come out.
- **File I/O.** SQLCipher is opened in Dart; the Rust crate gets a handle.
- **OS keychain access.** Same — Dart reads the master key and passes it.
- **UI strings.** Verification flow strings are formatted in Dart.
- **Anything that could leak via logging.** No log statements in any file.

## Banned in the Rust crate

- `unsafe` outside the FFI boundary itself. Memory safety enforced by Rust elsewhere.
- `panic!` in release builds. We use `Result` everywhere; `panic` aborts the process which is worse than returning an error code.
- Allocating large buffers without an explicit size limit.
- Random-call sites outside `csprng.rs`.
- Conditional compilation that changes cryptographic behavior between debug and release.
- A `Default` impl on any private-key type.
- Anything that prints (via `Debug`, `Display`, `dbg!`) the contents of a `Secret<T>`.
