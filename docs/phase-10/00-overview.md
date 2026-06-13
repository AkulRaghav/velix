# 00 — DevOps & Production Overview

## Position

Phase 10 is the bridge between "the system exists" and "the system serves users at 4 AM on a Tuesday without an engineer awake." Everything in this phase exists to make Velix's production posture *boring* — predictable, reproducible, monitored, recoverable.

We do not invent new operational practices. We adopt what works at well-run companies of our size class, calibrated to the architecture we built in Phases 1–9.

## Pillars

1. **Reproducible builds.** Two CI runs of the same commit produce identical artifacts. Verified by digest match in CI.
2. **Cell-based deployment.** Independent failure domains per region (Phase 6 doc 01 + Phase 1 doc 06). A bad cell does not take down the company.
3. **No surprises in production.** Every deploy is observed by a green CI run; every change is feature-flagged or canaried; every regression is caught at staging or canary.
4. **Secrets never live in code, env files, or images.** Vault holds them. Services fetch on startup with short-lived credentials.
5. **Observability is non-negotiable.** Every service emits structured logs, traces, and metrics. Alerts have runbooks. SLOs are published.
6. **Rollback is a one-button operation.** Every deploy is reversible without data migration drama.
7. **Disaster recovery is rehearsed, not aspirational.** Quarterly DR drills. Restore-from-backup tested monthly.
8. **Submission readiness is a checklist, not a sprint.** App Store / Play Store submission has a documented sequence.
9. **No prior guarantee weakens.** Phases 1–9 architectural, cryptographic, AI, accessibility, motion, and performance commitments survive Phase 10 unchanged.

## Stack (locked, Phase 10)

| Layer | Choice | Why |
|---|---|---|
| Container runtime | Kubernetes 1.30+ (EKS in AWS-primary cells, GKE in any GCP cells) | Mature, multi-cloud-portable |
| Container build | docker buildx + multi-stage Dockerfiles | Reproducible builds with caching |
| Image registry | GHCR (GitHub Container Registry) | Tied to source; signed via Sigstore |
| Image signing | cosign + Sigstore | Keyless signing via GitHub OIDC |
| CI | GitHub Actions | Same provider as code; OIDC simplifies secrets |
| CD | Argo CD (GitOps) | Declarative; reconciles cluster state from git |
| Secrets | HashiCorp Vault | Audit log; short-lived creds; per-service policies |
| Infrastructure as Code | Terraform 1.7+ + Terragrunt for env composition | Industry standard; per-cell modules |
| Service mesh | Skipped (envoy + cert-manager directly) | Mesh complexity not justified at 6 services |
| Cluster monitoring | Prometheus + Grafana + Loki + Tempo (LGTM stack) | Vendor-neutral; on-prem-able |
| App-level errors | Sentry (self-hosted) | Crash reports; PII-scrubbed at the SDK |
| Synthetic monitoring | Checkly | External probes from regions outside our cells |
| Status page | Statuspage.io (Atlassian) | Public-facing; the lowest-stakes vendor |
| Backup orchestration | pgBackRest (Postgres) + Velero (cluster state) | Battle-tested |
| App distribution | App Store Connect (iOS) + Google Play Console (Android) | Required by platform |

We do not use:

- A custom CI/CD pipeline.
- Self-hosted GitHub Actions runners (cost vs simplicity tradeoff favors hosted).
- Spinnaker (more complex than we need).
- A custom observability stack (LGTM is enough).
- Datadog (we self-host LGTM to avoid vendor concentration; Datadog can be re-evaluated post-1M MAU).

## Top-level shape

```
                          ┌──────────────────────────┐
                          │  Engineer (PR)           │
                          └───────────┬──────────────┘
                                      │
                          ┌───────────▼──────────────┐
                          │  GitHub                  │
                          │   • code               │
                          │   • CI (Actions)         │
                          │   • Container registry   │
                          └───────────┬──────────────┘
                                      │ (Argo CD pulls)
                                      │
              ┌───────────────────────┼─────────────────────────┐
              │                       │                          │
        ┌─────▼─────┐          ┌──────▼─────┐          ┌─────────▼────────┐
        │  staging  │          │ prod-east  │          │  prod-eu / apac  │
        │   (1 cell │          │  (us-east) │          │     (cells)      │
        └───────────┘          └────────────┘          └──────────────────┘
                                      │
                                      │ telemetry
                                      ▼
                          ┌──────────────────────────┐
                          │  LGTM stack              │
                          │   Loki + Tempo + Prom +  │
                          │   Grafana                │
                          └───────────┬──────────────┘
                                      │
                                      │ alerts
                                      ▼
                          ┌──────────────────────────┐
                          │  PagerDuty               │
                          │  + Slack                 │
                          └──────────────────────────┘
```

## Module layout

```
ops/
  helm/
    velix-edge/
    velix-identity/
    velix-routing/
    velix-media/
    velix-push/
    velix-call/
    velix-notifier/
    velix-ai-gateway/
    velix-shared/         ← service-account templates, network policies, etc.
  terraform/
    modules/
      cell/               ← reusable per-cell stack
      kubernetes/
      postgres/
      redis/
      nats/
      livekit/
      r2/
      vault/
    environments/
      staging/
      prod-us-east-1/
      prod-eu-west-1/
      prod-ap-southeast-1/
  argocd/
    apps/
      staging.yaml
      prod-us-east-1.yaml
      prod-eu-west-1.yaml
      prod-ap-southeast-1.yaml
    app-of-apps.yaml
  github-workflows/      ← CI/CD pipeline definitions
    ci.yml
    cd-staging.yml
    cd-production.yml
    perf-bench.yml
    security-scan.yml
  runbooks/
    incident-response.md
    postgres-failover.md
    region-failover.md
    backup-restore.md
    rollback.md
    submission-ios.md
    submission-android.md
  release/
    checklists/
    versioning.md
```

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | this | Pillars, stack, top-level shape |
| 01 | [Environments](./01-environments.md) | dev / staging / production separation |
| 02 | [Deployment Topology](./02-deployment-topology.md) | Cells, regions, what's in each |
| 03 | [Containers](./03-containers.md) | Dockerfile strategy, distroless, signing |
| 04 | [CI Pipeline](./04-ci-pipeline.md) | Lint, test, build, security checks |
| 05 | [CD Pipeline](./05-cd-pipeline.md) | Argo CD, staging-first, canary, phased rollout |
| 06 | [Secrets](./06-secrets.md) | Vault integration, rotation, audit |
| 07 | [Monitoring & Alerts](./07-monitoring-and-alerts.md) | RED metrics, SLOs, alert routing, runbooks |
| 08 | [Logging & Errors](./08-logging-and-errors.md) | Structured logs, Loki, Sentry, scrubbing |
| 09 | [Disaster Recovery](./09-disaster-recovery.md) | RTO/RPO, runbooks, drills |
| 10 | [Release Process](./10-release-process.md) | Versioning, notes, gates, freeze windows |
| 11 | [Rollback](./11-rollback.md) | Argo rollback, data-migration safety, feature flags |
| 12 | [Store Submission](./12-store-submission.md) | App Store + Play Store readiness checklists |
| 13 | [Security Readiness](./13-security-readiness.md) | Audit prep, public papers, transparency |
| 14 | [Phase 10 Audit](./14-phase-10-audit.md) | Self-review, gates Phase 11 |

## What this phase does NOT do

- Stand up the cells (we describe; the team executes per the runbooks).
- Run the first independent security audit (we prepare; the auditor runs).
- Submit to App Store / Play Store (we prepare; the publisher submits).
- Author all the alerting rules (we prescribe the categories; the team configures).

Phase 10 ships the **operational architecture** — what gets deployed, how it's deployed, how it's observed, how it recovers, what happens when it doesn't. The team executes against the runbooks. The runbooks are the contract.

## Read order

If you have ten minutes: 00 → 02 → 14.
If you're operating: 07 → 09 → 11 → 10.
If you're submitting: 12 → 13.
If you're auditing: 14 → 13 → 06 → 04.
