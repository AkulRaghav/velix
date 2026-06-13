# Routing latency

## Symptoms
- Alert: `RoutingP99LatencyBudgetBurn`
- p99 SendEnvelope > 250 ms intra-region.

## Likely causes
1. Postgres slow query (idempotency cache miss; lock contention).
2. NATS publish slow (ack window misconfigured; broker overloaded).
3. CPU/memory pressure (HPA hasn't scaled yet).
4. Cold pod (post-deploy; needs warm-up).

## Diagnostic steps
```
# Check pod resource use:
kubectl -n velix-routing top pods

# Postgres slow queries:
kubectl -n postgres exec -it pg-routing-0 -- psql -c \
  "select query, mean_exec_time, calls from pg_stat_statements order by mean_exec_time desc limit 10"

# NATS:
nats stream info velix-deliver
```

## Mitigations
1. If HPA hasn't scaled → manually scale: `kubectl -n velix-routing scale deployment/routing --replicas=12`.
2. If Postgres slow → identify the slow query; add an index if missing; or fail over.
3. If NATS slow → increase ack window via stream config; check broker health.
4. If post-deploy → wait 5 min for warm-up; if still slow, roll back.

## Escalation
- 10 min → page incident commander.
- 15 min → consider rollback.
