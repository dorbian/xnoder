#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE="${IMAGE:-localhost/openclaw-node-workstation:latest}"
FEDORA_VERSION="${FEDORA_VERSION:-latest}"
OPENCLAW_NPM_PACKAGE="${OPENCLAW_NPM_PACKAGE:-openclaw}"
RUNTIME="${RUNTIME:-podman}"

"$RUNTIME" build \
  --file Containerfile \
  --tag "$IMAGE" \
  --build-arg FEDORA_VERSION="$FEDORA_VERSION" \
  --build-arg OPENCLAW_NPM_PACKAGE="$OPENCLAW_NPM_PACKAGE" \
  .
