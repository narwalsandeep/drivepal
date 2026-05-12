#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <lcov-file> <min-line-percent> [label]"
  exit 2
fi

LCOV_FILE="$1"
MIN_PERCENT="$2"
LABEL="${3:-coverage}"

if [[ ! -f "$LCOV_FILE" ]]; then
  echo "ERROR: lcov file not found: $LCOV_FILE"
  exit 2
fi

LF_TOTAL="$(awk -F: '/^LF:/{sum+=$2} END{print sum+0}' "$LCOV_FILE")"
LH_TOTAL="$(awk -F: '/^LH:/{sum+=$2} END{print sum+0}' "$LCOV_FILE")"

if [[ "$LF_TOTAL" -le 0 ]]; then
  echo "ERROR: no measurable lines in $LCOV_FILE"
  exit 2
fi

PERCENT="$(awk -v lh="$LH_TOTAL" -v lf="$LF_TOTAL" 'BEGIN { printf "%.2f", (lh/lf)*100 }')"

echo "$LABEL line coverage: $PERCENT% (hit=$LH_TOTAL / found=$LF_TOTAL, minimum=$MIN_PERCENT%)"

awk -v p="$PERCENT" -v min="$MIN_PERCENT" 'BEGIN { exit !(p+0 >= min+0) }' || {
  echo "ERROR: $LABEL line coverage is below threshold."
  exit 1
}
