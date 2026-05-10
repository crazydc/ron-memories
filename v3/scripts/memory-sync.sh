#!/bin/bash
# memory-sync.sh — Pull all memories from Redis, update local cache

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "🔄 Syncing from Redis..."

# Get all keys
KEYS_JSON=$(curl -s "$URL/keys/ron:*" -H "Authorization: Bearer $TOKEN")

# Parse keys - filter out test/system keys
KEYS=$(echo "$KEYS_JSON" | python3 -c "
import sys, json
keys = json.loads(sys.stdin.read()).get('result', [])
filtered = [k for k in keys if not k.startswith('ron:jeff') and not k.startswith('ron:test') and not k.startswith('ron:archive')]
for k in filtered:
    print(k)
")

# Write new cache
{
    echo "# Ron Memory Cache"
    echo "# Last synced: $NOW"
    echo ""
    echo "| Key | Value | Updated |"
    echo "|-----|-------|--------|"
    
    count=0
    while IFS= read -r key; do
        [ -z "$key" ] && continue
        
        # Get value - it's a nested JSON string
        VALUE_JSON=$(curl -s "$URL/get/$key" -H "Authorization: Bearer $TOKEN")
        
        # Parse: {"result": "{\"value\": \"...\", \"timestamp\": \"...\"}"}
        RESULT=$(echo "$VALUE_JSON" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
v = inner.get('value', '')
t = inner.get('timestamp', '$NOW')
print(f'{v}|{t}')
" 2>/dev/null || echo "")
        
        if [ -n "$RESULT" ]; then
            VALUE="${RESULT%|*}"
            TS="${RESULT##*|}"
            SHORT_KEY="${key#ron:user:}"
            SHORT_KEY="${SHORT_KEY#ron:}"
            echo "| $SHORT_KEY | $VALUE | $TS |"
            count=$((count + 1))
        fi
    done <<< "$KEYS"
    
    echo ""
    echo "# Synced $count entries"
} > "$CACHE_FILE.tmp"

mv "$CACHE_FILE.tmp" "$CACHE_FILE"
echo "✅ Synced $count entries to $CACHE_FILE"