#!/bin/bash
# memory-get.sh v2 — Retrieve a memory with optional full retrieval
# Checks cache first, falls back to Redis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-get.sh <key> [--full | --archive]
Get a memory from local cache (fast) or Redis.

Options:
  --full     Retrieve even if value is a summary (skip compression)
  --archive  Retrieve from archive: prefix instead

Examples:
  memory-get.sh user_name
  memory-get.sh vehicle:tesla:reg
  memory-get.sh archive:vehicle:tesla:reg --full
EOF
}

FULL=false
ARCHIVE_PREFIX=""
KEY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --full) FULL=true; shift ;;
        --archive) ARCHIVE_PREFIX="archive:"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) KEY="$1"; shift ;;
    esac
done

if [ -z "$KEY" ]; then
    usage
    exit 1
fi

LOOKUP_KEY="${ARCHIVE_PREFIX}${KEY}"

# Try local cache first
VALUE=""
if [ -f "$RON_CACHE_FILE" ]; then
    VALUE=$(grep "^| $LOOKUP_KEY " "$RON_CACHE_FILE" | awk -F'|' '{gsub(/^ *| *$/, "", $3); print $3}')
fi

# Fallback to Redis if not in cache
if [ -z "$VALUE" ]; then
    VALUE=$(curl -s -X POST "$UPSTASH_REDIS_URL/get" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" \
        -d "{\"key\": \"$LOOKUP_KEY\"}" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$VALUE" ]; then
    echo "Key not found: $LOOKUP_KEY"
    exit 1
fi

# Check if it's a summary (compressed) and --full not set
if [ "$FULL" = false ] && echo "$VALUE" | grep -q '\.\.\. \[archived'; then
    echo "📋 [Summary] $VALUE"
else
    echo "$VALUE"
fi
