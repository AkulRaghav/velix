//! Encrypted backup.
//!
//! Argon2id key derivation + XChaCha20-Poly1305 AEAD. Backup payloads are
//! envelope-formatted with a fixed header version + algorithm id.
//!
//! See `docs/phase-7/14-encrypted-backup.md`.

use crate::csprng::Csprng;
use crate::error::{CryptoError, CryptoResult};

const BACKUP_HEADER_VERSION: u8 = 1;

/// Argon2id parameters tuned for ≈ 1000 ms on iPhone 12. CI verifies the
/// timing on floor devices (Pixel 4a / Galaxy A52) per Phase 9 doc 05 R9.
pub struct Argon2Params {
    pub mem_kib: u32,     // memory cost (default 64 MiB = 65_536 KiB)
    pub iterations: u32,  // time cost
    pub parallelism: u32, // lanes
    pub salt: [u8; 16],
}

impl Argon2Params {
    pub fn default_with_random_salt() -> CryptoResult<Self> {
        let salt = Csprng::random_bytes::<16>()?;
        Ok(Self {
            mem_kib: 64 * 1024,
            iterations: 3,
            parallelism: 1,
            salt,
        })
    }
}

/// Derive a 32-byte master backup key from a passphrase.
///
/// Final implementation: argon2 crate (already in Cargo.toml).
pub fn derive_master_key(_passphrase: &[u8], _params: &Argon2Params) -> CryptoResult<[u8; 32]> {
    Err(CryptoError::ProtocolError)
}

/// Encrypt a backup payload with the master key. Output:
///   [1 byte version | 16 bytes salt | 24 bytes nonce | ciphertext+tag]
///
/// Final implementation: chacha20poly1305 crate (already in Cargo.toml).
pub fn encrypt_backup(
    _master_key: &[u8; 32],
    _params: &Argon2Params,
    _plaintext: &[u8],
) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::ProtocolError)
}

/// Decrypt a backup payload. Validates the header version + parameter
/// signature.
///
/// Final implementation: chacha20poly1305 crate.
pub fn decrypt_backup(_master_key: &[u8; 32], _payload: &[u8]) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::DecryptFailed)
}

/// Header version exposed for integration tests + the migrator.
pub fn header_version() -> u8 {
    BACKUP_HEADER_VERSION
}
