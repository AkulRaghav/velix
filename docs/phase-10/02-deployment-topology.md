# 02 — Deployment Topology

The physical and logical shape of Velix in production. Cell-based, regional, with explicit failover and DR posture.

## Cells

A cell is a self-contained deployment unit. One Postgres cluster, one Redis cluster, one NATS cluster, one Kubernetes cluster, one LiveKit cluster — all in the same region.

```
                       ┌───────────────────────────┐
                       │   Cell: us-east-1          │
                       │   • velix_app users home   │
                       │     here based on signup   │
                       │   • Independent failure    │
                       │     domain                 │
                       └───────┬───────────────────┘
                               │
   ┌───────────────────────────┼─────────────────────────────────┐
   │                           │                                  │
┌──▼─────────────┐    ┌────────▼──────────┐    ┌─────────────────▼──┐
│ Cell us-west-2 │    │  Cell eu-west-1   │    │ Cell ap-southeast-1│
└────────────────┘    └───────────────────┘    └────────────────────┘
```

Three cells at Stage B (public 1.0, target 100k MAU per Phase 1 doc 08): us-east-1, eu-west-1, ap-southeast-1.

A user's home cell is determined at signup by their inferred region. The mapping is sticky: once a user is in cell X, all their data lives there.

## What's in a cell

| Component | Per cell |
|---|---|
| Edge layer (envoy) | 2-replica deployment behind anycast |
| identity service | 3 replicas (HPA on connections) |
| routing service | 3 replicas (HPA on connections, sticky-hash on device_id) |
| media service | 2 replicas |
| push service | 2 replicas |
| call service | 2 replicas |
| notifier service | 1 replica |
| Postgres primary | 1 |
| Postgres synchronous replica | 1 (same AZ, different node) |
| Postgres async replicas | 2 (different AZs) |
| Redis cluster | 6 nodes (3 master + 3 replica) |
| NATS JetStream cluster | 5 nodes |
| LiveKit SFU cluster | 3 nodes (autoscaling 3-10) |
| Cloudflare R2 (regional bucket) | per cell |

Each cell holds:

- ~30 backend pods at 100k MAU
- ~6 stateful services
- 1 LiveKit cluster

## What's NOT in a cell

- The OHTTP relay (third-party operator; not Velix infra).
- The AI provider (Anthropic, OpenAI; external).
- The CDN (Cloudflare; global, not per-cell).
- Apple App Store / Google Play Store assets (global).
- Build/CI infrastructure (single global cluster).

## Cross-region traffic

Default: zero cross-region synchronous traffic on the hot path.

A user in cell us-east-1 sends to a recipient in cell eu-west-1:

```
1. Sender's client connects to us-east-1 edge.
2. routing service in us-east-1 enqueues envelope in us-east Postgres.
3. routing service publishes velix.deliver.<recipient_account>.<recipient_device>.
4. NATS in us-east-1 sees the recipient's home is eu-west-1 (lookup via
   identity-service-cached account → home-cell map).
5. The envelope is forwarded to eu-west-1 via cross-region NATS bridge or
   a dedicated forwarder service.
6. routing in eu-west-1 ingests + delivers to the recipient.
```

Cross-region adds ~200 ms p99 vs intra-region's 250 ms p99. Both within the budget from Phase 1 doc 08.

## Database posture per cell

```
Postgres cluster:
  primary           (RW, sync replication)
  sync replica      (RO, used for failover)
  async replica 1   (RO, used for backups + analytics)
  async replica 2   (RO, used for read scaling)

Connections:
  identity service     primary (writes), sync replica (HA reads)
  routing service      primary (writes), async replica 2 (cold reads)
  media service        primary
  push service         primary
  call service         primary
  notifier service     primary

pgbouncer in transaction-pooling mode in front of the primary.
```

## Redis posture per cell

```
Redis cluster:
  6 nodes (3 master + 3 replica)
  ACL: per-service user with prefix-only permissions (Phase 6 doc 05)
  TLS-only connections
  AOF persistence (1 sec fsync) + RDB snapshots every 5 min
```

## NATS posture per cell

```
JetStream cluster:
  5 nodes (3 voter + 2 observer in MR mode)
  Replication factor 3
  Stream retention per Phase 6 doc 06

Cross-region: stream mirroring for `lifecycle` and `audit` (DR purposes).
Cross-region delivery for `deliver.*` is via a dedicated bridge service.
```

## Kubernetes posture per cell

- One EKS or GKE cluster.
- Three node groups:
  - **Latency-sensitive** (edge, identity, routing): m6i.large (4 vCPU, 16 GB) or n2-standard-4. Reserved instances at 60% capacity; on-demand for spike.
  - **Throughput** (media, push, notifier): m6i.large or n2-standard-4. Spot-eligible.
  - **Stateful proxies** (NATS clients, Redis sentinels): t3.medium reserved.
- Postgres is RDS / Cloud SQL (managed).
- LiveKit SFU runs on dedicated nodes (high egress + UDP).

## LiveKit per cell

- Autoscaling 3-10 nodes per region.
- Per-node capacity ≈ 500 concurrent participants (Phase 6 doc 07).
- JWT issued by the call service of the same cell.

## Cloudflare R2

- Per-cell bucket: `velix-media-us-east-1`, `velix-media-eu-west-1`, etc.
- A user's media goes to their home cell's bucket.
- Cross-region access is rare (cross-region DM with a media attachment); R2 handles it transparently with extra latency.

## DNS topology

```
ai.velix.app                    → CDN (global) → AI gateway (Velix-operated, multi-region)
api.velix.app                   → anycast → nearest cell's edge
api-us-east-1.velix.app         → us-east-1 edge (used by clients with sticky home cell)
ohttp-relay.<provider>.com      → third-party relay
livekit-us-east-1.velix.app     → us-east-1 LiveKit
push.velix.app                  → CDN-fronted push gateway
```

Clients are issued an `api_endpoint` URL at signup that points to their home cell's edge. Subsequent connections use that endpoint directly.

## Environments

Three environments. Each has its own cells, its own credentials, its own data.

| Environment | Purpose | Topology |
|---|---|---|
| **dev** | engineer's local dev loop | docker-compose stack on the engineer's machine |
| **staging** | pre-production verification | one cell (us-east-1), production-shaped, sanitized data |
| **production** | actual users | multi-cell (us-east-1, eu-west-1, ap-southeast-1) |

Strict separation:
- Different AWS / GCP accounts per environment.
- Different secrets in Vault.
- Different domain names.
- No production data ever leaves production. No staging data ever reaches production.
- Engineer access to production is audited and dual-control.

## Promotion path

```
[engineer's branch]
        │  PR, lint, unit tests, integration tests
        ▼
[main branch] — merged after PR approval
        │  CI: build images, sign, push to registry
        ▼
[staging cluster] — auto-deployed on every main merge
        │  smoke tests, perf benches
        │  manual approval to promote
        ▼
[production cluster] — phased rollout (canary 5% → 25% → 100%)
        │  deploy to one cell first; observe; then others
        ▼
[fully deployed]
```

Phased rollout per cell. A bad release in us-east-1 doesn't reach eu-west-1 if the canary catches it.

## Deployment scheduling

- **Production deploys: business-hours only.** No deploys after 4 PM in the on-call's local timezone, no Friday afternoon deploys, no holiday deploys.
- **Hotfixes:** dual-approval, can deploy outside windows.
- **Feature flags:** the preferred path for risky changes — deploy disabled, enable on a schedule.

## Failover

| Failure | Response |
|---|---|
| Single pod | Kubernetes restarts; HPA scales out if needed |
| AZ outage | Multi-AZ deployments handle; Postgres failover to sync replica |
| Region outage | Anycast directs to a neighbor cell; users in the failed cell experience read-only mode (their data is in the dead cell's Postgres) |
| Total cell loss | Run-book: restore from cross-region backups; spin up new cell; reroute users |

A user "in" a failed cell does not magically re-home to a healthy cell. They wait for their cell to recover. RTO target: 30 minutes per Phase 1 doc 08.

## Disaster recovery

| Scenario | RTO | RPO | Plan |
|---|---|---|---|
| AZ failure | < 5 min | 0 (sync replica) | Postgres failover + multi-AZ pods |
| Single region failure | < 30 min | < 60 s (async replicas) | DR docs, cross-region bridges remain |
| Multi-region failure | < 24 hr | < 5 min PITR | Restore from S3 WAL archive in surviving regions |
| R2 bucket loss | < 24 hr | < 1 hr (cross-region replication) | R2's cross-region replication restores |
| Postgres corruption | < 4 hr | < 5 min | PITR from WAL |
| LiveKit cluster loss | < 5 min | call drops | Clients reconnect to a healthy cluster |

DR drills run quarterly per Phase 1 doc 08. Phase 10 doc 09 has the runbooks.

## Cell-as-a-blast-radius

Adding a cell is mechanical: terraform module + Helm install + DNS entry + a Postgres backup-restore-or-fresh-spin. We commit to:

- A new cell can be brought up in 4 hours by one engineer.
- Cell shutdown is similarly mechanical (drain users to neighbor cells via a one-time migration; not common but supported).
- Adding a cell does not require code changes.

## What's NOT in this topology

- Multi-master Postgres. Conflicts are resolved server-side; we stay single-primary per cell.
- Active-active across regions. The sync cost is too high.
- Self-hosted CDN. We use Cloudflare.
- Self-hosted Postgres. We use RDS / Cloud SQL.
- Custom service mesh. We use envoy + cert-manager (Phase 6 doc 09).
