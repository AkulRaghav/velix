//! Criterion benches for cryptographic primitives.
//!
//! Phase 9 doc 06 wires these into CI. Targets:
//!   - encrypt_one_recipient ≤ 2 ms iPhone 12
//!   - argon2id ≈ 1000 ms iPhone 12
//!   - sign + verify ≤ 1 ms iPhone 12
//!
//! Run locally:
//!   cargo bench --bench primitives

use std::time::Duration;

#[allow(dead_code)]
fn placeholder_workload() -> u64 {
    let mut x = 1u64;
    for _ in 0..1024 {
        x = x.wrapping_mul(1103515245).wrapping_add(12345);
    }
    x
}

// Real benches use the criterion crate when wired:
//
//   use criterion::{criterion_group, criterion_main, Criterion};
//
//   fn bench_encrypt(c: &mut Criterion) { ... }
//   fn bench_argon2id(c: &mut Criterion) { ... }
//   fn bench_sign_verify(c: &mut Criterion) { ... }
//
//   criterion_group!(benches, bench_encrypt, bench_argon2id, bench_sign_verify);
//   criterion_main!(benches);
//
// Until the criterion crate is added to dev-dependencies (Sprint 1), this
// file compiles as a placeholder so CI's bench discovery stays green.

#[allow(dead_code)]
fn _budget_seconds() -> Duration {
    Duration::from_millis(2)
}

fn main() {
    // No-op binary so cargo bench doesn't fail in skeleton phase.
    let _ = placeholder_workload();
}
