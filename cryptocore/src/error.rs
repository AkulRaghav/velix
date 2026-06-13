//! Error codes returned across the C ABI.
//!
//! See `docs/phase-7/04-libsignal-binding.md` for the contract.
//!
//! We deliberately do NOT distinguish between "wrong key" and "tampered
//! ciphertext" in the error code; both are `DECRYPT_FAILED`. Distinguishing
//! leaks information that reduces the cost of cryptographic attacks.

#[repr(i32)]
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum CryptoError {
    Ok = 0,
    InvalidArgument = 1,
    BufferTooSmall = 2,
    DecryptFailed = 3,
    SignatureInvalid = 4,
    SessionNotFound = 5,
    ProtocolError = 6,
    KeyMissing = 7,
    KeyExpired = 8,
    Internal = 9,
}

impl CryptoError {
    pub fn as_int(self) -> i32 {
        self as i32
    }
}

/// `Result<T, CryptoError>` with an erased success path; the C ABI returns
/// data via out-pointers, not via the result type.
pub type CryptoResult<T> = Result<T, CryptoError>;
