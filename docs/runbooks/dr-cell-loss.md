# Disaster recovery — full cell loss

Reference: docs/phase-10/09-dr-and-bcp.md.

## Symptoms
- Cloud provider regional outage.
- All synthetic probes for one cell red.
- Status page (manual): cell marked Major Outage.

## Targets
- RTO: ≤ 30 min for routing fail-over.
- RPO: ≤ 5 min (NATS JetStream + Postgres replication).

## Steps

### 1. Acknowledge
- On-call confirms the cell is genuinely down (not a probe issue).
- Page the incident commander.
- Update the status page within 5 min of confirmation.

### 2. Steer traffic
- DNS / GeoDNS layer shifts the affected cell's traffic to the other two.
  In production this is a one-line config change in our DNS provider:
  ```
  velixctl traffic shift --from=<cell> --to=<cell-1>,<cell-2>
  ```
- Argo CD reconciles; the surviving cells autoscale on demand.

### 3. Validate fail-over
- p99 send→deliver returns within 10 min.
- Crash-free rate stays > 99.5%.
- Bug bounty inflow doesn't spike beyond expected band.

### 4. Drain the dead cell
- The data in the dead cell is lost only if the region is permanently
  destroyed. NATS JetStream replays from a remote-replicated mirror.
- For active accounts in the dead cell: their messages queued in JetStream
  drain to recipients via the surviving cells once consumers re-attach.
- For accounts whose home is the dead cell: identity records are
  replicated (read replica in another cell); traffic continues.

### 5. Recovery
- Rebuild the cell once the cloud region recovers.
- Run terraform apply against the new region; same module.
- Argo CD reconciles; the cell rejoins the topology.

### 6. Post-incident
- Full postmortem within 10 business days.
- Update DR runbook with lessons learned.

## Quarterly drill checklist

- Schedule a fail-over drill in staging (not production) every quarter.
- Validate RTO + RPO actuals; update if they drift.
- Train the on-call team — every on-call must drive at least one drill
  per year.
