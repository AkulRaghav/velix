# Identity error rate burning fast

## Symptoms
Alert `IdentityErrorRateBurnFast`. Sign-in failures, account-creation failures.

## Likely causes
1. Postgres unavailable.
2. Vault unavailable (token issuer can't sign).
3. Bad deploy.

## Diagnostic
```
kubectl -n velix-identity logs -l app=identity --tail=200
kubectl -n vault get pods
```

## Mitigations
1. Vault outage → fail over to standby Vault.
2. Postgres → see [postgres-replication](./postgres-replication.md).
3. Bad deploy → [rollback](./rollback.md).

## Escalation
5 min → service owner; 10 min → IC; 15 min → P0.
