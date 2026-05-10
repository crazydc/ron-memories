#!/bin/bash
# Ron Memory - Sync from Redis to local file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

SYNC_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get all keys using Upstash
KEYS_RESPONSE=$(curl -s -X GET "$REDIS_URL/keys/ron:*" \
    -H "Authorization: $REDIS_TOKEN")

# Use Python to parse the response and extract keys
KEYS=$(python3 -c "
import json
import sys
try:
    response = json.loads(sys.stdin.read())
    result = response.get('result', '')
    if isinstance(result, list):
        for k in result:
            if k.startswith('ron:user:'):
                print(k)
except:
    pass
" <<< "$KEYS_RESPONSE")

# Build new memory file
{
    echo "# Ron Memory Cache"
    echo "# Last synced: $SYNC_TIME"
    echo ""
    echo "| Key | Value | Updated |"
    echo "|-----|-------|---------|"
} > "$MEMORY_FILE"

for redis_key in $KEYS; do
    key="${redis_key#ron:user:}"
    
    # Get value using Python for JSON parsing
    VALUE_RESPONSE=$(curl -s -X GET "$REDIS_URL/get/$redis_key" \
        -H "Authorization: $REDIS_TOKEN")
    
    # Parse using Python
    PARSED=$(python3 -c "
import json
import sys
try:
    response = json.loads(sys.stdin.read())
    result = json.loads(response.get('result', '{}'))
    print(result.get('value', '') + '|' + result.get('timestamp', 'unknown'))
except:
    pass
" <<< "$VALUE_RESPONSE")
    
    value="${PARSED%|*}"
    timestamp="${PARSED##*|}"
    
    if [ -n "$value" ]; then
        echo "| $key | $value | $timestamp |" >> "$MEMORY_FILE"
    fi
done

echo "OK: Synced to $MEMORY_FILE"
echo "  - $(grep -c '|' "$MEMORY_FILE" || echo 0) entries"