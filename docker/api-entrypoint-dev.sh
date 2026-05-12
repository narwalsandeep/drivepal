#!/bin/sh
set -e
cd /app
if [ ! -d node_modules/@nestjs/core ] || [ ! -d node_modules/stripe ]; then
  echo "[api-dev] Installing dependencies (first run or dependency change)…"
  npm ci
fi
exec "$@"
