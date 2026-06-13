# Postgres replication lag

## Diagnostic
```
kubectl -n postgres exec -it pg-<svc>-0 -- psql -c \
  "select now()-pg_last_xact_replay_timestamp() as replay_lag from pg_stat_replication"
```

## Mitigations
1. Check primary load; identify long-running queries killing WAL apply.
2. Failover if replication lag > 60 s for > 5 min:
   ```
   velixctl pg-failover --service=<svc> --cell=<cell>
   ```
3. Rebuild lagging replica from base backup if it can't catch up.
