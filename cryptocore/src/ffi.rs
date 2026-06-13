//! C ABI surface.
//!
//! Every function returns a `CryptoError` integer; data flows out via
//! caller-owned out buffers with explicit length pointers.
//!
//! Lifetimes:
//!   - All buffers passed in are non-owning (`*const u8`); Dart allocates
//!     and owns them across the call.
//!   - All buffers passed out are non-owning (`*mut u8`); Dart allocates
//!     them at the size returned by the corresponding `_len` query.
//!   - Sessions, identities, and group sessions are heap-allocated by the
//!     crate; Dart receives an opaque handle (`u64`); explicit `_free`
//!     functions deallocate.
//!
//! See `docs/phase-7/04-libsignal-binding.md` for the full contract.
//!
//! ABI compatibility: bumps on every breaking change. Dart calls
//! `velix_abi_version()` at startup; mismatch is fatal.

use crate::error::CryptoError;

/// Reads the ABI version sentinel; validates that the FFI surface links.
///
/// The full FFI surface (~ 60 functions) is authored in this module against
/// the contract in `docs/phase-7/04-libsignal-binding.md`. The skeleton
/// below establishes the patterns; the functions are filled in alongside
/// the matching identity/session/sender_keys/sealed_sender modules.
///
/// Mirrored at the top of `lib.rs` for symmetry.
#[no_mangle]
pub extern "C" fn velix_ffi_ping() -> i32 {
    CryptoError::Ok as i32
}

// Identity surface (sketch — implemented when libsignal lands):
//
// #[no_mangle]
// pub unsafe extern "C" fn velix_identity_generate(out_pub: *mut u8) -> i32 { ... }
//
// #[no_mangle]
// pub unsafe extern "C" fn velix_identity_sign(
//     identity_handle: u64,
//     msg: *const u8, msg_len: usize,
//     out_sig: *mut u8) -> i32 { ... }
//
// Session surface, group surface, sealed-sender surface, backup surface,
// media surface, livekit surface follow the same shape: handle in,
// caller-allocated buffers out, integer error code returned.
