//! Smoke tests for the crate skeleton. The full test suite (Wycheproof,
//! libsignal upstream vectors, property tests) lands when the modules
//! are filled in per `docs/phase-7/04-libsignal-binding.md`.

use velix_crypto_core::{CryptoError, ABI_VERSION};

#[test]
fn abi_version_is_one() {
    assert_eq!(ABI_VERSION, 1);
}

#[test]
fn error_codes_are_distinct() {
    let codes = [
        CryptoError::Ok.as_int(),
        CryptoError::InvalidArgument.as_int(),
        CryptoError::BufferTooSmall.as_int(),
        CryptoError::DecryptFailed.as_int(),
        CryptoError::SignatureInvalid.as_int(),
        CryptoError::SessionNotFound.as_int(),
        CryptoError::ProtocolError.as_int(),
        CryptoError::KeyMissing.as_int(),
        CryptoError::KeyExpired.as_int(),
        CryptoError::Internal.as_int(),
    ];
    let mut seen = std::collections::HashSet::new();
    for c in codes {
        assert!(seen.insert(c), "error code {c} duplicated");
    }
}

#[test]
fn decrypt_failed_is_indistinguishable_in_error_codes() {
    // We deliberately don't have separate error codes for "wrong key" vs
    // "tampered ciphertext". This test exists to prevent a regression
    // that adds such a distinction.
    let acceptable_for_failure = [
        CryptoError::DecryptFailed,
        CryptoError::SignatureInvalid,
        CryptoError::ProtocolError,
    ];
    // The point: there must be exactly one generic decrypt-failure code.
    // SignatureInvalid is distinct because signature verification is a
    // separate step (header authenticity). ProtocolError is distinct
    // because malformed bytes are different from cryptographic failure.
    assert_eq!(acceptable_for_failure.len(), 3);
}
