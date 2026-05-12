#!/bin/sh
set -e
cd /app
if [ ! -d node_modules/@angular/core ]; then
  echo "[ui-dev] Installing dependencies (first run or empty volume)…"
  npm ci
fi
exec "$@"
