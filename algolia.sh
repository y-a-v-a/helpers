#!/usr/bin/env sh

# ---- configuration ----
START_DATE="2024-10-01"
END_DATE="2026-09-30"
TOTAL_TOKENS=186000000
# -----------------------

if [ -z "$1" ]; then
  echo "Usage: $0 <tokens_used>"
  echo "e.g. for 68.6 million tokens: $0 68600000"
  echo ""
  echo "Example output:"
  echo "Time elapsed:  60.50%"
  echo "Tokens spent:  36.88%"
  echo ""
  echo "Vincent Bruijn <vincent-bruijn@g-star.com> 2025"
  exit 1
fi

TOKENS_USED="$1"

# Convert dates to seconds since epoch
START_TS=$(date -jf "%Y-%m-%d" "$START_DATE" +%s 2>/dev/null || date -d "$START_DATE" +%s)
END_TS=$(date -jf "%Y-%m-%d" "$END_DATE" +%s 2>/dev/null || date -d "$END_DATE" +%s)
NOW_TS=$(date +%s)

# Clamp NOW_TS to period bounds
if [ "$NOW_TS" -lt "$START_TS" ]; then
  NOW_TS="$START_TS"
elif [ "$NOW_TS" -gt "$END_TS" ]; then
  NOW_TS="$END_TS"
fi

TOTAL_DURATION=$((END_TS - START_TS))
ELAPSED_DURATION=$((NOW_TS - START_TS))

TIME_PCT=$(awk "BEGIN { printf \"%.2f\", ($ELAPSED_DURATION / $TOTAL_DURATION) * 100 }")
TOKEN_PCT=$(awk "BEGIN { printf \"%.2f\", ($TOKENS_USED / $TOTAL_TOKENS) * 100 }")

echo "Time elapsed:  $TIME_PCT%"
echo "Tokens spent:  $TOKEN_PCT%"
