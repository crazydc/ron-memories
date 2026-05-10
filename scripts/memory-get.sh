#!/bin/bash
# memory-get.sh v3 — Retrieve a memory, track access for reinforcement

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"

KEY="$1"

if [ -z "$KEY" ]; then
    echo "Usage: memory-get.sh <key>"
    exit 1
fi

REDIS_KEY="ron:$KEY"

# Try Redis first
RESPONSE=$(curl -s "$URL/get/$REDIS_KEY" -H "Authorization: Bearer $TOKEN" 2>/dev/null)

if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
    # Parse JSON: {"result": "{\"value\": \"...\", \"timestamp\": \"...\"}"}
    VALUE=$(echo "$RESPONSE" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
print(inner.get('value', ''))
" 2>/dev/null)
    
    if [ -n "$VALUE" ]; then
        echo "$VALUE"
        
        # Track access for reinforcement (increment counter)
        REINFORCE_KEY="ron:reinforce:count:$KEY"
        NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        # Get current count
        CURRENT=$(curl -s "$URL/get/$REINFORCE_KEY" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
print(inner.get('value', '0'))
" 2>/dev/null || echo "0")
        
        NEW_COUNT=$((CURRENT + 1))
        
        # Update reinforce count
        curl -s -X POST "$URL/set/$REINFORCE_KEY" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{\"value\": \"$NEW_COUNT\", \"timestamp\": \"$NOW\"}" >/dev/null 2>&1
        
        # Update last access time
        LAST_KEY="ron:reinforce:last:$KEY"
        curl -s -X POST "$URL/set/$LAST_KEY" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "{\"value\": \"$NOW\", \"timestamp\": \"$NOW\"}" >/dev/null 2>&1
        
        exit 0
    fi
fi

# Fallback to local cache
if [ -f "$CACHE_FILE" ]; then
    CACHED=$(grep "^| $KEY " "$CACHE_FILE" | awk -F'|' '{gsub(/^ *| *$/, "", $3); print $3}' | tail -1)
    if [ -n "$CACHED" ]; then
        echo "$CACHED"
        exit 0
    fi
fi

echo "Key not found: $KEY"
exit 1
