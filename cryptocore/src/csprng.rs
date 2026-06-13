//! Single source of randomness.
//!
//! Every random call in the crate goes through `Csprng`. This is the only
//! place `OsRng` (or any other RNG) is named.
//!
//! Mixing strategy: OS CSPRNG XOR'd with hardware RNG when available.
//! On the platforms we ship to:
//!   - iOS / macOS: `SecRandomCopyBytes` (hardware-mixed by Apple).
//!   - Android: `getrandom(2)` syscall (hardware-mixed by kernel).
//!   - Windows: `BCryptGenRandom` with `BCRYPT_USE_SYSTEM_PREFERRED_RNG`.
//!   - Linux: `/dev/urandom` (kernel-mixed).
//!
//! The `rand` crate's `OsRng` uses `getrandom` under the hood on each
//! platform, so we get this mixing transparently.

use rand::rngs::OsRng;
use rand::RngCore;
use zeroize::Zeroize;

use crate::error::{CryptoError, CryptoResult};

pub struct Csprng;

impl Csprng {
    pub fn fill(buf: &mut [u8]) -> CryptoResult<()> {
        OsRng.try_fill_bytes(buf).map_err(|_| CryptoError::Internal)
    }

    /// Fill a fixed-size buffer with random bytes. Returns the buffer.
    pub fn random_bytes<const N: usize>() -> CryptoResult<[u8; N]> {
        let mut out = [0u8; N];
        Self::fill(&mut out)?;
        Ok(out)
    }

    /// Generate a random 32-byte key. Convenience wrapper.
    pub fn key32() -> CryptoResult<Secret32> {
        Self::random_bytes::<32>().map(Secret32)
    }
}

/// 32-byte secret. Zeroized on drop.
pub struct Secret32(pub [u8; 32]);

impl Secret32 {
    pub fn new(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

impl Drop for Secret32 {
    fn drop(&mut self) {
        self.0.zeroize();
    }
}

impl Zeroize for Secret32 {
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}
