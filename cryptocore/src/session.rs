//! Session establishment + Double Ratchet.
//!
//! Wraps libsignal's `SessionStore`, `SessionBuilder`, and the message
//! encrypt/decrypt entry points.
//!
//! See `docs/phase-7/06-double-ratchet.md`.

use crate::error::{CryptoError, CryptoResult};

/// Opaque session id. Lifecycle owned by libsignal's SessionStore.
pub struct SessionId(pub [u8; 32]);

/// Pre-key bundle for X3DH initiation.
pub struct PrekeyBundle {
    pub identity_key: [u8; 32],
    pub signed_prekey: [u8; 32],
    pub signed_prekey_signature: [u8; 64],
    pub one_time_prekey: Option<[u8; 32]>,
}

/// Initiate a session from Alice's side using a fetched bundle.
///
/// Final implementation: libsignal `SessionBuilder::process_pre_key_bundle`.
pub fn initiate_session(
    _local_identity_pub: &[u8; 32],
    _remote_account_id: &str,
    _remote_device_id: &str,
    _bundle: &PrekeyBundle,
) -> CryptoResult<SessionId> {
    Err(CryptoError::ProtocolError)
}

/// Encrypt a plaintext payload for a peer device using the established
/// session. Returns the on-wire ciphertext blob.
///
/// Final implementation: libsignal `SessionCipher::encrypt`.
pub fn encrypt(_session: &SessionId, _plaintext: &[u8]) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::ProtocolError)
}

/// Decrypt a ciphertext from a peer device. Advances the ratchet.
///
/// Final implementation: libsignal `SessionCipher::decrypt`.
pub fn decrypt(_session: &SessionId, _ciphertext: &[u8]) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::DecryptFailed)
}
