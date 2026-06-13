# Service down

## Symptoms
- Alert: `ServiceDown`
- `up{job=~"velix-.*"} == 0`
- Synthetic probes red.

## Likely causes
1. Pod crash-looping (see [pod-crashloop](./pod-crashloop.md)).
2. Image pull failure (registry outage / image deleted).
3. ConfigMap or Secret missing (Vault Agent failed to inject).
4. NetworkPolicy blocking necessary egress.

## Diagnostic steps
```
kubectl -n velix-<service> get pods
kubectl -n velix-<service> describe pod <pod>
kubectl -n velix-<service> logs <pod> --previous
```

## Mitigations
1. If image pull failure → confirm image exists; retry pull.
2. If Vault inject failure → check Vault Agent logs; verify role exists.
3. If NetworkPolicy → check recent NetworkPolicy changes; revert.
4. If unclear → roll back to last known good (see [rollback](./rollback.md)).

## Escalation
- 5 min → page service owner.
- 10 min → page incident commander.
- 15 min → declare P0; war-room.
