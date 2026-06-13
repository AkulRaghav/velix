//! Identity key management.
//!
//! Wraps libsignal's IdentityKey + IdentityKeyPair generation.
//!
//! External dependency: this module is implemented against the libsignal
//! Rust crate; that crate is added to Cargo.toml when the cryptocore
//! engineer begins the FFI implementation in Sprint 1.
//!
//! See `docs/phase-7/04-libsignal-binding.md` for the FFI contract.

use crate::csprng::{Csprng, Secret32};
use crate::error::{CryptoError, CryptoResult};
use zeroize::Zeroize;

/// Owned identity keypair. Private half is zeroized on drop.
pub struct IdentityKeyPair {
    pub public: [u8; 32],
    private: Secret32,
}

impl IdentityKeyPair {
    /// Generate a fresh identity keypair via the system CSPRNG.
    ///
    /// Final implementation: delegate to
    /// `libsignal_protocol::IdentityKeyPair::generate(&mut rng)`.
    pub fn generate() -> CryptoResult<Self> {
        let private = Csprng::key32()?;
        // Deriving the public key from the private key is the libsignal
        // ed25519 step. The placeholder below preserves the type shape.
        let public = derive_public_key(private.as_bytes())?;
        Ok(Self { public, private })
    }

    pub fn public(&self) -> &[u8; 32] {
        &self.public
    }

    /// Sign a message with the identity private key.
    ///
    /// Final implementation: delegate to libsignal's identity-key signing
    /// (Ed25519 over the device pubkey || timestamp message).
    pub fn sign(&self, _message: &[u8]) -> CryptoResult<[u8; 64]> {
        // Skeleton: returns InvalidArgument until implemented.
        let _ = &self.private; // suppress unused warning in skeleton
        Err(CryptoError::ProtocolError)
    }
}

impl Drop for IdentityKeyPair {
    fn drop(&mut self) {
        self.public.zeroize();
        // private is zeroized via Secret32 drop
    }
}

/// Verify an Ed25519 signature against a public key and message.
///
/// Final implementation: libsignal's ed25519 verification (constant-time).
pub fn verify_signature(_pubkey: &[u8; 32], _message: &[u8], _sig: &[u8; 64]) -> CryptoResult<()> {
    // Skeleton: refuse all signatures until implemented.
    Err(CryptoError::SignatureInvalid)
}

/// Derive the public key from a 32-byte ed25519 private seed.
///
/// Final implementation: libsignal does this internally during keypair
/// generation. The placeholder returns an empty array shape preserved.
fn derive_public_key(_private: &[u8; 32]) -> CryptoResult<[u8; 32]> {
    Ok([0u8; 32])
}
