#!/usr/bin/env bash
set -Eeuo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-/opt/openclaw-node}"
OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-$OPENCLAW_HOME/state/openclaw}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$OPENCLAW_HOME/workspace}"
OPENCLAW_WEB_PORT="${OPENCLAW_WEB_PORT:-18789}"
CHROME_DEBUG_PORT="${CHROME_DEBUG_PORT:-9222}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

export OPENCLAW_HOME OPENCLAW_CONFIG_DIR OPENCLAW_WORKSPACE OPENCLAW_WEB_PORT CHROME_DEBUG_PORT VNC_PORT NOVNC_PORT
export HOME="${HOME:-/home/nodeagent}"
export DISPLAY="${DISPLAY:-:1}"
export BROWSER_CDP_URL="${BROWSER_CDP_URL:-http://127.0.0.1:${CHROME_DEBUG_PORT}}"
export CHROME_USER_DATA_DIR="${CHROME_USER_DATA_DIR:-$OPENCLAW_HOME/browser-profile}"

read_secret_file() {
  local var_name="$1"
  local file_var_name="${var_name}_FILE"
  local current_value="${!var_name:-}"
  local file_value="${!file_var_name:-}"

  if [[ -z "$current_value" && -n "$file_value" && -f "$file_value" ]]; then
    export "$var_name=$(tr -d '\r\n' < "$file_value")"
  fi
}

mkdir -p \
  "$OPENCLAW_CONFIG_DIR" \
  "$OPENCLAW_WORKSPACE" \
  "$OPENCLAW_HOME/browser-profile" \
  "$OPENCLAW_HOME/state/vnc" \
  "$OPENCLAW_HOME/logs" \
  "$HOME/.config" "$HOME/.cache" "$HOME/.local/share"

read_secret_file OPENCLAW_GATEWAY_URL
read_secret_file OPENCLAW_NODE_TOKEN
read_secret_file OPENCLAW_GATEWAY_TOKEN
read_secret_file VNC_PASSWORD

# Backward compatibility with the uploaded initial .env name.
if [[ -z "${OPENCLAW_NODE_TOKEN:-}" && -n "${NODE_TOKEN:-}" ]]; then
  export OPENCLAW_NODE_TOKEN="$NODE_TOKEN"
fi

# OpenClaw gateway token is optional for node mode, but useful if the same container runs gateway tooling.
if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" && -n "${OPENCLAW_NODE_TOKEN:-}" ]]; then
  export OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_NODE_TOKEN"
fi

if [[ -z "${OPENCLAW_NODE_NAME:-}" ]]; then
  if command -v hostname >/dev/null 2>&1; then
    export OPENCLAW_NODE_NAME="$(hostname)"
  elif [[ -r /proc/sys/kernel/hostname ]]; then
    export OPENCLAW_NODE_NAME="$(cat /proc/sys/kernel/hostname)"
  else
    export OPENCLAW_NODE_NAME="openclaw-node"
  fi
else
  export OPENCLAW_NODE_NAME
fi
export OPENCLAW_LOG_LEVEL="${OPENCLAW_LOG_LEVEL:-info}"

CONFIG_FILE="$OPENCLAW_CONFIG_DIR/openclaw-node.json"
export OPENCLAW_CONFIG="$CONFIG_FILE"

if [[ -f "$OPENCLAW_HOME/etc/openclaw-node.json.template" ]]; then
  envsubst < "$OPENCLAW_HOME/etc/openclaw-node.json.template" > "$CONFIG_FILE"
  chmod 0600 "$CONFIG_FILE"
fi

mode="${1:-node}"
shift || true

case "$mode" in
  node|all)
    exec /usr/bin/supervisord -c "$OPENCLAW_HOME/etc/supervisord.conf"
    ;;
  openclaw-only)
    exec "$OPENCLAW_HOME/bin/start-openclaw.sh" "$@"
    ;;
  browser-only|desktop-only)
    exec "$OPENCLAW_HOME/bin/start-browser.sh" "$@"
    ;;
  shell|bash)
    exec /bin/bash "$@"
    ;;
  sleep)
    exec sleep infinity
    ;;
  *)
    exec "$mode" "$@"
    ;;
esac
