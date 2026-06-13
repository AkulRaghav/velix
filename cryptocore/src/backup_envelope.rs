//! Backup envelope framing.
//!
//! The backup envelope layout is libsignal-independent — it's just bytes
//! framed around the AEAD ciphertext. We can finalize the framer here and
//! plug AEAD primitives in once they're wired.
//!
//! Layout (per docs/phase-7/14-encrypted-backup.md):
//!
//! ```text
//!  offset  size  field
//!  ------  ----  --------------------------------------------
//!     0     1   version           = 1
//!     1     1   algorithm_id      = 1 (XChaCha20-Poly1305 + Argon2id)
//!     2     2   reserved          = 0
//!     4     1   argon2_iterations
//!     5     2   argon2_mem_kib    (big-endian)
//!     7     1   argon2_parallelism
//!     8    16   argon2_salt
//!    24    24   aead_nonce
//!    48    var  aead_ciphertext (with 16-byte tag suffix)
//! ```

use crate::error::{CryptoError, CryptoResult};

pub const HEADER_LEN: usize = 48;
pub const VERSION_V1: u8 = 1;
pub const ALG_XCHACHA20_POLY1305_ARGON2ID: u8 = 1;

#[derive(Debug, Clone, Copy)]
pub struct EnvelopeHeader {
    pub version: u8,
    pub algorithm_id: u8,
    pub argon2_iters: u8,
    pub argon2_mem_kib: u16,
    pub argon2_lanes: u8,
    pub argon2_salt: [u8; 16],
    pub aead_nonce: [u8; 24],
}

impl EnvelopeHeader {
    pub fn write_into(&self, out: &mut [u8]) -> CryptoResult<()> {
        if out.len() < HEADER_LEN {
            return Err(CryptoError::BufferTooSmall);
        }
        out[0] = self.version;
        out[1] = self.algorithm_id;
        out[2] = 0;
        out[3] = 0;
        out[4] = self.argon2_iters;
        out[5] = (self.argon2_mem_kib >> 8) as u8;
        out[6] = self.argon2_mem_kib as u8;
        out[7] = self.argon2_lanes;
        out[8..24].copy_from_slice(&self.argon2_salt);
        out[24..48].copy_from_slice(&self.aead_nonce);
        Ok(())
    }

    pub fn parse(input: &[u8]) -> CryptoResult<Self> {
        if input.len() < HEADER_LEN {
            return Err(CryptoError::ProtocolError);
        }
        if input[0] != VERSION_V1 {
            return Err(CryptoError::ProtocolError);
        }
        if input[1] != ALG_XCHACHA20_POLY1305_ARGON2ID {
            return Err(CryptoError::ProtocolError);
        }
        let argon2_mem_kib = ((input[5] as u16) << 8) | (input[6] as u16);
        let mut salt = [0u8; 16];
        salt.copy_from_slice(&input[8..24]);
        let mut nonce = [0u8; 24];
        nonce.copy_from_slice(&input[24..48]);
        Ok(Self {
            version: input[0],
            algorithm_id: input[1],
            argon2_iters: input[4],
            argon2_mem_kib,
            argon2_lanes: input[7],
            argon2_salt: salt,
            aead_nonce: nonce,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip_header() {
        let header = EnvelopeHeader {
            version: VERSION_V1,
            algorithm_id: ALG_XCHACHA20_POLY1305_ARGON2ID,
            argon2_iters: 3,
            argon2_mem_kib: 65535,
            argon2_lanes: 1,
            argon2_salt: [0xAA; 16],
            aead_nonce: [0x55; 24],
        };
        let mut buf = [0u8; HEADER_LEN];
        header.write_into(&mut buf).unwrap();
        let parsed = EnvelopeHeader::parse(&buf).unwrap();
        assert_eq!(parsed.version, VERSION_V1);
        assert_eq!(parsed.algorithm_id, ALG_XCHACHA20_POLY1305_ARGON2ID);
        assert_eq!(parsed.argon2_iters, 3);
        assert_eq!(parsed.argon2_mem_kib, 65535);
        assert_eq!(parsed.argon2_lanes, 1);
        assert_eq!(parsed.argon2_salt, [0xAA; 16]);
        assert_eq!(parsed.aead_nonce, [0x55; 24]);
    }

    #[test]
    fn parse_rejects_short_input() {
        let buf = [0u8; HEADER_LEN - 1];
        assert!(matches!(
            EnvelopeHeader::parse(&buf),
            Err(CryptoError::ProtocolError)
        ));
    }

    #[test]
    fn parse_rejects_unknown_version() {
        let mut buf = [0u8; HEADER_LEN];
        buf[0] = 99;
        buf[1] = ALG_XCHACHA20_POLY1305_ARGON2ID;
        assert!(matches!(
            EnvelopeHeader::parse(&buf),
            Err(CryptoError::ProtocolError)
        ));
    }

    #[test]
    fn parse_rejects_unknown_algorithm() {
        let mut buf = [0u8; HEADER_LEN];
        buf[0] = VERSION_V1;
        buf[1] = 99;
        assert!(matches!(
            EnvelopeHeader::parse(&buf),
            Err(CryptoError::ProtocolError)
        ));
    }

    #[test]
    fn write_into_rejects_short_buffer() {
        let header = EnvelopeHeader {
            version: VERSION_V1,
            algorithm_id: ALG_XCHACHA20_POLY1305_ARGON2ID,
            argon2_iters: 3,
            argon2_mem_kib: 65535,
            argon2_lanes: 1,
            argon2_salt: [0; 16],
            aead_nonce: [0; 24],
        };
        let mut buf = [0u8; HEADER_LEN - 1];
        assert!(matches!(
            header.write_into(&mut buf),
            Err(CryptoError::BufferTooSmall)
        ));
    }
}
