# Multi-stage, reproducible build for the identity service.
# Build context is the backend/ directory:
#   docker build -f services/identity/Dockerfile -t velix-identity .
# See docs/phase-10/03-build-supply-chain.md for the supply-chain posture.

FROM golang:1.26-alpine AS build

ARG SOURCE_DATE_EPOCH=0
ARG GIT_REVISION=unknown

WORKDIR /src

COPY proto/ proto/
COPY pkg/ pkg/
COPY services/identity/ services/identity/

WORKDIR /src/services/identity

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GOWORK=off \
    GOFLAGS="-trimpath"

RUN go build \
    -ldflags="-s -w -X main.gitRevision=${GIT_REVISION} -buildid=" \
    -o /out/identity-server \
    ./cmd/identity-server

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/identity-server /usr/local/bin/identity-server

USER nonroot:nonroot

EXPOSE 8080 8081

LABEL org.opencontainers.image.title="velix-identity" \
      org.opencontainers.image.description="Velix identity service" \
      org.opencontainers.image.source="https://github.com/velix/velix" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="Velix"

ENTRYPOINT ["/usr/local/bin/identity-server"]
