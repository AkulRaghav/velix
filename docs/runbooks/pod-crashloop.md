# Pod crashlooping

## Diagnostic
```
kubectl -n <ns> describe pod <pod>
kubectl -n <ns> logs <pod> --previous
```

## Common causes + fixes
- OOMKilled → bump memory limits OR fix leak. See [oom](./oom.md).
- Bad config → revert ConfigMap; restart pods.
- Failing readiness/liveness → check probe definition; widen if probes are too tight.
- Image pull → see [service-down](./service-down.md).

## Escalation
5 min on a single replica is OK; 5 min on multiple replicas → page service owner.
