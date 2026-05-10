#!/bin/bash
# memory-sync.sh — Pull all memories from Redis, update local cache

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"
MIGRATION_FLAG_KEY="ron:migration:v2to:v3:done"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check for v2 keys and warn if migration not done
check_v2_migration_needed() {
    # Get all keys
    KEYS_JSON=$(curl -s "$URL/keys/ron:*" -H "Authorization: Bearer $TOKEN")
    
    # Check if migration flag exists
    FLAG_JSON=$(curl -s "$URL/get/$MIGRATION_FLAG_KEY" -H "Authorization: Bearer $TOKEN")
    MIGRATION_DONE=$(echo "$FLAG_JSON" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = d.get('result', '{}')
if inner and inner != 'null':
    inner = json.loads(inner) if isinstance(inner, str) else inner
    print(inner.get('value', ''))
else:
    print('')
" 2>/dev/null)
    
    # If migration already done, skip check
    [ -n "$MIGRATION_DONE" ] && return
    
    # Check for v2 key patterns (flat keys without proper namespace)
    V2_PATTERN=$(echo "$KEYS_JSON" | python3 -c "
import sys, json
keys = json.loads(sys.stdin.read()).get('result', [])
v2_keys = []
for k in keys:
    # Skip system/flag keys
    if k.startswith('ron:health:') or k.startswith('ron:reinforce:') or k.startswith('ron:migration:'):
        continue
    short = k[4:] if k.startswith('ron:') else k  # Remove ron: prefix
    # v2 keys are flat (no : in them) or old flat patterns
    if ':' not in short and not short.startswith('user:') and not short.startswith('family:') and not short.startswith('story:') and not short.startswith('contact:') and not short.startswith('project:') and not short.startswith('vehicle:') and not short.startswith('pref:') and not short.startswith('archive:') and not short.startswith('reminder:') and not short.startswith('goal:'):
        v2_keys.append(k)
if v2_keys:
    print('⚠️  WARNING: v2 keys detected. Consider running migration:')
    for vk in v2_keys[:5]:
        print(f'  - {vk}')
    if len(v2_keys) > 5:
        print(f'  ... and {len(v2_keys) - 5} more')
    print('  Run: ./scripts/memory-migrate-v2-to-v3.sh --force')
else:
    print('')
" 2>/dev/null)
    
    [ -n "$V2_PATTERN" ] && echo "$V2_PATTERN"
}

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

# Check for v2 migration needed
check_v2_migration_needed