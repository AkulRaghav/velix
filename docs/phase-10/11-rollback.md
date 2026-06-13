# 11 — Rollback

The single most important production capability after the deploy itself. A rollback that takes more than 5 minutes is a rollback that doesn't help.

## Layers

Three rollback mechanisms, used in escalating severity:

### Tier 1 — Feature flag

Toggle off a feature flag. Instant. No deploy.

```
ops/featureflags/disable.yml
  feature: ai_assistant
  reason: "investigating elevated latency"
```

The flag system fetches every 60 s; effective worldwide within 1 minute.

### Tier 2 — Canary halt

Stop the canary rollout; revert traffic to the stable version.

```
gh workflow run halt-canary.yml --ref main \
  -f cell=prod-us-east-1
```

Within 30 seconds: the edge envoy stops routing canary traffic. Stable is at 100% again. The canary pods stay alive (so we can read them for diagnosis).

### Tier 3 — Argo CD revert

Revert the Argo CD application's `targetRevision` to the previous tag.

```
gh workflow run rollback.yml --ref main \
  -f cell=prod-us-east-1 \
  -f to_version=v1.0.2
```

Within 5 minutes: previous version's pods are running; new version's pods are gone.

## Rollback decision tree

```
Alert fires post-deploy.

  Question 1: Is the issue covered by a feature flag?
    Yes → Tier 1 (toggle flag).
    No → continue.

  Question 2: Is the issue isolated to canary traffic?
    Yes → Tier 2 (halt canary).
    No → continue (it's affecting full production).

  Question 3: Has the new version replaced stable?
    Yes (canary at 100%) → Tier 3 (Argo revert).
    No → Tier 2 + investigate.

  Question 4: Is there a database migration that's already run?
    Yes → see "Data migration safety" below; consult senior engineer.
    No → Argo revert is safe.
```

The on-call walks the tree explicitly during an incident. The decision is logged.

## Data migration safety

Database migrations follow Expand → Migrate → Contract (Phase 10 doc 05).

| Phase | Rollback safe? | Why |
|---|---|---|
| **Expand** (additive only) | Yes | Old code still works; new columns ignored. |
| **Migrate** (backfill data) | Yes | Backfill is a Job, not a service deploy; rollback service code. |
| **Contract** (remove old columns) | **No** without data restore | Old code expects columns that are gone. |

Contract phases require:

- 24 hours since the previous expand.
- A documented decision that "we will not roll back contract."
- A snapshot taken immediately before contract.

If a contract release introduces a bug:

```
Option A: Roll forward — fix the bug; deploy a new release.
Option B: Restore from snapshot — restore the DB to pre-contract state.
   - 4-hour RTO.
   - User data may be lost (the 24-hour grace).
   - Used only for catastrophic bugs.
```

We strongly prefer Option A. Contract releases are reviewed extra carefully exactly because B is painful.

## Runbook: standard rollback

```
ON-CALL: at 14:23, alert "routing.error_rate_burn" fires.

1. Acknowledge in PagerDuty (avoids escalation).
2. Open Grafana → routing dashboard.
3. Confirm: error rate spiked at 14:18, ~6 minutes after canary deploy.
4. Open the deploy markers; confirm v1.0.4 was deployed at 14:18.
5. Decision: TIER 2 (halt canary).
6. Execute:
     gh workflow run halt-canary.yml --ref main -f cell=prod-us-east-1
7. Wait 60 seconds.
8. Verify error rate returns to baseline.
9. Slack #incidents: "v1.0.4 canary halted in prod-us-east-1; error rate
   recovered. Investigating."
10. Open Tempo → trace samples from the canary period.
11. Identify the regression.
12. File a postmortem ticket with deadline 48 hours.

Total elapsed: ~5 minutes from alert to mitigation.
```

## Runbook: full rollback

```
ON-CALL: at 14:23, alert "routing.error_rate_burn" + customer reports.

1. Acknowledge.
2. Confirm v1.0.4 has rolled past canary; it's at 50% in prod-us-east-1.
3. Decision: TIER 3 (Argo revert).
4. Execute:
     gh workflow run rollback.yml --ref main \
       -f cell=prod-us-east-1 \
       -f to_version=v1.0.3
5. Workflow opens an Argo PR; auto-approves; Argo syncs.
6. Within 5 minutes: previous-version pods running.
7. Verify metrics return to baseline.
8. Halt rollout to prod-eu-west-1 + prod-ap-southeast-1.
9. Status page: "Resolved at 14:30; rolled back to v1.0.3."
10. Postmortem within 24 hours.

Total elapsed: ~7 minutes.
```

## Runbook: rollback with active migration

```
ON-CALL: at 14:23, alert fires; v1.0.4 included a contract migration that's
already run.

1. Acknowledge.
2. Recognize the migration was a contract phase.
3. Senior engineer paged in addition to on-call.
4. Decision tree:
   - Is the impact severe enough to justify data restoration?
     Yes → restore from snapshot (4-hour RTO).
     No → roll forward with a fix.
5. Default: ROLL FORWARD.
   - Author a one-line patch.
   - Hotfix release v1.0.4.1.
   - Deploy across cells with abbreviated canary.
6. Status page: "Investigating; mitigation in progress."

This is the worst-case rollback scenario. Contract migrations are rare and
heavily reviewed precisely because of this.
```

## Mobile rollback

iOS / Android apps in the wild cannot be "rolled back" in the cloud sense. The user has the binary. Mitigations:

- **Phased rollout (Apple/Google staged release):** halt the rollout. New users don't get the bad version.
- **Force update:** the app checks a server-side `min_supported_version` on launch; if it's below threshold, the app refuses to start and prompts to update from the store.
- **Server-side feature flag:** disable the new feature without re-deploying the app.

For a critical mobile bug:

```
1. Halt staged rollout immediately (App Store Connect / Play Console).
2. Server-side: disable any feature that triggers the bug.
3. Hotfix release: v1.0.4.1.
4. Submit for expedited review (Apple) / immediate (Google).
5. Roll out fix.
6. If users on bad version are stuck: force update via min_supported_version bump.
```

## Database backups for emergency restore

Per Phase 10 doc 09:

- Hourly snapshots retained 7 days.
- Daily snapshots retained 30 days.
- WAL continuous; PITR within 7 days.

Restore from snapshot:

```
1. Provision a fresh RDS instance from snapshot (~30 min).
2. Update Vault's database secret to point to new instance.
3. Restart pods (ExternalSecrets refreshes in <1 min).
4. Verify writes against new instance.
5. Promote new instance to primary.
6. Re-establish replication.
```

Total: ~1-2 hours for a fresh restore. Most rollbacks don't need this.

## Verifying rollback

After any rollback:

- [ ] Error rate baseline restored.
- [ ] Latency baseline restored.
- [ ] Synthetic probes green.
- [ ] No new alerts.
- [ ] Customer support has not received reports of new issues.
- [ ] Incident channel updated with mitigation status.

## Postmortem

Every rollback (Tier 2 or 3) generates a postmortem within 48 hours. Template:

```markdown
# Postmortem: <date> <service> rollback

## Summary
What happened in 1-2 sentences.

## Timeline
- HH:MM Deploy of vX.Y.Z to canary in <cell>.
- HH:MM Alert fired.
- HH:MM Mitigation: halt canary / Argo revert / etc.
- HH:MM Recovery confirmed.

## Impact
- Affected users: count or %.
- Duration: minutes.
- SLO impact: yes/no; budget consumed.

## Root cause
What broke and why.

## Detection
How we noticed (which alert; could we have noticed faster).

## Mitigation
What we did. Could it have been faster?

## Lessons learned
- What went well.
- What went poorly.
- What we'll change.

## Action items
- [ ] action — assignee — due date
```

Postmortems are blameless. The goal is to fix the system, not the person.

## Banned

- Rollbacks without postmortem.
- Rollbacks that take longer than 5 minutes (the runbook is wrong; fix it).
- Hand-edited Argo CD applications during rollback (use the workflow).
- Skipping observation periods after rollback.
- "Roll forward" decisions made by a single engineer (always two).
- Contract-phase migrations without explicit approval.
- Rollbacks during freeze windows without on-call + manager + senior engineer approval.
