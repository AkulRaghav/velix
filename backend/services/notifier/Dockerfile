# Multi-stage, reproducible build for the notifier service.
# Build context is the backend/ directory:
#   docker build -f services/notifier/Dockerfile -t velix-notifier .

FROM golang:1.26-alpine AS build

ARG SOURCE_DATE_EPOCH=0
ARG GIT_REVISION=unknown

WORKDIR /src

COPY proto/ proto/
COPY pkg/ pkg/
COPY services/notifier/ services/notifier/

WORKDIR /src/services/notifier

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GOWORK=off \
    GOFLAGS="-trimpath"

RUN go build \
    -ldflags="-s -w -X main.gitRevision=${GIT_REVISION} -buildid=" \
    -o /out/notifier-server \
    ./cmd/notifier-server

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/notifier-server /usr/local/bin/notifier-server

USER nonroot:nonroot

EXPOSE 8080 8081

LABEL org.opencontainers.image.title="velix-notifier" \
      org.opencontainers.image.description="Velix notifier service" \
      org.opencontainers.image.source="https://github.com/velix/velix" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="Velix"

ENTRYPOINT ["/usr/local/bin/notifier-server"]
