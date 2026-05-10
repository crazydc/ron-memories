#!/bin/bash
# memory-get.sh — Retrieve a memory from Redis + local cache fallback

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"

KEY="$1"
if [ -z "$KEY" ]; then
    echo "Usage: memory-get.sh <key>"
    exit 1
fi

REDIS_KEY="ron:user:$KEY"

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
        exit 0
    fi
fi

# Fallback to local cache
if [ -f "$CACHE_FILE" ]; then
    grep "^| $KEY " "$CACHE_FILE" | awk -F'|' '{gsub(/^ *| *$/, "", $3); print $3}' | tail -1
fi