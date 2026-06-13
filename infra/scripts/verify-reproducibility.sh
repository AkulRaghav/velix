#!/usr/bin/env bash
# Build a service image twice and compare digests.
# Used by .github/workflows/backend-ci.yml nightly job.
set -euo pipefail

SERVICE="${1:?usage: verify-reproducibility.sh <service>}"
DOCKERFILE="backend/services/${SERVICE}/Dockerfile"

if [[ ! -f "${DOCKERFILE}" ]]; then
  echo "Dockerfile not found: ${DOCKERFILE}" >&2
  exit 1
fi

EPOCH="${SOURCE_DATE_EPOCH:-0}"
REV="${GIT_REVISION:-$(git rev-parse HEAD)}"

build_once() {
  local tag="$1"
  docker buildx build \
    --build-arg SOURCE_DATE_EPOCH="${EPOCH}" \
    --build-arg GIT_REVISION="${REV}" \
    --tag "${tag}" \
    --output=type=docker \
    -f "${DOCKERFILE}" \
    backend/
}

build_once "velix-${SERVICE}:repro1"
docker save "velix-${SERVICE}:repro1" | sha256sum > /tmp/digest1

build_once "velix-${SERVICE}:repro2"
docker save "velix-${SERVICE}:repro2" | sha256sum > /tmp/digest2

if ! diff -q /tmp/digest1 /tmp/digest2; then
  echo "REPRODUCIBILITY FAILURE: ${SERVICE}" >&2
  cat /tmp/digest1 /tmp/digest2 >&2
  exit 1
fi

echo "OK: ${SERVICE} reproducible"
cat /tmp/digest1
