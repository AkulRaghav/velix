# Routing error rate burning fast

## Symptoms
- Alert: `RoutingErrorRateBurnFast`
- Grafana → "Velix — Overview" → "Service error rate by service" shows routing >1%.
- User reports: "messages not sending."

## Likely causes
1. Postgres unavailable (replication lag, primary failover, exhausted connections).
2. NATS JetStream stream lag (publish ack timeouts).
3. Bad deploy — recent rollout with regression.

## Diagnostic steps
1. Check the recent deploy timeline:
   ```
   kubectl -n velix-routing rollout history deployment/routing
   argocd app history routing-us-east-1
   ```
2. Check Postgres health:
   ```
   kubectl -n postgres exec -it pg-routing-0 -- psql -c 'select count(*) from pg_stat_activity'
   ```
3. Check NATS JetStream lag:
   ```
   nats stream report --server $NATS_URL | grep velix-routing
   ```
4. Look at the dashboard "RoutingService p99" panel.

## Mitigations
1. **If a deploy correlates** → roll back via Argo CD: `argocd app rollback routing-<cell>`. (See [rollback](./rollback.md).)
2. **If Postgres** → fail over: `velixctl pg-failover --service=routing --cell=<cell>`. Check replication lag returns < 1s.
3. **If NATS** → scale stream consumers; check the DLQ.
4. **If unclear and impact is widespread** → enable feature flag `routing.read-only` in LaunchDarkly; routing returns 503 deliberately while we investigate.

## Rollback / escalation
- 5 min without improvement → page incident commander.
- 10 min without improvement → enable `disable-cell` flag for the affected cell; traffic shifts to the other two.
- 15 min → declare P0; status page update; war-room.

## Post-incident
- Postmortem within 5 business days.
- Required attendees: routing service owner, on-call lead, security lead if any keys/secrets handled.
- Include: timeline, root cause, mitigation, what worked, what didn't, action items.
