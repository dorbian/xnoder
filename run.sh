#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="${ENV_FILE:-/opt/openclaw-node/secrets/openclaw-node.env}"
IMAGE="${IMAGE:-localhost/openclaw-node-workstation:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-openclaw-node}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found: $ENV_FILE" >&2
  echo "Create it from etc/openclaw-node.env.example or mount it from your bootc provisioning." >&2
  exit 1
fi

podman run -d \
  --name "$CONTAINER_NAME" \
  --replace \
  --restart=always \
  --shm-size=2g \
  --security-opt seccomp=unconfined \
  --env-file "$ENV_FILE" \
  -p 127.0.0.1:18789:18789 \
  -p 127.0.0.1:9222:9222 \
  -p 127.0.0.1:5900:5900 \
  -p 127.0.0.1:6080:6080 \
  -v openclaw-workspace:/opt/openclaw-node/workspace:Z \
  -v openclaw-state:/opt/openclaw-node/state:Z \
  -v openclaw-browser:/opt/openclaw-node/browser-profile:Z \
  -v openclaw-logs:/opt/openclaw-node/logs:Z \
  "$IMAGE" node
