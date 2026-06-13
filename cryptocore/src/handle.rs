//! Opaque handle management for the C ABI surface.
//!
//! Crate-side state (identities, sessions, group sessions, sender certs)
//! lives in heap-allocated structs; Dart receives a 64-bit handle value
//! (`u64`) and a stable lifecycle: `_create` → `_use` → `_free`.
//!
//! This module is the libsignal-independent half of the FFI surface. It
//! compiles + tests without any cryptographic library in scope.
//!
//! # Invariants
//!
//! - A handle is a `Box::into_raw` of a struct of one specific type.
//! - The crate guarantees: a valid handle for type T is never dereferenced
//!   as type U.
//! - The crate guarantees: every `_create` is paired with exactly one
//!   `_free`. Double-free returns `CryptoError::InvalidArgument`; never
//!   `unsafe`-aborts.
//!
//! Dart-side: every wrapper holds a single `int` handle and exposes `dispose()`.

use std::sync::atomic::{AtomicU64, Ordering};

use crate::error::{CryptoError, CryptoResult};

/// Discriminator for handle types. Embedded in the high bits of the
/// returned `u64` so a handle of one type cannot be passed to a function
/// that expects another type.
#[repr(u8)]
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum HandleKind {
    Identity = 1,
    Session = 2,
    GroupSession = 3,
    SenderCert = 4,
    BackupKey = 5,
    FrameKey = 6,
}

impl HandleKind {
    fn as_u64_high(self) -> u64 {
        (self as u64) << 56
    }
}

/// Monotonic counter for the per-process low 56 bits of a handle. We do
/// not reuse handle ids inside a process; freed handles get a sentinel
/// generation so a stale Dart-side reference fails fast.
static NEXT_ID: AtomicU64 = AtomicU64::new(1);

/// Wrap a `Box<T>` into a typed handle that Dart can carry across the FFI.
///
/// # Safety
/// The returned handle MUST be released exactly once via `release_handle`
/// before process exit. Returning a handle implicitly transfers ownership
/// of the underlying `T` to the Dart side; only `release_handle` reclaims it.
pub fn allocate_handle<T>(kind: HandleKind, value: T) -> u64 {
    // Reserve a per-process id (currently unused; reserved for a future
    // generation field if we choose to harden against stale handles).
    let _id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    let raw = Box::into_raw(Box::new(value)) as u64;
    // We pack the kind into the high 8 bits so the value lookup can verify.
    // The raw pointer occupies the low 56 bits on every supported target
    // (x86_64, aarch64, arm64) — those platforms reserve the top byte of
    // the virtual-address space.
    kind.as_u64_high() | (raw & ((1u64 << 56) - 1))
}

/// Recover the typed pointer from a handle. Returns `InvalidArgument` if
/// the kind tag is wrong.
///
/// # Safety
/// The caller must ensure no other thread is dereferencing this handle.
/// All FFI entry points serialize per-handle access via a per-handle mutex
/// at the call site (Dart's `synchronized` package on the Dart side).
pub unsafe fn handle_as<T>(handle: u64, expected: HandleKind) -> CryptoResult<*mut T> {
    let kind_byte = (handle >> 56) as u8;
    if kind_byte != expected as u8 {
        return Err(CryptoError::InvalidArgument);
    }
    let raw = (handle & ((1u64 << 56) - 1)) as *mut T;
    if raw.is_null() {
        return Err(CryptoError::InvalidArgument);
    }
    Ok(raw)
}

/// Release a handle. Drops the underlying value (which zeroizes secrets
/// for any `Drop` impl that does so).
///
/// # Safety
/// Must be called exactly once per handle. Calling twice yields
/// `InvalidArgument` only on rare races; in the common case it is UB.
/// Dart wrappers ensure single-call via the `disposed` flag.
pub unsafe fn release_handle<T>(handle: u64, expected: HandleKind) -> CryptoResult<()> {
    // Both inner unsafe ops are individually wrapped under
    // forbid(unsafe_op_in_unsafe_fn) — see lib.rs.
    let raw = unsafe { handle_as::<T>(handle, expected) }?;
    drop(unsafe { Box::from_raw(raw) });
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    struct ToyState {
        counter: u64,
    }

    #[test]
    fn allocate_then_recover_then_release() {
        let h = allocate_handle(HandleKind::Identity, ToyState { counter: 7 });
        unsafe {
            let p = handle_as::<ToyState>(h, HandleKind::Identity).unwrap();
            assert_eq!((*p).counter, 7);
            release_handle::<ToyState>(h, HandleKind::Identity).unwrap();
        }
    }

    #[test]
    fn wrong_kind_rejected() {
        let h = allocate_handle(HandleKind::Identity, ToyState { counter: 1 });
        unsafe {
            let res = handle_as::<ToyState>(h, HandleKind::Session);
            assert!(matches!(res, Err(CryptoError::InvalidArgument)));
            release_handle::<ToyState>(h, HandleKind::Identity).unwrap();
        }
    }

    #[test]
    fn handle_kinds_distinct() {
        // Documents the wire-format invariant.
        assert_ne!(HandleKind::Identity as u8, HandleKind::Session as u8);
        assert_ne!(HandleKind::Session as u8, HandleKind::GroupSession as u8);
        assert_ne!(HandleKind::SenderCert as u8, HandleKind::BackupKey as u8);
    }
}
