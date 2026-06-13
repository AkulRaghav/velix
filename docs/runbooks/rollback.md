# Three-tier rollback

Reference: docs/phase-10/11-rollback-and-recovery.md.

## Tier 1 — Feature flag (≤ 1 minute)

For any change shipped behind a flag.

```
ldcli flag rollout disable <flag-name>
```

Confirm Grafana dashboard shows error rate dropping. No deploy needed.

## Tier 2 — Canary halt (≤ 3 minutes)

For changes mid-rollout (5% / 25% / 100% canary).

```
argocd app set <app> --revision <last-known-good>
argocd app sync <app>
```

Halts the canary; previous version handles 100% of traffic again.

## Tier 3 — Full Argo revert (≤ 5 minutes)

For changes fully rolled out.

```
git revert <bad-commit>
git push origin main
# Argo CD auto-syncs; HPA stabilizes within ~2 min.
```

If repo push is blocked, manually pin the chart values:

```
argocd app set <app> -p image.digest=<previous-digest>
argocd app sync <app>
```

## Database migrations

Phase 10 doc 11: migrations follow Expand → Migrate → Contract. Rollback is
safe through the Migrate phase.

- Expand phase: rollback is trivial (the column is additive).
- Migrate phase: rollback requires running the down-migration manually.
- Contract phase: cannot roll back without restoring from backup.

If a migration was promoted past Contract and a regression surfaces:

1. Disable writes to the affected service (feature flag → read-only mode).
2. Restore from the most recent point-in-time snapshot ([dr-postgres-restore](./dr-postgres-restore.md)).
3. Replay messages from NATS JetStream replay window (24h retention).

## Mobile rollback

- Halt staged rollout in App Store Connect / Play Console.
- If the bad version is widely installed: ship `min-version` bump as a
  hot-config update; the client shows a "please update" screen until
  the user updates.

## Metrics target

- p50 rollback execution time: ≤ 2 minutes.
- p99 rollback execution time: ≤ 5 minutes.
- Drilled quarterly.
