//! Sender Keys for group messaging.
//!
//! Wraps libsignal's GroupSessionBuilder + GroupCipher.
//!
//! See `docs/phase-7/07-sender-keys.md`.

use crate::error::{CryptoError, CryptoResult};

/// Distinguishes a (sender, group) tuple in the local store.
pub struct SenderKeyName {
    pub group_id: [u8; 16],
    pub sender_id: [u8; 32],
}

/// Generate a fresh sender-key distribution message for a new group session.
///
/// Final implementation: libsignal `GroupSessionBuilder::create`.
pub fn create_distribution(_name: &SenderKeyName) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::ProtocolError)
}

/// Process a peer's sender-key distribution message.
///
/// Final implementation: libsignal `GroupSessionBuilder::process`.
pub fn process_distribution(
    _name: &SenderKeyName,
    _distribution_message: &[u8],
) -> CryptoResult<()> {
    Err(CryptoError::ProtocolError)
}

/// Encrypt a plaintext for the group, addressed at the sender's chain.
///
/// Final implementation: libsignal `GroupCipher::encrypt`.
pub fn encrypt(_name: &SenderKeyName, _plaintext: &[u8]) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::ProtocolError)
}

/// Decrypt a sender-key ciphertext.
///
/// Final implementation: libsignal `GroupCipher::decrypt`.
pub fn decrypt(_name: &SenderKeyName, _ciphertext: &[u8]) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::DecryptFailed)
}
