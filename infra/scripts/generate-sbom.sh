#!/usr/bin/env bash
# Generate SBOMs for all Velix images using syft.
# Phase 10 doc 03 specifies SPDX format; we additionally produce CycloneDX.
set -euo pipefail

SERVICES=(routing identity media push call notifier)
OUTDIR="${1:-./sbom}"
mkdir -p "${OUTDIR}"

for svc in "${SERVICES[@]}"; do
  echo "Generating SBOM for ${svc}..."
  syft "ghcr.io/velix/${svc}:${TAG:-latest}" \
    -o spdx-json="${OUTDIR}/${svc}.spdx.json" \
    -o cyclonedx-json="${OUTDIR}/${svc}.cdx.json"
done

# cryptocore SBOM from cargo.
( cd cryptocore && cargo sbom --format=spdx-json > "../${OUTDIR}/cryptocore.spdx.json" ) || true

echo "SBOMs in ${OUTDIR}/"
