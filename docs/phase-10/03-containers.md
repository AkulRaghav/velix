# 03 — Container Strategy

## Image posture

- **Distroless or minimal base.** No shell. No package manager. No interactive utilities.
- **Multi-stage builds.** Build artifacts in one stage; ship only the binary in the final stage.
- **Reproducible.** Pinned base, pinned dependencies, pinned go toolchain. Two CI builds produce the same digest.
- **Scratch + glibc** for Go services that need DNS resolution (we use `gcr.io/distroless/static-debian12`).
- **One service per image.** No "swiss army knife" containers.
- **Non-root user.** UID 65532 (distroless default).
- **Read-only root filesystem.** Per pod-spec; only `/tmp` writeable.
- **No `latest` tags ever.** Images tagged by git SHA + semver.

## Reference Dockerfile (Go service)

```dockerfile
# syntax=docker/dockerfile:1.7

# ---- build stage ---------------------------------------------------------
FROM golang:1.22.4-alpine AS build

# Pinned for reproducibility.
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GOFLAGS="-trimpath -mod=readonly"

WORKDIR /src

# Cache deps; bust on go.mod / go.sum changes.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

# -ldflags -s -w strips debug + symbol info.
# -buildvcs=true embeds git SHA.
# -X embeds the version string.
ARG VERSION=dev
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build \
        -trimpath \
        -ldflags "-s -w -X main.version=${VERSION}" \
        -buildvcs=true \
        -o /out/service \
        ./cmd/service

# ---- runtime stage -------------------------------------------------------
FROM gcr.io/distroless/static-debian12:nonroot

# Metadata for ops.
LABEL org.opencontainers.image.source="https://github.com/velix/backend"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Run as non-root.
USER nonroot:nonroot

WORKDIR /app

COPY --from=build /out/service /app/service

# We pass the gRPC port via env; default to 9090.
EXPOSE 9090
EXPOSE 9100  # /metrics

ENTRYPOINT ["/app/service"]
```

Resulting image: ~12 MB compressed for a Go service. Contains the binary + ca-certs + tzdata + nothing else.

## Per-service Dockerfiles

Six services, each with the same Dockerfile shape. Differences:
- `cmd/<service>` build target.
- Some services need `gcr.io/distroless/cc-debian12:nonroot` (cgo-linked deps; rare).
- Notifier might be smaller; routing might be slightly larger due to NATS client.

## Security posture

| Property | Value |
|---|---|
| Base image | distroless static / cc |
| Root user | banned |
| Shell | absent |
| Package manager | absent |
| SUID/SGID binaries | absent |
| ca-certs | from distroless (auto-updated via base bumps) |
| tzdata | from distroless |
| Vulnerability scan | Grype + Trivy in CI |
| Image signing | cosign with Sigstore |
| SBOM | generated per-image, attached to release |
| Capabilities | dropped to none in pod-spec (no `CAP_NET_RAW`, etc.) |
| Filesystem | read-only (pod-spec) |
| seccomp | RuntimeDefault profile |
| AppArmor | runtime/default profile (Linux nodes) |

## Image registry

- Production: GHCR (GitHub Container Registry) under `ghcr.io/velix/<service>`.
- Tags: `<semver>` (e.g., `1.0.3`), `<semver>-<sha>` (e.g., `1.0.3-abc1234`), `sha-<sha>` (e.g., `sha-abc1234`).
- No `latest` tag ever pushed.
- Old tags retained for 90 days; older purged.
- Image signatures verified by Kubernetes via Kyverno admission policy.

## Image build pipeline

```
On main merge:
  1. CI builds the image with `docker buildx` for amd64 + arm64.
  2. Tags with both `<semver>-<sha>` and `sha-<sha>`.
  3. Generates SBOM via syft.
  4. Scans via Trivy + Grype; fails on CRITICAL/HIGH CVEs.
  5. Signs with cosign + Sigstore (keyless via GitHub OIDC).
  6. Pushes to GHCR.
  7. Triggers staging deploy.

On release tag (semver):
  1. Re-tag the existing `sha-<sha>` image as `<semver>` (no rebuild).
  2. Generate release notes.
  3. Trigger production deploy approval workflow.
```

## Multi-arch support

We build amd64 and arm64. Reasons:

- Production: AWS Graviton (arm64) is cheaper for our workload.
- Development: Apple Silicon Macs (arm64).

`docker buildx` handles both from a single Dockerfile. CI uses QEMU for cross-builds on amd64 runners.

## Reproducible builds

Two CI builds of the same git SHA produce the same image digest. Verified by:

- Pinned base image with full digest (e.g., `gcr.io/distroless/static-debian12@sha256:...`).
- Pinned Go toolchain via `golang:1.22.4-alpine` (we periodically bump and re-baseline).
- `-trimpath` strips local file paths from the binary.
- `SOURCE_DATE_EPOCH` = git commit timestamp; layers reflect.
- `--reproducible` flag on buildx.

CI verifies: build the image twice from `main`; compare digests; fail if different.

## Per-service image sizes

| Service | Image size (compressed) | Resident memory @ idle |
|---|---|---|
| edge (envoy) | 28 MB | 80 MB |
| identity | 14 MB | 40 MB |
| routing | 16 MB | 60 MB (more due to active sockets) |
| media | 12 MB | 30 MB |
| push | 12 MB | 30 MB |
| call | 14 MB | 40 MB |
| notifier | 10 MB | 25 MB |
| ai_gateway | 18 MB | 50 MB |

## Pod resource posture

```yaml
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 1000m       # 4x burst headroom for bursty workloads
    memory: 512Mi    # hard ceiling

# Different per service:
# - routing: 500m / 2000m / 1Gi (memory dominated by sockets)
# - media: 100m / 500m / 256Mi (mostly metadata)
# - call: 200m / 1000m / 512Mi
```

HPA on each Deployment with `cpu: averageUtilization: 60`. Scales 3 → 30 replicas.

## Pod security standards

Every pod-spec satisfies the Kubernetes "restricted" Pod Security Standard:

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    fsGroup: 65532
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: service
    image: ghcr.io/velix/<service>:<tag>@sha256:<digest>
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
    resources:
      requests: { cpu: 250m, memory: 256Mi }
      limits: { cpu: 1000m, memory: 512Mi }
    ports:
    - containerPort: 9090
      name: grpc
    - containerPort: 9100
      name: metrics
    livenessProbe:
      httpGet: { path: /healthz, port: metrics }
      initialDelaySeconds: 10
      periodSeconds: 10
    readinessProbe:
      httpGet: { path: /readyz, port: metrics }
      initialDelaySeconds: 5
      periodSeconds: 5
    volumeMounts:
    - { name: tmp, mountPath: /tmp }
  volumes:
  - { name: tmp, emptyDir: {} }
```

## Banned

- `:latest` tags.
- Building images outside CI (no engineer-built production images).
- Running as root.
- Adding shells / package managers to runtime images.
- Pulling images from registries other than `ghcr.io/velix/*`.
- Disabling vulnerability scans for "speed."
- Pinning the base image without a digest.
- Embedding secrets in images.
- Embedding licenses for third-party services in images (those go in Vault).
