# 08 — Scalability Roadmap

Capacity targets, infrastructure scaling stages, and the cost discipline that goes with them.

## Stages and capacity profile

| Stage | DAU | MAU | Concurrent connections (peak) | Messages/sec (peak) | Concurrent calls (peak) |
|---|---|---|---|---|---|
| Closed beta | 200 | 200 | 100 | 50 | 20 |
| Public launch | 25k | 100k | 8k | 4k | 1k |
| 6mo post-launch | 200k | 600k | 60k | 30k | 8k |
| 18mo | 1M | 3M | 250k | 150k | 40k |
| 36mo | 5M | 15M | 1M | 800k | 200k |

These are conservative engineering targets. Real growth curves are unpredictable; what matters is the headroom multiplier at each stage. **Target: 5× headroom over current peak at all times.**

## Infrastructure stages

### Stage A — closed beta (Weeks 9–16)
- Single region (us-east). One Postgres primary + one replica. Three-node Redis. Three-node NATS. One LiveKit cluster.
- Single Kubernetes cluster (EKS), one node group, ~20 pods total.
- Cost target: < $1,500 / month.

### Stage B — public 1.0 (Months 6–12)
- Two regions (us-east, eu-west). Cell-based deployment, sticky home cell per user.
- Postgres primary + 2 replicas per region with synchronous replica for failover.
- Redis cluster (6 nodes) per region.
- NATS JetStream cluster (5 nodes) per region.
- LiveKit cluster (3 SFU nodes) per region, autoscaling to 10.
- 2 K8s clusters, multi-AZ. CDN for media via Cloudflare R2 + Cloudflare in front.
- Cost target: < $25k / month at 100k MAU.

### Stage C — 1M MAU (Months 12–24)
- Three regions (add ap-southeast). Cell scaling.
- Postgres horizontally sharded by `account_id` hash. Initial 8 shards, room to 64.
- Redis: sharded cluster, 24 nodes per region with replicas.
- NATS: 7-node clusters, JetStream replication factor 3.
- LiveKit: per-region clusters of 20+ SFU nodes, geographic load balancing.
- Per-region K8s, ArgoCD for multi-cluster GitOps.
- Cost target: < $250k / month.

### Stage D — 10M+ MAU (Year 2+)
- Five+ regions. Per-region cells with deeper sub-cells for hot regions.
- Postgres sharded to 64+, with tiered storage for cold message envelopes.
- Read replicas in lower-cost zones for non-latency-critical reads.
- Specialized services break out of the monolith if and when they justify the operational cost.
- Continuous capacity testing via shadow traffic and synthetic load.

## Per-component scaling notes

### Edge Gateway (Go)
- Stateless. Scale horizontally by CPU. Anycast for region selection.
- Horizontal pod autoscaler on connections-per-pod and CPU.

### Identity & Auth
- Stateless reads, stateful writes.
- Postgres for the source of truth.
- Reads cached aggressively in Redis with short TTL.

### Routing / Realtime
- Sharded by `account_id` hash. Each shard owns N devices.
- WebSocket connections terminate at edge, internal routing via NATS subjects.
- Hot devices (very active) get dedicated pods via consistent hashing with virtual nodes.

### Media Service
- Signed URLs only. R2 does the heavy lifting.
- Service is mostly an authorizer + metadata writer.

### Persistence Layer
- Postgres: sharded by `account_id`. Initial single primary per region; sharding kicks in at Stage C.
- Hot table is `message_envelope` (ciphertext + minimal meta + TTL).
- TTL'd rows are dropped at retention boundary.
- Encrypted messages older than 30 days are pruned unless still queued for an offline device.

### Redis
- Cluster mode. Sharded by account.
- Used for: presence, typing, push de-dup, rate limit windows, online tokens, ephemeral pairing handshakes.
- Memory pressure is the typical scaling trigger.

### NATS JetStream
- Subject hierarchy: `velix.deliver.<account>.<device>`.
- JetStream stream per region; consumer groups per service.
- Replication factor 3, max 5GB per stream.

### LiveKit
- Per-region SFU clusters. Geographic JWT routing.
- Capacity: ~500 concurrent participants per node (8GB / 4 vCPU). Plan for 50% utilization at peak.

## Performance targets across the stack

| Metric | Target |
|---|---|
| Edge → Routing latency p99 | ≤ 5 ms |
| Send → ack p99 (intra-region) | ≤ 250 ms |
| Send → ack p99 (cross-region) | ≤ 600 ms |
| Push delivery time p95 | ≤ 4 s |
| Cold start (mid-tier Android, release build) | ≤ 800 ms |
| Database read p99 | ≤ 20 ms |
| Database write p99 | ≤ 50 ms |
| LiveKit join time p95 | ≤ 700 ms |
| Voice MOS (good network) | ≥ 4.2 |
| Voice MOS (200ms RTT, 1% loss) | ≥ 4.0 |
| Frame stability (client) | ≥ 99% inside 16.6 ms |

## Cost discipline

We will set a **cost-per-MAU ceiling** at each stage. If we cross it, we stop and optimize before scaling further. Reasonable initial target:

| Stage | Cost / MAU / month |
|---|---|
| Public 1.0 | ≤ $0.25 |
| 1M MAU | ≤ $0.25 |
| 10M MAU | ≤ $0.18 |

A subscription ARPU of $4–6 / month for paid users sustains this comfortably with even a modest 5–10% paid conversion.

## Disaster scenarios and recovery objectives

| Scenario | RTO | RPO |
|---|---|---|
| Single pod failure | < 30 s | 0 |
| Single AZ failure | < 5 min | 0 (synchronous replica) |
| Region failure | < 30 min | < 60 s |
| Postgres corruption (any region) | < 4 hr | < 5 min |
| Full account-database loss (catastrophic) | < 24 hr | < 5 min from PITR |

We will test region failover quarterly. We will test Postgres restore monthly.

## What we are not optimizing for

- Microsecond-level message latency. 250 ms is the bar; chasing 50 ms costs disproportionate operational complexity.
- Linear cost-per-MAU below $0.10. The privacy and feature posture justifies a higher floor than ad-funded products.
- Five-nines availability. Four-nines is honest and achievable. Five-nines is a marketing claim more than an engineering target for this size of team.

## Open questions for Phase 8

1. Tiered storage for cold message envelopes (S3-class) — when does it pay for itself?
2. Whether to use Citus (Postgres extension for sharding) or hand-rolled application-level sharding.
3. Whether to introduce ScyllaDB or similar for the message envelope table in Stage D.
4. Edge-cached presence vs centralized.
