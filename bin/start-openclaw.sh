#!/usr/bin/env bash
set -Eeuo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-/opt/openclaw-node}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$OPENCLAW_HOME/workspace}"
OPENCLAW_GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-}"
OPENCLAW_NODE_TOKEN="${OPENCLAW_NODE_TOKEN:-}"
if [[ -z "${OPENCLAW_NODE_NAME:-}" ]]; then
  if command -v hostname >/dev/null 2>&1; then
    OPENCLAW_NODE_NAME="$(hostname)"
  elif [[ -r /proc/sys/kernel/hostname ]]; then
    OPENCLAW_NODE_NAME="$(cat /proc/sys/kernel/hostname)"
  else
    OPENCLAW_NODE_NAME="openclaw-node"
  fi
fi
OPENCLAW_LOG_LEVEL="${OPENCLAW_LOG_LEVEL:-info}"

mkdir -p "$OPENCLAW_WORKSPACE" "$OPENCLAW_HOME/logs"
cd "$OPENCLAW_WORKSPACE"

if [[ -z "$OPENCLAW_GATEWAY_URL" ]]; then
  echo "[openclaw] ERROR: OPENCLAW_GATEWAY_URL is required." >&2
  exit 1
fi

if [[ -z "$OPENCLAW_NODE_TOKEN" ]]; then
  echo "[openclaw] ERROR: OPENCLAW_NODE_TOKEN is required." >&2
  exit 1
fi

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[openclaw] ERROR: openclaw CLI not found in PATH." >&2
  exit 1
fi

cmd=(openclaw node start
  --gateway "$OPENCLAW_GATEWAY_URL"
  --token "$OPENCLAW_NODE_TOKEN"
  --name "$OPENCLAW_NODE_NAME"
  --workspace "$OPENCLAW_WORKSPACE"
  --log-level "$OPENCLAW_LOG_LEVEL"
)

echo "[openclaw] Starting node: $OPENCLAW_NODE_NAME"
echo "[openclaw] Gateway: $OPENCLAW_GATEWAY_URL"
echo "[openclaw] Workspace: $OPENCLAW_WORKSPACE"
exec "${cmd[@]}"
