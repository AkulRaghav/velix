/// The cryptographic-trust state of a conversation as understood by the
/// local device. See `docs/phase-2/01-color-tokens.md` for the visual
/// contract and `docs/phase-2/09-component-contracts.md` for the trust
/// material modifier.
enum TrustState {
  /// All participants' identity keys are verified by the local user.
  verified,

  /// Standard E2E — keys exchanged but not manually verified.
  standard,

  /// Verification is missing or inconsistent. Treat with care.
  unverified,

  /// A peer device key has changed since last interaction; the user
  /// should re-verify before treating new messages as authentic.
  rekeyed,
}
