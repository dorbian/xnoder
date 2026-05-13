#!/usr/bin/env bash
set -Eeuo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-/opt/openclaw-node}"
DISPLAY="${DISPLAY:-:1}"
CHROME_DEBUG_PORT="${CHROME_DEBUG_PORT:-9222}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
ENABLE_VNC="${ENABLE_VNC:-1}"
ENABLE_NOVNC="${ENABLE_NOVNC:-1}"
HEADLESS="${HEADLESS:-0}"
VNC_PASSWORD="${VNC_PASSWORD:-}"
CHROME_USER_DATA_DIR="${CHROME_USER_DATA_DIR:-$OPENCLAW_HOME/browser-profile}"

export DISPLAY
mkdir -p "$CHROME_USER_DATA_DIR" "$OPENCLAW_HOME/state/vnc" "$OPENCLAW_HOME/logs" /tmp/.X11-unix
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 || true

cleanup() {
  trap - EXIT INT TERM
  for pid in "${WEBSOCKIFY_PID:-}" "${X11VNC_PID:-}" "${CHROME_PID:-}" "${OPENBOX_PID:-}" "${XVFB_PID:-}"; do
    [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

Xvfb "$DISPLAY" -screen 0 1920x1080x24 -ac +extension GLX +extension RANDR +extension RENDER -noreset > "$OPENCLAW_HOME/logs/xvfb.log" 2>&1 &
XVFB_PID=$!
sleep 1

openbox > "$OPENCLAW_HOME/logs/openbox.log" 2>&1 &
OPENBOX_PID=$!
sleep 1

CHROME_FLAGS=(
  --no-sandbox
  --disable-dev-shm-usage
  --user-data-dir="$CHROME_USER_DATA_DIR"
  --remote-debugging-address=0.0.0.0
  --remote-debugging-port="$CHROME_DEBUG_PORT"
  --window-size=1920,1080
  --no-first-run
  --no-default-browser-check
  --password-store=basic
)

if [[ "$HEADLESS" == "1" ]]; then
  CHROME_FLAGS+=(--headless=new)
fi

chromium "${CHROME_FLAGS[@]}" about:blank > "$OPENCLAW_HOME/logs/chromium.log" 2>&1 &
CHROME_PID=$!

if [[ "$ENABLE_VNC" == "1" && "$HEADLESS" != "1" ]]; then
  if [[ -z "$VNC_PASSWORD" ]]; then
    VNC_PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 || true)"
  fi

  x11vnc -storepasswd "$VNC_PASSWORD" "$OPENCLAW_HOME/state/vnc/passwd" >/dev/null 2>&1
  chmod 600 "$OPENCLAW_HOME/state/vnc/passwd"

  x11vnc -display "$DISPLAY" -rfbport "$VNC_PORT" -shared -forever -rfbauth "$OPENCLAW_HOME/state/vnc/passwd" > "$OPENCLAW_HOME/logs/x11vnc.log" 2>&1 &
  X11VNC_PID=$!

  if [[ "$ENABLE_NOVNC" == "1" ]]; then
    websockify --web=/usr/share/novnc "$NOVNC_PORT" "127.0.0.1:$VNC_PORT" > "$OPENCLAW_HOME/logs/novnc.log" 2>&1 &
    WEBSOCKIFY_PID=$!
  fi

  echo "[browser] noVNC: http://127.0.0.1:${NOVNC_PORT}/vnc.html"
  echo "[browser] VNC password: ${VNC_PASSWORD}"
fi

echo "[browser] Chromium CDP: http://127.0.0.1:${CHROME_DEBUG_PORT}/json/version"
wait -n
