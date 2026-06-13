# NATS DLQ growing

## Symptoms
Alert `NATSStreamDLQGrowing`. Messages routed to dead-letter queue at > 100/10m.

## Diagnostic
```
nats stream view <stream>-dlq --server $NATS_URL
```

Inspect a sample DLQ message; identify the consumer that's failing.

## Mitigations
1. If a single consumer is failing → roll back its deploy.
2. If a poison message → terminate it (Ack as Term) once verified non-malicious.
3. If pattern is broad → investigate the upstream publish path.

## Banned
- Mass-acknowledging the DLQ without root-cause investigation.
