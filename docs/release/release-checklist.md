# Release Checklist

The single per-release checklist used by the release manager. Adjacent to
[Phase 11 doc 07 launch readiness](../phase-11/07-launch-readiness.md), but
applies to every routine release after public 1.0.

## Pre-release (T-3 days)

- [ ] Code freeze for the release branch.
- [ ] All in-flight PRs either merged or rolled to next cycle.
- [ ] Release notes drafted from PR titles.
- [ ] Localized release notes generated (or English fallback documented).

## Release day (T-0)

### Backend

- [ ] CI green on the release commit.
- [ ] Reproducibility check green for all six service images.
- [ ] Cosign signatures present.
- [ ] SBOM attached to GitHub Release.
- [ ] Three-cell phased canary configured (5% → 25% → 100%).
- [ ] On-call confirmed for the next 96 hours.
- [ ] Status page set to "Maintenance: rolling out vN.M.K".

### Mobile

- [ ] TestFlight external testing observed ≥ 7 days.
- [ ] Closed-testing track on Play observed ≥ 5 days.
- [ ] App Store Connect privacy disclosures verified unchanged.
- [ ] Play Store data safety section verified unchanged.
- [ ] Encryption export compliance current (annual filing not lapsed).
- [ ] Phased rollout configured (1% → 10% → 50% → 100%).
- [ ] App Store / Play Store screenshots / preview video current if UI changed.

### Cryptocore (when shipped)

- [ ] Reproducibility check green on three platforms.
- [ ] Cargo.lock unchanged across the release commit.
- [ ] Wycheproof + libsignal upstream test vectors green.
- [ ] No new Critical/High items in the latest audit (see [phase-11/07](../phase-11/07-launch-readiness.md)).

## Rollout monitoring (first 96 hours)

- [ ] p99 send→deliver ≤ 250 ms intra-region.
- [ ] Crash-free rate ≥ 99.5%.
- [ ] ANR rate ≤ 0.5%.
- [ ] p99 cold-start ≤ 800 ms.
- [ ] No P0 incidents.
- [ ] Bug bounty inflow inside expected band.
- [ ] Status page remains Operational.

If any threshold is missed for more than one rollout window: halt the
rollout per [rollback runbook](../runbooks/rollback.md).

## Post-release (T+7 days)

- [ ] Postmortem (if any user-impacting issue).
- [ ] Update [release-history.md](./release-history.md).
- [ ] If a runbook fired: review for edits.

## Public release announcements

- [ ] Blog post (if user-visible features).
- [ ] Release notes published at `velix.app/changelog`.
- [ ] Status page resolves to Operational.

## Banned

- Releases on Friday afternoon (see [freeze-exception runbook](../runbooks/freeze-exception.md)).
- Releases without a green reproducibility check.
- Releases without on-call confirmed.
- Releases without staged rollout configured.
