# 09 — Disaster Recovery

What we promise we can recover from. RTO and RPO targets per scenario, with rehearsed runbooks.

## RTO / RPO matrix

(RTO = recovery time objective: how long to restore service. RPO = recovery point objective: how much data we may lose.)

| Scenario | RTO | RPO | Plan reference |
|---|---|---|---|
| Single pod crash | < 30 s | 0 | Kubernetes self-heals |
| Single AZ failure | < 5 min | 0 (sync replica) | runbook/az-failure |
| Single region failure | < 30 min | < 60 s | runbook/region-failover |
| Postgres primary loss (single cell) | < 5 min | 0 (sync replica) | runbook/postgres-failover |
| Postgres corruption | < 4 hr | < 5 min | runbook/postgres-restore-pitr |
| Cell-wide loss | < 4 hr | < 5 min PITR | runbook/cell-restore |
| R2 bucket loss (regional) | < 24 hr | < 1 hr | runbook/r2-restore |
| LiveKit cluster loss | < 5 min (calls drop, re-establish elsewhere) | call drops | runbook/livekit-failover |
| Full multi-region failure (the whole company) | < 24 hr | < 5 min | runbook/full-restore |
| Vault loss | < 4 hr | 0 (Raft replicated; cold-stored unseal keys) | runbook/vault-restore |
| Image registry loss (GHCR) | rebuilds from source | 0 | runbook/registry-rebuild |

These are commitments. We rehearse to verify; we restore from real backups quarterly.

## Backup strategy

### Postgres

- **WAL archiving:** continuous to S3 via pgBackRest. Per-cell S3 bucket; cross-region replicated.
- **Snapshots:**
  - Hourly snapshots retained 7 days.
  - Daily snapshots retained 30 days.
  - Weekly snapshots retained 6 months.
- **PITR (Point-in-Time Recovery):** any moment within the last 7 days.
- **Replication lag** alerted via Phase 10 doc 07.
- **Restore drill:** monthly; we restore to a fresh staging cluster from the previous day's snapshot and verify schema + a sample row read.

### Redis

- **AOF persistence:** every 1 second fsync.
- **RDB snapshots:** every 5 minutes.
- **Replicated:** primary + 2 replicas per shard.

Loss of all Redis is acceptable: presence resets, rate limits reset, idempotency caches re-populate from Postgres. Total user-visible impact: < 60 seconds.

### NATS JetStream

- **Per-stream replication factor 3.**
- **Cross-region mirroring** for the `lifecycle` and `audit` streams (DR purposes).
- **Hot path (`delivery` stream):** in-cell only; cross-region delivery is via the cross-cell forwarder service, not NATS mirroring.
- **Stream retention** per Phase 6 doc 06.

If a NATS cluster loses quorum: messages stuck until restored. Routing service falls back to direct-delivery via Postgres queue read (bypasses NATS). Performance degrades, but no data is lost.

### Cloudflare R2

- R2 has cross-region replication built in.
- Per-cell bucket replicates to a sibling region's bucket.
- RPO < 1 hour.
- For DR, the replica becomes the active bucket; clients re-fetch via new presigned URLs.

### Vault

- Raft cluster with 3+ voters.
- Auto-unseal via cloud KMS.
- Snapshots taken hourly; retained 30 days.
- Cold-stored unseal keys held by 3 senior engineers (Shamir-secret-shared with threshold 2).

### Image registry

- GHCR is GitHub-managed; we trust its durability.
- We build images from source on demand if needed.
- All images are reproducible (Phase 10 doc 03); rebuilding produces bit-identical artifacts.

## DR Runbooks (excerpts)

### runbook/postgres-failover

```
Trigger:
  primary unhealthy for > 60 s
  OR
  primary AZ down

Steps:
  1. Page on-call + senior engineer.
  2. Confirm primary is dead via cloud console.
  3. Promote sync replica to primary.
  4. Update Postgres connection string in Kubernetes secret.
     (External Secrets Operator pulls from Vault; rotate the underlying secret.)
  5. Roll out a no-op deploy to force pod restart with new conn string
     (alternatively, trigger a SIGTERM + SIGUSR2 restart on each pod).
  6. Verify routing.SendEnvelope p99 returns to baseline within 5 min.
  7. Provision a new sync replica from the new primary.
  8. Postmortem within 5 days.

RTO target: 5 min. Actual best-case: 90 seconds (cloud auto-failover for RDS).
```

### runbook/cell-restore

```
Trigger:
  one cell completely lost (region-level outage; cells in other regions OK)

Steps:
  1. Page everyone.
  2. Confirm scope: is this a region issue or wider?
  3. If region-only:
       - Update DNS to remove the dead cell from anycast.
       - Users in that cell experience signin/recovery flow only;
         their cell is unhealthy.
       - Update status page.
  4. Restore in a new region:
       - Provision a fresh cell via terraform (~30 min for the EC2 / RDS spin).
       - Restore Postgres from cross-region snapshot.
       - Wait for replication catchup.
       - Argo CD reconciles services into the new cell.
       - Update DNS to route the original cell's users to the new region.
  5. Verify with synthetic probes.
  6. Postmortem.

RTO target: 4 hours. Mostly bound by terraform + RDS provisioning time.
```

### runbook/full-restore

```
Trigger:
  catastrophic: all cells down at once.
  (Hypothetical; would require multiple independent failures or
  a coordinated attack on cloud infrastructure.)

Steps:
  1. Convene incident response (war room).
  2. Status page: "service unavailable; investigating."
  3. Restore cells in priority order:
       - prod-us-east-1 first (largest user count)
       - prod-eu-west-1 second
       - prod-ap-southeast-1 third
  4. For each cell:
       - terraform apply (provision infra, ~30 min).
       - Restore Postgres from S3 WAL + most recent snapshot.
       - Verify Redis bootstraps fresh (acceptable; presence/rate-limit/etc.).
       - Restore Vault from snapshot or unseal new instance.
       - Argo CD reconciles services.
       - Validate via synthetic probes.
       - Update DNS for the cell.
  5. Communicate progress hourly via status page.
  6. Postmortem.

RTO target: 24 hours total. Partial service available much earlier.
```

## DR drills

| Drill | Cadence |
|---|---|
| AZ failure (kill one AZ in staging) | quarterly |
| Postgres failover (forced in staging) | quarterly |
| Region failover (DNS-level) | quarterly |
| Cell restore from cold backup | annually |
| Full multi-region restore (tabletop, then partial live) | annually |
| Vault unseal-key reconstruction | annually (tabletop) |
| Image rebuild from source | annually |

Drills are scheduled, announced internally, and produce a postmortem. Failure to meet RTO / RPO is a P0 issue.

## Backup verification

- Every backup is checksummed.
- Restore drills verify a sample row matches expected.
- Backup integrity dashboard shows green/red per cell per backup type.

## Cross-region considerations

- User data is sticky to home cell. We do not "rebalance" users across cells without explicit migration.
- Cross-region disaster (e.g., us-east-1 lost) means us-east-1 users wait for restore.
- We do NOT auto-spin up a us-east-1 user's account in eu-west-1 — that would conflict with their cell-bound encryption sessions.

## Encryption keys and DR

- User-side encryption keys (identity, MDK, session keys) live on the user's device.
- Server has no copy of these keys. DR cannot recover user content because the server never had it.
- Backups (Phase 7 doc 11) are encrypted with the user's passphrase. DR restores the ciphertext; the user's device decrypts.

This means: a server-side restore from backup gives the user their data ciphertext back, exactly as before. If the user has lost their passphrase too, server-side restore does not help them. Phase 7 doc 17 documented this.

## What DR cannot do

- Recover data lost due to user error (e.g., user deleted a conversation; the deletion is already replicated to all their devices).
- Recover deleted accounts (account deletion is a hard delete with 30-day grace period; after the grace period, the data is irrecoverable).
- Decrypt user content. Ever.

## What DR runbooks expect

- Engineers familiar with the runbooks (annual training).
- Cold-stored unseal keys accessible (Vault).
- terraform state available (S3-backed).
- CI accessible (GHCR + GitHub Actions).
- Cloud provider access (cross-account roles configured).

## Banned

- "Manual" recovery procedures not in a runbook.
- DR plans that require a single engineer to execute alone.
- DR plans that depend on production credentials being accessible from non-production environments.
- Skipping the postmortem after any drill or actual incident.
- Backups that haven't been restored within the last 30 days (untested backups are not backups).
- Backup retention shorter than the documented RPO.
