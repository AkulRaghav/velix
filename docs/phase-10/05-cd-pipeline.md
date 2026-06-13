# 05 — CD Pipeline

Argo CD reconciles cluster state from git. No `kubectl apply` ever. Phased rollout per cell. Manual approval for production.

## Why GitOps

The state of every cluster is described in git. To know what's running in `prod-us-east-1`, you read `ops/argocd/apps/prod-us-east-1.yaml`. To change it, you submit a PR. Argo CD applies the change after merge.

Benefits:
- Auditable. Every production change is a git commit.
- Reversible. Revert the commit; Argo CD rolls back.
- Reproducible. `kubectl get all -A` matches `git`.
- Observable. Argo CD's UI shows current state, sync status, drift.
- Multi-cluster. Same pattern for staging, prod-us-east-1, etc.

## App-of-Apps

```
ops/argocd/
  app-of-apps.yaml              ← The root application; Argo CD bootstraps from this
  apps/
    staging.yaml                ← One Application per environment
    prod-us-east-1.yaml
    prod-eu-west-1.yaml
    prod-ap-southeast-1.yaml
  charts/                       ← Helm charts referenced by Applications
```

Each `apps/<env>.yaml` is an Argo CD `Application` resource pointing at the corresponding Helm chart with environment-specific values.

```yaml
# ops/argocd/apps/staging.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: velix-staging
  namespace: argocd
spec:
  project: velix
  source:
    repoURL: https://github.com/velix/backend
    targetRevision: main             # always tracks main for staging
    path: ops/helm
    helm:
      valueFiles:
        - values-staging.yaml
  destination:
    server: https://staging-cluster.velix.app
    namespace: velix
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
```

Production `Application`s pin to a specific Git tag (e.g., `v1.0.3`), not `main`. A new release means updating the `targetRevision`.

## Staging deploy (auto)

```
PR merged to main
   │
   ▼
CI builds images, pushes to ghcr.io with tags sha-<sha>
   │
   ▼
CI updates ops/argocd/apps/staging.yaml's image tag to sha-<sha>
(via a small bot PR)
   │
   ▼
PR auto-approved + auto-merged (it's a one-line image tag bump)
   │
   ▼
Argo CD detects the change, syncs to staging cluster
   │
   ▼
Pods rolling-update: 1 → 2 → 3 replicas (gradual)
   │
   ▼
Synthetic probes verify health for 30 minutes
   │
   ▼
Slack: "Staging deploy v1.0.3-abc1234 healthy"
```

## Production deploy (manual approval)

```
Engineer creates a release tag (e.g., v1.0.3)
   │
   ▼
CI verifies the tag is on main + green
   │
   ▼
CI generates release notes from PR titles
   │
   ▼
A "Promote to Production" workflow appears in GitHub Actions:
  - Cell: prod-us-east-1
  - Action: deploy 5% canary
  - Approver required: on-call engineer
   │
   ▼
On-call approves
   │
   ▼
Bot PR updates ops/argocd/apps/prod-us-east-1.yaml's targetRevision to v1.0.3
   │
   ▼
Argo CD syncs to prod-us-east-1
   │
   ▼
ServiceMesh (Istio Lite via traffic-splitting on the edge envoy) directs
5% of traffic to the new version
   │
   ▼
Canary observed for 30 minutes:
  - Error rate baseline match
  - Latency p99 not regressed
  - No P0 alerts firing
   │
   ▼
"Promote canary to 25%" workflow appears
   │
   ▼
On-call approves; observation window 15 min
   │
   ▼
"Promote canary to 100%" workflow appears
   │
   ▼
On-call approves; full rollout in prod-us-east-1
   │
   ▼
"Promote to next cell" workflow (prod-eu-west-1)
   │
   ▼
... same sequence per cell
```

The full release sequence: 5%, 25%, 100% per cell × 3 cells = 9 promotion gates. Each gate has automated checks + a human approval.

Total elapsed time for a typical production release: 4-6 hours.

## Canary infrastructure

The edge envoy supports traffic splitting:

```yaml
# Route 5% of /v1/routing.SendEnvelope traffic to canary version
- match:
    prefix: /v1/
  route:
    weighted_clusters:
      clusters:
        - name: routing-stable
          weight: 95
        - name: routing-canary
          weight: 5
```

Both versions run side-by-side; envoy splits. Telemetry tags the canary version separately so we can see its specific metrics.

## Phased rollout per cell

| Cell | Sequence |
|---|---|
| Cell 1: prod-us-east-1 | first; smallest user count → recovery is fastest |
| Cell 2: prod-eu-west-1 | second; only after Cell 1 is at 100% for 30 minutes |
| Cell 3: prod-ap-southeast-1 | third |

A failure in Cell 1 stops the rollout. Cells 2 and 3 stay on the previous version.

## Database migrations

Special handling because they cross the cluster/data boundary.

```
Pattern: Expand → Migrate → Contract.

Expand release:
  - Adds new columns / tables / indexes (additive only).
  - Old code keeps working.
  - Roll out normally.

Migrate release (between expand and contract):
  - Backfill data into new columns.
  - Run as a Kubernetes Job, not as a service deploy.
  - Operates on read replicas where possible.
  - Idempotent; resumable.

Contract release:
  - Removes old columns / tables / fields.
  - Only after expand has been live ≥ 24 hours.
  - Roll out normally.
```

This pattern means a rollback during the expand phase is safe (old code still works); rollback during contract is impossible without data restoration. Contract is the most carefully reviewed.

## Rollback

```
On the cell where the rollback is needed:
  1. Page the on-call.
  2. Run: gh workflow run rollback.yml --ref main \
            -f cell=prod-us-east-1 \
            -f to_version=v1.0.2
  3. Workflow updates ops/argocd/apps/prod-us-east-1.yaml's targetRevision.
  4. Argo CD reconciles; previous version's pods come back.
  5. Synthetic probes verify health.
  6. Slack: "Rollback complete in prod-us-east-1; on v1.0.2"
```

Rollback time target: 5 minutes. The workflow is one click for the on-call.

If the rollback involves a database migration that's already run (contract phase): we cannot purely roll back code. The runbook (`ops/runbooks/rollback.md`) handles this case explicitly with a human decision tree.

## Feature flags

Risky changes ship behind feature flags. The flag system:

- Uses a simple Postgres-backed flag service exposed via gRPC.
- Flags are evaluated client-side and server-side.
- Flag evaluation is cached for 60 seconds.
- Flag changes are git commits → Argo-deployed → fetched.

This means a hotfix-shaped change that doesn't require a redeploy is achievable: toggle a flag, observe.

## Concurrency

| Operation | Concurrent | Locking |
|---|---|---|
| Staging deploys | yes (Argo CD handles) | none |
| Production canary in same cell | no | mutex via GitHub workflow |
| Cross-cell production canary | no | sequenced by workflow |
| Rollback | exclusive | locks all canary workflows for that cell |

GitHub Actions `concurrency` enforces.

## Telemetry around deploys

Every deploy emits markers in Grafana:

- A vertical annotation line at the deploy time on every dashboard.
- A `velix_deploy_total{cell, version}` counter for the deploy event.
- Pre/post comparison panels on the customer-impacting dashboard for the first 30 minutes post-deploy.

If alerts fire within 30 minutes of a deploy, the dashboard correlates and the runbook says "consider rollback."

## Approval matrix

| Action | Required approvers |
|---|---|
| Staging deploy | none (auto) |
| Production canary 5% | on-call engineer |
| Production canary 25% | on-call engineer |
| Production canary 100% | on-call engineer |
| Production rollback | on-call engineer |
| Database migration deploy (expand or contract) | on-call + senior backend engineer |
| Cross-cell promotion | on-call |
| Hotfix deploy outside business hours | on-call + manager |
| Vault policy change | on-call + security lead |

## What deploys we don't allow

- Cross-environment promotion via direct image tag (always through git).
- Production deploys from a non-tagged commit.
- Deploys after 4 PM local time on Friday.
- Deploys during scheduled freezes (App Store review periods, major holidays).
- Deploys with failing CI.
- Deploys without a release note.

## Argo CD security

- Argo CD itself runs in a separate namespace; tightly RBAC'd.
- Argo CD service account can only read its own namespace + write to declared destination namespaces.
- Argo CD UI access requires SSO (Velix internal IdP).
- Argo CD's ApplicationSet is controlled via git-only; no UI-driven application creation.

## Banned

- `kubectl apply` against any cluster.
- `helm install` against any cluster.
- Direct `docker push` to ghcr from a developer machine.
- Production deploys without an approval.
- Argo CD UI-driven application creation.
- Skipping the canary stage for "small" releases.
- Promoting from canary to 100% under 15 minutes of observation.
