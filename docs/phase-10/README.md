# Phase 10 — DevOps & Production

Status: in progress. Gates Phase 11 (final audit).

## What ships

The complete operational architecture for running Velix in production: container strategy, CI/CD pipelines, secrets handling, monitoring, alerting, logging, error reporting, disaster recovery, release process, rollback, store submission, security readiness.

This phase ships the **architecture, runbooks, and reference configurations**. The team executes against them. The team's first sprint after Phase 10 wires Argo CD into staging; the second sprint deploys the first cell to production.

## Locked posture

- **Cell-based deployment.** Three regions at 1.0; independent failure domains.
- **Reproducible builds.** Two CI runs of the same SHA produce the same image digest.
- **Distroless images.** No shell. No package manager. Non-root.
- **Argo CD GitOps.** No manual `kubectl apply`. Cluster state reconciled from git.
- **Vault for all secrets.** Short-lived, audit-logged, per-service policies.
- **LGTM observability** (Loki + Grafana + Tempo + Mimir/Prometheus). Vendor-neutral.
- **Phased rollout.** Staging → prod canary 5% → prod 100% per cell, sequenced.
- **Rollback in one button.** Argo CD revert + image-tag re-pin.
- **DR drilled quarterly.** RTO/RPO targets verified via tabletop and live exercises.
- **No prior guarantee weakens.** Phases 1–9 architectural, cryptographic, AI, accessibility, motion, and performance commitments survive.

## Documents

| # | File | Purpose |
|---|---|---|
| 00 | [Overview](./00-overview.md) | Pillars, stack, module layout |
| 01 | [Environments](./01-environments.md) | dev / staging / production; isolation; promotion |
| 02 | [Deployment Topology](./02-deployment-topology.md) | Cells, regions, what's in each |
| 03 | [Containers](./03-containers.md) | Dockerfile strategy, distroless, signing, multi-arch |
| 04 | [CI Pipeline](./04-ci-pipeline.md) | Lint, test, build, security scan, signed images |
| 05 | [CD Pipeline](./05-cd-pipeline.md) | Argo CD GitOps, canary, phased rollout, gates |
| 06 | [Secrets](./06-secrets.md) | Vault, rotation, kubernetes auth, mTLS issuance |
| 07 | [Monitoring & Alerts](./07-monitoring-and-alerts.md) | SLOs, RED metrics, alert routing, runbook links |
| 08 | [Logging & Errors](./08-logging-and-errors.md) | Loki, Sentry, PII scrubbing |
| 09 | [Disaster Recovery](./09-disaster-recovery.md) | RTO/RPO matrix, drills, runbooks |
| 10 | [Release Process](./10-release-process.md) | Versioning, gates, freeze windows, release checklist |
| 11 | [Rollback](./11-rollback.md) | Argo revert, feature flags, data-migration safety |
| 12 | [Store Submission](./12-store-submission.md) | App Store + Play Store readiness checklists |
| 13 | [Security Readiness](./13-security-readiness.md) | First independent audit prep; public papers |
| 14 | [Phase 10 Audit](./14-phase-10-audit.md) | Self-review, gates Phase 11 |

## Reference module layout

```
ops/
  helm/                    ← per-service Helm charts
  terraform/               ← per-cell IaC modules
  argocd/                  ← Application definitions
  github-workflows/        ← CI/CD pipeline definitions
  runbooks/                ← incident response, failover, rollback, submission
  release/                 ← checklists, versioning
```

## Reading order

If you have ten minutes: 00 → 02 → 14.
If you're operating: 07 → 09 → 11 → 10.
If you're submitting: 12 → 13.
If you're auditing: 14 → 13 → 06 → 04.
