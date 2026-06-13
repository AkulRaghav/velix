//! Encrypted media.
//!
//! Per-media random key (32 bytes) wrapped per recipient via the message
//! ratchet. The wrapped key is included in the message envelope; the bytes
//! ride to R2 as ciphertext.
//!
//! See `docs/phase-7/15-encrypted-media.md`.

use crate::csprng::{Csprng, Secret32};
use crate::error::{CryptoError, CryptoResult};

/// Generate a fresh per-media key.
pub fn fresh_media_key() -> CryptoResult<Secret32> {
    Csprng::key32()
}

/// Encrypt a media chunk with the media key.
///
/// We use XChaCha20-Poly1305 with 24-byte nonces; the nonce is part of the
/// per-chunk header so each chunk can be decrypted independently for
/// streaming downloads.
///
/// Final implementation: chacha20poly1305 crate.
pub fn encrypt_chunk(
    _key: &Secret32,
    _associated_data: &[u8],
    _plaintext: &[u8],
) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::ProtocolError)
}

/// Decrypt a media chunk.
///
/// Final implementation: chacha20poly1305 crate.
pub fn decrypt_chunk(
    _key: &Secret32,
    _associated_data: &[u8],
    _ciphertext: &[u8],
) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::DecryptFailed)
}
