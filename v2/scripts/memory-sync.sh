#!/bin/bash
# memory-sync.sh v2 — Pull all namespaces from Redis, update local cache

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "=== Sync started at $NOW ===" >&2
echo "Cache file: $RON_CACHE_FILE" >&2

# Get all keys from Upstash
KEYS_RESPONSE=$(curl -s "$UPSTASH_REDIS_URL/keys/ron:*" \
    -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN")

# Extract keys - tr removes all quotes
KEYS=$(echo "$KEYS_RESPONSE" | grep -o 'ron:[^"]*' | tr -d '"')
KEY_COUNT=$(echo "$KEYS" | wc -w)
echo "Found $KEY_COUNT keys in Redis" >&2

# Write to temp file first
OUTFILE=$(mktemp)
{
    echo "# Ron Memory Cache"
    echo "# Last synced: $NOW"
    echo ""
    echo "| Key | Value | Updated |"
    echo "|-----|-------|---------|"
    
    line_num=0
    for redis_key in $KEYS; do
        line_num=$((line_num + 1))
        key="${redis_key#ron:user:}"
        
        if [[ "$key" =~ ^archive: ]]; then
            continue
        fi
        
        # Get value and timestamp from Redis
        GET_RESPONSE=$(curl -s "$UPSTASH_REDIS_URL/get/$redis_key" \
            -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN")
        
        value=$(echo "$GET_RESPONSE" | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
        timestamp=$(echo "$GET_RESPONSE" | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$value" ]; then
            echo "| $key | $value | $timestamp |"
        fi
    done
} > "$OUTFILE"

entry_count=$(grep -c "^| " "$OUTFILE" 2>/dev/null || echo 0)
echo "Wrote $entry_count entries to temp file" >&2

mv "$OUTFILE" "$RON_CACHE_FILE"
echo "OK: Synced to $RON_CACHE_FILE" >&2
echo "  - $entry_count entries" >&2
