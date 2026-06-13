# OOMKilled

## Diagnostic
```
kubectl -n <ns> describe pod <pod> | grep -A5 'Last State'
kubectl -n <ns> top pods
```

## Mitigations
1. Bump memory limits in Helm values; redeploy.
2. If a leak is suspected, capture a heap profile (`pprof`) and triage.
3. Roll back the latest deploy if the OOM started after a release.

## Banned
- Indefinitely raising memory limits to mask a leak. Limits move once;
  underlying cause is investigated.
