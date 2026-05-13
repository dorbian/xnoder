#!/usr/bin/env bash
set -Eeuo pipefail

CHROME_DEBUG_PORT="${CHROME_DEBUG_PORT:-9222}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
ENABLE_NOVNC="${ENABLE_NOVNC:-1}"

curl -fsS "http://127.0.0.1:${CHROME_DEBUG_PORT}/json/version" >/dev/null
if [[ "$ENABLE_NOVNC" == "1" ]]; then
  curl -fsS "http://127.0.0.1:${NOVNC_PORT}/" >/dev/null
fi
