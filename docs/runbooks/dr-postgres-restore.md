# DR — Postgres point-in-time restore

## When
- Production data loss confirmed.
- Bad migration (Contract phase) needs reverting.
- Cell-loss DR (see [dr-cell-loss](./dr-cell-loss.md)).

## RPO / RTO
- RPO: ≤ 5 min (continuous WAL archiving to S3).
- RTO: ≤ 60 min (point-in-time-recovery from snapshot + WAL replay).

## Steps
1. Identify target timestamp T.
2. Snapshot current state (for forensics).
3. Initiate PITR:
   ```
   velixctl pg-restore --service=<svc> --cell=<cell> --target-time=<T>
   ```
4. Pause writes via feature flag (read-only mode).
5. Wait for restore to complete.
6. Validate data integrity (row counts, smoke checks).
7. Re-enable writes.

## Validation
- Compare row counts to pre-restore snapshot.
- Sample the affected service's hot path.
- Run synthetic test transactions.

## Drilled
- Monthly restore drill in staging — restore time recorded; deviation > 25%
  triggers root-cause investigation.
