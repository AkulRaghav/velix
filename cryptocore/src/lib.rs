//! Velix cryptographic core.
//!
//! Wraps Signal Foundation's libsignal-protocol-rust crate and a small set
//! of audited primitives (libsodium-equivalent via RustCrypto crates). Exposes
//! a stable C ABI for Dart FFI consumption.
//!
//! See `docs/phase-7/04-libsignal-binding.md` for the FFI contract.
//!
//! # Crate posture
//!
//! - No `unsafe` outside the `extern "C"` boundary itself.
//! - No logging. The crate is silent by construction.
//! - No `panic!` in release builds; use `Result` everywhere.
//! - All secret material wrapped in `Secret*` types that zeroize on drop.
//! - `csprng::Csprng` is the only source of randomness.
//! - All AEAD nonces are produced internally; never accepted from Dart.
//!
//! # What this crate does
//!
//! - Wraps libsignal: identity creation, X3DH, Double Ratchet, Sender Keys,
//!   Sealed Sender.
//! - Wraps AEAD primitives: XChaCha20-Poly1305 (preferred), AES-256-GCM
//!   (hardware-accelerated where useful).
//! - Wraps Argon2id for passphrase-derived backup wrapping.
//! - Provides the LiveKit Insertable Streams frame encrypt/decrypt.
//!
//! # What this crate does NOT do
//!
//! - HTTP / network code.
//! - File I/O. SQLCipher is opened in Dart; this crate gets a handle.
//! - OS keychain access.
//! - UI strings.
//! - Logging (zero log statements anywhere in the crate).

#![forbid(unsafe_op_in_unsafe_fn)]
#![warn(clippy::all)]

pub mod backup;
pub mod backup_envelope;
pub mod csprng;
pub mod error;
pub mod ffi;
pub mod handle;
pub mod identity;
pub mod livekit;
pub mod media;
pub mod sealed_sender;
pub mod sender_keys;
pub mod session;
pub mod test_vectors;

pub use error::{CryptoError, CryptoResult};

/// ABI version. Increments on breaking C ABI changes.
pub const ABI_VERSION: u32 = 1;

/// Returns the ABI version. Dart calls this at startup; mismatches are fatal.
#[no_mangle]
pub extern "C" fn velix_abi_version() -> u32 {
    ABI_VERSION
}
