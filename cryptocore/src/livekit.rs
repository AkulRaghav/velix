//! LiveKit Insertable Streams E2EE.
//!
//! Per-participant frame encrypt/decrypt for audio + video tracks. The
//! shared key is established out-of-band via the message ratchet (a
//! "call-key" message at call setup); rotates on every participant change.
//!
//! See `docs/phase-7/16-livekit-e2ee.md`.

use crate::error::{CryptoError, CryptoResult};

/// Frame key. 32 bytes; rotated per participant set.
pub struct FrameKey(pub [u8; 32]);

/// Encrypt a video / audio frame.
///
/// We use AES-256-GCM here (hardware-accelerated on both iOS and Android)
/// rather than ChaCha to minimize per-frame overhead at 30 fps × multiple
/// participants. Nonce is `frame_counter || track_id || sender_id`; never
/// reused.
///
/// Final implementation: aes-gcm crate (added when this module is wired).
pub fn encrypt_frame(
    _key: &FrameKey,
    _frame_counter: u64,
    _track_id: u32,
    _sender_id: &[u8; 16],
    _plaintext: &[u8],
) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::ProtocolError)
}

/// Decrypt a video / audio frame.
///
/// Final implementation: aes-gcm crate.
pub fn decrypt_frame(
    _key: &FrameKey,
    _frame_counter: u64,
    _track_id: u32,
    _sender_id: &[u8; 16],
    _ciphertext: &[u8],
) -> CryptoResult<Vec<u8>> {
    Err(CryptoError::DecryptFailed)
}
