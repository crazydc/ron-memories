#!/bin/bash
# memory-set.sh v3 — Save a memory, touch reinforce: keys for freshness

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"

usage() {
    cat << EOF
Usage: memory-set.sh <key> <value> [--force]
Save a memory to Redis + local cache.

Examples:
  memory-set.sh user:name Alex
  memory-set.sh story:holiday_2025:title "Summer road trip"
  memory-set.sh reminder:dentist:message "Call dentist" --force
EOF
}

FORCE=false
KEY=""
VALUE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=true; shift ;;
        *)
            if [ -z "$KEY" ]; then KEY="$1"; shift
            elif [ -z "$VALUE" ]; then VALUE="$1"; shift
            else shift; fi
            ;;
    esac
done

if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
    usage; exit 1
fi

# Check for staleness
if [ -f "$CACHE_FILE" ] && grep -q "^| $KEY " "$CACHE_FILE" 2>/dev/null; then
    OLD_VALUE=$(grep "^| $KEY " "$CACHE_FILE" | awk -F'|' '{gsub(/^ *| *$/, "", $3); print $3}')
    if [ -n "$OLD_VALUE" ] && [ "$OLD_VALUE" != "$VALUE" ] && [ "$FORCE" = false ]; then
        echo "⚠️  Staleness detected: '$KEY' already exists"
        echo "   Old: '$OLD_VALUE'"
        echo "   New: '$VALUE'"
        echo "   Use --force to overwrite"
        exit 1
    fi
fi

# Save to Redis with JSON format
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REDIS_KEY="ron:$KEY"
JSON_PAYLOAD="{\"value\": \"$VALUE\", \"timestamp\": \"$TIMESTAMP\"}"

curl -s -X POST "$URL/set/$REDIS_KEY" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$JSON_PAYLOAD" >/dev/null 2>&1

# Update local cache
mkdir -p "$(dirname "$CACHE_FILE")"
touch "$CACHE_FILE"
grep -v "^| $KEY " "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null || true
mv "$CACHE_FILE.tmp" "$CACHE_FILE"
echo "| $KEY | $VALUE | $TIMESTAMP |" >> "$CACHE_FILE"

# Touch reinforce:last:<key> to mark freshness on save
LAST_KEY="ron:reinforce:last:$KEY"
curl -s -X POST "$URL/set/$LAST_KEY" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"value\": \"$TIMESTAMP\", \"timestamp\": \"$TIMESTAMP\"}" >/dev/null 2>&1

echo "✅ Saved '$KEY' = '$VALUE'"
