# Multi-stage, reproducible build for the media service.
# Build context is the backend/ directory:
#   docker build -f services/media/Dockerfile -t velix-media .

FROM golang:1.22-alpine AS build

ARG SOURCE_DATE_EPOCH=0
ARG GIT_REVISION=unknown

WORKDIR /src

COPY proto/ proto/
COPY pkg/ pkg/
COPY services/media/ services/media/

WORKDIR /src/services/media

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64 \
    GOWORK=off \
    GOFLAGS="-trimpath"

RUN go build \
    -ldflags="-s -w -X main.gitRevision=${GIT_REVISION} -buildid=" \
    -o /out/media-server \
    ./cmd/media-server

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/media-server /usr/local/bin/media-server

USER nonroot:nonroot

EXPOSE 8080 8081

LABEL org.opencontainers.image.title="velix-media" \
      org.opencontainers.image.description="Velix media service" \
      org.opencontainers.image.source="https://github.com/velix/velix" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="Velix"

ENTRYPOINT ["/usr/local/bin/media-server"]
