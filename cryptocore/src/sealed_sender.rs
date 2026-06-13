//! Sealed Sender enforcement.
//!
//! Wraps libsignal's `seal`/`unseal` entry points. The routing service
//! NEVER learns the sender from the envelope shell — only the recipient
//! decrypts and observes the inner sender certificate.
//!
//! See `docs/phase-7/09-sealed-sender.md`.

use crate::error::{CryptoError, CryptoResult};

/// Server-issued sender certificate. Short-lived (≤ 24h).
pub struct SenderCertificate {
    pub bytes: Vec<u8>,
}

/// Wrap an inner ciphertext with the sealed-sender shell.
///
/// Final implementation: libsignal `sealed_sender_encrypt`.
pub fn seal(
    _inner_ciphertext: &[u8],
    _recipient_identity_pub: &[u8; 32],
    _sender_cert: &SenderCertificate,
) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::ProtocolError)
}

/// Unwrap a sealed-sender shell. Returns (sender_account_id, sender_device_id,
/// inner_ciphertext).
///
/// Final implementation: libsignal `sealed_sender_decrypt`.
pub fn unseal(
    _sealed: &[u8],
    _local_identity_priv: &[u8; 32],
) -> CryptoResult<(String, String, Vec<u8>)> {
    Err(CryptoError::DecryptFailed)
}
