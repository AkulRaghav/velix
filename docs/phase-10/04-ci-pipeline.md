# 04 — CI Pipeline

GitHub Actions runs every PR through a fixed sequence of checks. Reproducible. Fast. Not bypassable.

## Pipeline shape

```
on PR:
  ┌─────────────────┐
  │  lint           │
  └────────┬────────┘
           │
  ┌────────▼────────┐
  │  typecheck      │
  └────────┬────────┘
           │
  ┌────────▼────────────────────┬────────────────────┬──────────────────────┐
  │  unit tests                 │  perf bench        │  security scan       │
  │  (Dart, Go, Rust)           │  (frame stability) │  (CVE, secrets, IaC) │
  └────────┬────────────────────┴────────────────────┴──────────────────────┘
           │
  ┌────────▼────────┐
  │  integration    │
  │  tests          │
  └────────┬────────┘
           │
  ┌────────▼────────┐
  │  proto check    │
  └────────┬────────┘
           │
  ┌────────▼─────────────────────┐
  │  build images (amd64+arm64)  │
  │  generate SBOM               │
  │  sign images (cosign)        │
  └────────┬─────────────────────┘
           │
  ┌────────▼────────┐
  │  result         │
  └─────────────────┘

If everything green: PR is mergeable.
Failed step: PR is blocked; human reviews the failure.
```

Total target: ≤ 12 minutes for a typical PR.

## Per-stage detail

### Stage 1 — Lint

Run in parallel on the same runner:

| Subsystem | Tool | Configured in |
|---|---|---|
| Dart | `dart analyze --fatal-infos --fatal-warnings` | per-package `analysis_options.yaml` |
| Dart | `dart format --set-exit-if-changed` | repo root |
| Go | `golangci-lint run --config .golangci.yml` | repo root |
| Go | `gofumpt -d` (stricter gofmt) | |
| Rust | `cargo fmt --check` | `cryptocore/` |
| Rust | `cargo clippy --all-targets -- -D warnings` | |
| Proto | `buf lint` | `backend/buf.yaml` |
| YAML | `yamllint` | `.yamllint.yml` |
| Helm | `helm lint` per chart | |
| Terraform | `terraform fmt -check` + `tflint` | per env |
| Markdown | `markdownlint` | |

Failure: fail loudly with a diff. Engineer fixes locally.

### Stage 2 — Typecheck

| Subsystem | Tool |
|---|---|
| Dart | already covered by `dart analyze` |
| Go | `go vet ./...` |
| Rust | `cargo check --all-targets` |

### Stage 3 — Unit tests

| Subsystem | Tool |
|---|---|
| Dart | `flutter test --coverage` (apps/velix_app + packages/velix_*) |
| Dart | `dart test --coverage` (pure-Dart packages: velix_domain) |
| Go | `go test -race -count=1 ./...` per service |
| Rust | `cargo test --release` (cryptocore) |
| Rust | `cargo bench --no-run` (verifies benches compile, doesn't run) |

Coverage thresholds:
- velix_domain: 90%
- velix_design / velix_motion / velix_3d: 60%
- apps/velix_app: 50%
- backend services: 70%
- cryptocore: 95%

PRs that drop coverage below threshold fail.

### Stage 4 — Integration tests

```
testcontainers-go spins up:
  postgres:16-alpine
  redis:7-alpine
  nats:2.10-alpine
  minio (R2-compatible)
  livekit:dev

Tests exercise:
  identity.CreateAccount → PublishPrekeys → FetchPrekeyBundle → SignIn
  routing.SendEnvelope (single + multi-recipient)
  routing.Subscribe (drains offline queue)
  media.IssueUploadUrl + R2 round-trip
  push.RequestPush (mock APNs)
  call.StartSession → JoinSession → LeaveSession
```

Integration tests run in parallel where possible. Total time target: ≤ 4 minutes.

### Stage 5 — Proto check

```
buf format --diff   # any unformatted .proto fails
buf lint            # standard lints
buf breaking --against '.git#branch=main'   # breaking changes vs main
```

A breaking change requires a major version bump (e.g., `v1` → `v2`); the bot suggests this in the PR comment.

### Stage 6 — Performance bench

Phase 9 doc 02 specifies the harness. CI runs:

| Bench | Where |
|---|---|
| Cold start | BrowserStack App Live device farm (Pixel 6) |
| Chat list scroll | Pixel 6 |
| Conversation push | Pixel 6 |
| Modal arrival | Pixel 6 |
| Cryptocore criterion | runner (no device) |
| k6 load test on routing | self-hosted ephemeral cluster |

iOS bench (iPhone 12) runs nightly, not per-PR. The Phase 9 budgets enforce.

### Stage 7 — Security scan

| Check | Tool |
|---|---|
| Container CVE | Trivy + Grype on built images |
| Dependency CVE | Dependabot + Renovate (always-on) |
| Secret leakage | gitleaks; fails on any pattern hit |
| IaC misconfig | tfsec + Checkov on terraform |
| Helm misconfig | kube-score on rendered Helm output |
| SAST | Semgrep with custom Velix rules + community packs |
| License compliance | go-licenses + dart pub deps; flag GPL |

Failure on any P0 CVE blocks merge. P1 CVE warns; team decides.

### Stage 8 — Build images

Per service:

```
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/velix/<service>:sha-${GITHUB_SHA::7} \
  --build-arg VERSION=${GITHUB_SHA} \
  --output type=registry \
  --provenance=true \
  --sbom=true \
  .
```

After build:

```
syft attest ghcr.io/velix/<service>:sha-... > sbom.json
cosign sign --yes ghcr.io/velix/<service>@sha256:<digest>
cosign attest --predicate sbom.json --type spdxjson ghcr.io/velix/<service>@sha256:<digest>
```

Sigstore keyless signing via GitHub OIDC. No long-lived signing keys.

## On main merge (post-PR)

The same pipeline runs again on the merged commit, producing the canonical artifacts. The bench results are stored as the new baseline (Phase 9 doc 02).

After main pipeline succeeds:

```
1. Tag image as ghcr.io/velix/<service>:${SEMVER}-${SHA}
2. Update Argo CD app manifest in ops/argocd/apps/staging.yaml.
3. Argo CD detects the change and deploys to staging.
4. Smoke tests run against staging.
5. If green, manual approval prompt for production canary.
```

## On release tag (semver)

```
git tag v1.0.3
```

Triggers:

```
1. Re-tag the existing sha-<sha> image as v1.0.3 (no rebuild).
2. Generate release notes from PR titles since last tag.
3. Update production Argo CD app manifests.
4. Phased canary rollout (5% → 25% → 100%).
5. Per-cell sequencing per Phase 10 doc 02.
6. Open the App Store / Play Store submission flow if mobile changes are part of this release.
```

## Reproducibility verification

A nightly job:

```
1. Pick a recent commit (the most recent main merge).
2. Re-build all images on a fresh runner.
3. Compare digests to the originally-built images.
4. Mismatch = file an issue; investigate.
```

We expect 100% reproducibility. A failure here is a real problem (probably a non-pinned dependency).

## CI infrastructure

| Component | Choice |
|---|---|
| Runner provider | GitHub-hosted (`ubuntu-latest`, `macos-latest` for iOS bench) |
| Self-hosted runners | none at 1.0; revisit at 1M MAU when CI minutes get expensive |
| Cache | GitHub Actions cache + remote cache for buildx |
| Artifacts | GitHub artifacts (90-day retention) + S3 for long-term |
| Bench device farm | BrowserStack App Live (per-PR) + Sauce Labs (failover) |

## Concurrency control

```
on PR:
  concurrency:
    group: ci-${{ github.ref }}
    cancel-in-progress: true
```

A PR that's force-pushed cancels the previous run. We don't waste runner time.

For main:

```
on push to main:
  concurrency:
    group: cd-staging
    cancel-in-progress: false  # never cancel a deploy
```

## Notifications

- PR failure: comment on PR + ping the author in Slack.
- Main failure: page the on-call (rare; main is supposed to be green).
- Security scan failure: immediate Slack to #security.
- Reproducibility failure: Slack to #infrastructure.

## What CI does NOT do

- Run any test that requires production credentials.
- Push to production.
- Skip stages "for speed."
- Allow `[skip ci]` markers for any PR.
- Run end-to-end tests against real third-party services (we mock).
- Deploy without an explicit approval.

## Banned

- `[ci skip]` markers in commit messages.
- Self-approval of PRs (GitHub branch protection prevents).
- Merging without all checks green (branch protection prevents).
- Skipping CI for "trivial" changes.
- Manual image builds outside CI (they don't get signed).
- Test code that calls real production endpoints.
- Tests that depend on flaky external services without retries + skip-on-flake.
