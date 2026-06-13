# Multi-stage, reproducible build for the routing service.
# Build context is the backend/ directory:
#   docker build -f services/routing/Dockerfile -t velix-routing .
# See docs/phase-10/03-build-supply-chain.md for the supply-chain posture.

FROM golang:1.22-alpine AS build
# CI pins this to a digest; the tag is used for local builds.

ARG SOURCE_DATE_EPOCH=0
ARG GIT_REVISION=unknown

WORKDIR /src

# Copy the shared modules + proto stubs the service's replace directives point
# at, then the service module itself. Building with GOWORK=off makes each
# module self-contained via its go.mod replace directives.
COPY proto/ proto/
COPY pkg/ pkg/
COPY services/routing/ services/routing/

WORKDIR /src/services/routing

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GOWORK=off \
    GOFLAGS="-trimpath"

RUN go build \
    -ldflags="-s -w -X main.gitRevision=${GIT_REVISION} -buildid=" \
    -o /out/routing-server \
    ./cmd/routing-server

# Distroless final stage. Static, non-root, minimal.
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/routing-server /usr/local/bin/routing-server

USER nonroot:nonroot

# gRPC on 8080, health/metrics on 8081.
EXPOSE 8080 8081

LABEL org.opencontainers.image.title="velix-routing" \
      org.opencontainers.image.description="Velix realtime routing service" \
      org.opencontainers.image.source="https://github.com/velix/velix" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="Velix"

ENTRYPOINT ["/usr/local/bin/routing-server"]
