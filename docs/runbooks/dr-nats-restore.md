# DR — NATS JetStream restore

## When
- NATS cluster lost.
- Stream replica corrupted.

## Steps
1. Stop the affected stream's consumers.
2. Restore from S3-backed snapshot:
   ```
   nats stream restore <stream> --backup s3://velix-nats-backup/<cell>/<stream>/<snapshot>
   ```
3. Restart consumers; monitor lag.

## RPO
- 5 min — snapshots taken every 5 min.

## RTO
- 30 min for typical streams.
