#!/usr/bin/env bash
set -Eeuo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-/opt/openclaw-node}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$OPENCLAW_HOME/workspace}"
OPENCLAW_GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-}"
OPENCLAW_NODE_TOKEN="${OPENCLAW_NODE_TOKEN:-}"
OPENCLAW_NODE_HOST="${OPENCLAW_NODE_HOST:-}"
OPENCLAW_MODE="${OPENCLAW_MODE:-node}"
OPENCLAW_COMMAND_OVERRIDE="${OPENCLAW_COMMAND_OVERRIDE:-}"
if [[ -z "${OPENCLAW_NODE_NAME:-}" ]]; then
  if command -v hostname >/dev/null 2>&1; then
    OPENCLAW_NODE_NAME="$(hostname)"
  elif [[ -r /proc/sys/kernel/hostname ]]; then
    OPENCLAW_NODE_NAME="$(cat /proc/sys/kernel/hostname)"
  else
    OPENCLAW_NODE_NAME="openclaw-node"
  fi
fi
OPENCLAW_LOG_LEVEL="${OPENCLAW_LOG_LEVEL:-debug}"
OPENCLAW_WEB_PORT="${OPENCLAW_WEB_PORT:-18789}"
OPENCLAW_NODE_RUN_EXTRA_ARGS="${OPENCLAW_NODE_RUN_EXTRA_ARGS:-}"

if [[ -z "$OPENCLAW_NODE_HOST" ]]; then
  if command -v hostname >/dev/null 2>&1; then
    # Prefer the first container IP as a useful default, but override this with
    # OPENCLAW_NODE_HOST when the gateway must reach the host's LAN address.
    OPENCLAW_NODE_HOST="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  OPENCLAW_NODE_HOST="${OPENCLAW_NODE_HOST:-0.0.0.0}"
fi

mkdir -p "$OPENCLAW_WORKSPACE" "$OPENCLAW_HOME/logs"
cd "$OPENCLAW_WORKSPACE"

redact() {
  local v="${1:-}"
  if [[ -z "$v" ]]; then echo "<empty>"; return; fi
  if (( ${#v} <= 10 )); then echo "<redacted:${#v}>"; return; fi
  echo "${v:0:4}…${v: -4}"
}

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[openclaw] ERROR: openclaw CLI not found in PATH." >&2
  echo "[openclaw] PATH=$PATH" >&2
  exit 127
fi

{
  echo "[openclaw] ===== startup diagnostic ====="
  echo "[openclaw] date: $(date -Is 2>/dev/null || date)"
  echo "[openclaw] mode: $OPENCLAW_MODE"
  echo "[openclaw] cli: $(command -v openclaw)"
  openclaw --version 2>&1 | sed 's/^/[openclaw] version: /' || true
  echo "[openclaw] gateway_url: ${OPENCLAW_GATEWAY_URL:-<empty>}"
  echo "[openclaw] gateway_token: $(redact "${OPENCLAW_GATEWAY_TOKEN:-}")"
  echo "[openclaw] node_token: $(redact "$OPENCLAW_NODE_TOKEN")"
  echo "[openclaw] node_name: $OPENCLAW_NODE_NAME"
  echo "[openclaw] node_host: $OPENCLAW_NODE_HOST"
  echo "[openclaw] node_port: $OPENCLAW_WEB_PORT"
  echo "[openclaw] workspace: $OPENCLAW_WORKSPACE"
  echo "[openclaw] browser_cdp: ${BROWSER_CDP_URL:-<empty>}"
  echo "[openclaw] config: ${OPENCLAW_CONFIG:-<empty>}"
  echo "[openclaw] ================================="
} | tee -a "$OPENCLAW_HOME/logs/openclaw-startup.log"

if [[ -n "$OPENCLAW_COMMAND_OVERRIDE" ]]; then
  echo "[openclaw] Using OPENCLAW_COMMAND_OVERRIDE."
  exec bash -lc "$OPENCLAW_COMMAND_OVERRIDE"
fi

case "$OPENCLAW_MODE" in
  node)
    # OpenClaw's foreground node process is `openclaw node run`.
    # `openclaw node start` only accepts --node-id, so do not pass
    # --gateway/--token here. Gateway credentials are provided through the
    # rendered config file at $OPENCLAW_CONFIG.
    if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
      echo "[openclaw] WARNING: OPENCLAW_GATEWAY_TOKEN is empty. If your gateway requires auth, set it in the secret env file." >&2
    fi
    case "${OPENCLAW_GATEWAY_TOKEN:-}" in
      REPLACE_ME*|REPLACE_WITH*|your-*|changeme|CHANGE_ME)
        echo "[openclaw] ERROR: OPENCLAW_GATEWAY_TOKEN still looks like a placeholder." >&2
        exit 1
        ;;
    esac
    cmd=(openclaw node run
      --host "$OPENCLAW_NODE_HOST"
      --port "$OPENCLAW_WEB_PORT"
      --display-name "$OPENCLAW_NODE_NAME"
    )
    if [[ -n "$OPENCLAW_NODE_RUN_EXTRA_ARGS" ]]; then
      # shellcheck disable=SC2206
      extra_args=( $OPENCLAW_NODE_RUN_EXTRA_ARGS )
      cmd+=("${extra_args[@]}")
    fi
    ;;
  gateway)
    if [[ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
      openclaw config set gateway.auth.mode token || true
      openclaw config set gateway.auth.token "$OPENCLAW_GATEWAY_TOKEN" || true
    fi
    openclaw config set gateway.mode remote || true
    openclaw config set gateway.bind 0.0.0.0 || true
    openclaw config set gateway.port "$OPENCLAW_WEB_PORT" || true
    cmd=(openclaw gateway start --host 0.0.0.0 --port "$OPENCLAW_WEB_PORT")
    ;;
  local-gateway)
    openclaw config set gateway.mode local || true
    openclaw config set gateway.bind loopback || true
    openclaw config set gateway.port "$OPENCLAW_WEB_PORT" || true
    cmd=(openclaw gateway start --host 127.0.0.1 --port "$OPENCLAW_WEB_PORT")
    ;;
  *)
    echo "[openclaw] ERROR: unknown OPENCLAW_MODE=$OPENCLAW_MODE. Use node, gateway, local-gateway, or OPENCLAW_COMMAND_OVERRIDE." >&2
    exit 1
    ;;
esac

echo "[openclaw] Running: ${cmd[*]}"
exec "${cmd[@]}"
