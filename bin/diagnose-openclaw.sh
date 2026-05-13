#!/usr/bin/env bash
set -Eeuo pipefail
OPENCLAW_HOME="${OPENCLAW_HOME:-/opt/openclaw-node}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$OPENCLAW_HOME/workspace}"
cd "$OPENCLAW_WORKSPACE" 2>/dev/null || true
redact() { local v="${1:-}"; [[ -z "$v" ]] && echo '<empty>' && return; (( ${#v} <= 10 )) && echo "<redacted:${#v}>" && return; echo "${v:0:4}…${v: -4}"; }
echo '== binaries =='
for c in openclaw node npm chromium chromium-browser Xvfb x11vnc websockify hostname envsubst bash curl jq; do printf '%-18s ' "$c"; command -v "$c" || true; done
echo '== openclaw =='
openclaw --version 2>&1 || true
openclaw node run --help 2>&1 | sed -n '1,100p' || true
openclaw node start --help 2>&1 | sed -n '1,60p' || true
echo '== env =='
echo "OPENCLAW_MODE=${OPENCLAW_MODE:-node}"
echo "OPENCLAW_GATEWAY_URL=${OPENCLAW_GATEWAY_URL:-<empty>}"
echo "OPENCLAW_NODE_TOKEN=$(redact "${OPENCLAW_NODE_TOKEN:-${NODE_TOKEN:-}}")"
echo "OPENCLAW_NODE_NAME=${OPENCLAW_NODE_NAME:-<empty>}"
echo "BROWSER_CDP_URL=${BROWSER_CDP_URL:-<empty>}"
echo '== network =='
if [[ -n "${OPENCLAW_GATEWAY_URL:-}" ]]; then
  python3 - <<'PY' || true
import os, urllib.parse, socket
u=os.environ.get('OPENCLAW_GATEWAY_URL','')
p=urllib.parse.urlparse(u)
h=p.hostname; port=p.port or (443 if p.scheme in ('wss','https') else 80)
print(f'gateway parsed: host={h} port={port} scheme={p.scheme}')
if h:
    try:
        socket.create_connection((h,port),3).close(); print('tcp_connect=ok')
    except Exception as e: print(f'tcp_connect=failed: {e}')
PY
fi
echo '== recent logs =='
for f in "$OPENCLAW_HOME"/logs/openclaw-startup.log "$OPENCLAW_HOME"/logs/openclaw.err.log "$OPENCLAW_HOME"/logs/openclaw.log "$OPENCLAW_HOME"/logs/browser.err.log "$OPENCLAW_HOME"/logs/browser.log; do
  [[ -f "$f" ]] || continue
  echo "--- $f"
  tail -120 "$f" || true
done
