# 10 — Release Process

The shape of a release. From a green main merge to users seeing a new version.

## Versioning

We use **semver** with a `+build` suffix:

```
1.0.3+abc1234   ← public version 1.0.3, built from commit abc1234
```

| Component | When it bumps |
|---|---|
| Major (1 → 2) | Breaking changes (gRPC v2, schema breaking, UX overhaul) |
| Minor (1.0 → 1.1) | New features, backward compatible |
| Patch (1.0.0 → 1.0.1) | Bug fixes only |

## Release types

| Type | Who can ship | Approval |
|---|---|---|
| **Patch** | any engineer | one reviewer |
| **Minor** | any engineer | one reviewer + on-call |
| **Major** | senior engineer / lead | full team review + design + security |
| **Hotfix** | on-call (incident) | manager |

## Release cadence

- **Backend:** continuous; multiple production deploys per week. Each is a patch or minor.
- **Mobile (iOS / Android):** every 2 weeks for major channels. Hotfixes faster (Apple expedited review).
- **Major versions:** ~quarterly.

## Release checklist (per release)

Before tagging the release:

- [ ] All PRs merged are green in CI.
- [ ] Staging deployment of `main` has been observed for at least 1 week without P0 alerts.
- [ ] Synthetic probes against staging are 99%+ green for the past 24 hours.
- [ ] Performance benches show no regression (Phase 9 doc 02).
- [ ] Security scan shows no new HIGH or CRITICAL CVEs.
- [ ] Release notes drafted (auto-generated from PR titles, hand-edited).
- [ ] Database migrations (if any) follow expand → migrate → contract pattern (Phase 10 doc 05).
- [ ] Feature flags for risky changes are configured.
- [ ] Rollback plan tested (the rollback workflow runs successfully on staging).
- [ ] Notification to #releases Slack channel.
- [ ] Status page draft (if user-facing changes).
- [ ] On-call notified of deploy window.

After tagging:

- [ ] Tag pushed to git: `v1.0.3`.
- [ ] CI builds the image; re-tags as `v1.0.3`.
- [ ] Release notes published to GitHub Releases.
- [ ] Mobile builds (iOS via TestFlight, Android via Internal Testing) submitted.
- [ ] Backend phased rollout begins (Phase 10 doc 05).

## Mobile release sequence

```
1. Engineer tags v1.0.3.
2. CI builds:
   - iOS: archives to App Store Connect via Fastlane.
   - Android: bundles to Play Console via Fastlane.
3. Internal testing (TestFlight / Play Internal): ~24 hours.
4. Engineer reviews; sends to external testing.
5. External testing (TestFlight beta / Play Open Testing): ~3 days.
6. Engineer reviews; submits for review.
7. Apple review: 24-48 hours typical.
8. Google review: 6-24 hours typical.
9. On approval:
   - Phased release on iOS (1% → 10% → 50% → 100% over 7 days).
   - Staged rollout on Android (1% → 10% → 50% → 100%).
10. Monitor crash rates; halt rollout if regressions.
```

## Backend release sequence

```
1. Engineer tags v1.0.3 (after main has been on staging for 1 week).
2. CI re-tags images as v1.0.3.
3. Release-bot opens PR updating ops/argocd/apps/prod-us-east-1.yaml's targetRevision.
4. Approver merges (on-call).
5. Argo CD syncs to prod-us-east-1.
6. Edge envoy traffic-splits 5% to canary.
7. Observation window: 30 min.
8. If green: promote to 25% (15 min observation), then 100%.
9. After prod-us-east-1 at 100% for 30 min: promote prod-eu-west-1.
10. Same sequence per cell.
11. Total release time: 4-6 hours per cell × 3 cells = 12-18 hours for full deployment.
```

## Release notes

Two flavors:

### Internal (engineering)

Generated from PR titles since last tag. Includes:

- All PRs merged.
- Database migrations with expand/contract status.
- Feature flag changes.
- Performance bench delta.
- Security scan delta.

### Public (users)

Hand-curated. Covers:

- New features (user-visible).
- Bug fixes (user-visible).
- Performance improvements (user-visible).

We do NOT include:

- Internal refactors.
- Architectural changes invisible to users.
- Internal feature flag toggles.

## Freeze windows

| Window | What's frozen |
|---|---|
| Apple holiday freeze (mid-Dec to early Jan) | App Store submissions; backend OK |
| Google holiday freeze (similar) | Play Store submissions; backend OK |
| Velix-internal freeze (week before any major release) | Backend deploys outside hotfix |
| Friday after 4 PM | Production backend deploys |
| Major US/EU/APAC holidays | Production backend deploys |

Hotfixes for incidents bypass freezes with on-call + manager approval.

## Hotfix process

```
Incident → on-call assesses severity:
   P0: deploy hotfix immediately.

   Process:
     1. on-call creates a hotfix branch from the current production tag.
     2. minimal fix, single PR.
     3. CI runs the standard pipeline (~12 min).
     4. Two engineers review (one is on-call).
     5. Tag as v1.0.3+hotfix.1 (preserves the production version + hotfix counter).
     6. Skip canary if incident is severe; deploy directly to all cells.
     7. Monitor; verify; status page update.
     8. Postmortem within 24 hours.
```

For mobile hotfixes: Apple expedited review (`request_expedited`) + same Google process.

## Per-component release independence

| Component | Release cadence | Versioning |
|---|---|---|
| `apps/velix_app` | every 2 weeks (mobile review cadence) | semver |
| Backend services | continuous; multiple/week | semver per service (independent) |
| `cryptocore` | bumped on cryptographic changes only | strict semver |
| `velix_design` / `velix_motion` / `velix_3d` | bumped with the app | strict semver (consumers pin) |

A backend service can ship without a corresponding app release. The proto contracts (Phase 6 doc 02) are stable; new fields are additive.

## Concurrency between releases

GitHub Actions concurrency control:

```yaml
concurrency:
  group: production-release
  cancel-in-progress: false
```

Two production releases in flight at once → second waits. We never ship two backend releases simultaneously.

## What gets logged about a release

- Release event in `velix_deploy_total{cell, version}` metric.
- Annotation on every dashboard at the deploy moment.
- Slack message in #releases.
- GitHub Release page with notes.
- Argo CD's history.

## Rollback decisions

Per Phase 10 doc 11. Summary:

- Canary metrics regress > thresholds → automatic halt.
- Production metrics regress post-promotion → on-call decision.
- Rollback time: ≤ 5 minutes.

## Banned

- Releasing without a green CI on the tagged commit.
- Releasing without observation in staging for at least the documented window.
- Skipping the canary stage for "small" or "obvious" releases.
- Hand-edited release notes that omit user-impacting changes.
- Releases without a rollback plan.
- Releases that mix expand and contract migrations in one tag.
- Releases on Friday afternoons.
- Releases during freeze windows without manager + on-call approval.
