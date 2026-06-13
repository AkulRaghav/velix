# Runbooks

Every alert in `infra/monitoring/prometheus/rules/` has a runbook here. The
runbook URL is in the alert annotations; PagerDuty links to it directly.

## Index

| Alert | Runbook |
|---|---|
| RoutingErrorRateBurnFast | [routing-error-rate](./routing-error-rate.md) |
| RoutingP99LatencyBudgetBurn | [routing-latency](./routing-latency.md) |
| IdentityErrorRateBurnFast | [identity-error-rate](./identity-error-rate.md) |
| ServiceDown | [service-down](./service-down.md) |
| PodCrashLooping | [pod-crashloop](./pod-crashloop.md) |
| OOMKilled | [oom](./oom.md) |
| CertExpiringIn14d | [cert-rotation](./cert-rotation.md) |
| PostgresReplicationLag | [postgres-replication](./postgres-replication.md) |
| NATSStreamDLQGrowing | [nats-dlq](./nats-dlq.md) |
| RedisHighMemory | [redis-memory](./redis-memory.md) |

## Disaster recovery

| Scenario | Runbook |
|---|---|
| Full cell loss | [dr-cell-loss](./dr-cell-loss.md) |
| Postgres restore from backup | [dr-postgres-restore](./dr-postgres-restore.md) |
| NATS JetStream restore | [dr-nats-restore](./dr-nats-restore.md) |

## Release ops

| Operation | Runbook |
|---|---|
| Three-tier rollback | [rollback](./rollback.md) |
| Hotfix release | [hotfix-release](./hotfix-release.md) |
| Friday-freeze exception | [freeze-exception](./freeze-exception.md) |

## How to author a runbook

Every runbook follows this template:

```
# <runbook name>

## Symptoms
What the on-call sees first.

## Likely causes
Top 3 causes ordered by frequency.

## Diagnostic steps
Concrete commands and queries.

## Mitigations
Concrete mitigations ordered from least-invasive to most-invasive.

## Rollback / escalation
When to escalate; who to page.

## Post-incident
Postmortem template link; required attendees.
```

Runbooks are versioned; every change is reviewed and dated.
