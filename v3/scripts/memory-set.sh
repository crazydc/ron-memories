#!/bin/bash
# memory-set.sh v3 — Save a memory, touch reinforce: keys for freshness

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"
MIGRATION_FLAG_KEY="ron:migration:v2to:v3:done"

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
    
    # Check for v2 key patterns (flat keys without namespace separators)
    V2_PATTERN=$(echo "$KEYS_JSON" | python3 -c "
import sys, json
keys = json.loads(sys.stdin.read()).get('result', [])
v2_keys = []
for k in keys:
    # Skip system/flag keys
    if k.startswith('ron:health:') or k.startswith('ron:reinforce:') or k.startswith('ron:migration:'):
        continue
    short = k[4:] if k.startswith('ron:') else k  # Remove ron: prefix
    # v2 keys are flat (no : in them) or start with old prefixes
    if ':' not in short and not short.startswith('user:') and not short.startswith('family:') and not short.startswith('story:') and not short.startswith('contact:') and not short.startswith('project:') and not short.startswith('vehicle:') and not short.startswith('pref:') and not short.startswith('archive:') and not short.startswith('reminder:') and not short.startswith('goal:'):
        v2_keys.append(k)
if v2_keys:
    print('WARNING: v2 keys detected. Consider running migration:')
    for vk in v2_keys[:5]:
        print(f'  - {vk}')
    if len(v2_keys) > 5:
        print(f'  ... and {len(v2_keys) - 5} more')
else:
    print('')
" 2>/dev/null)
    
    [ -n "$V2_PATTERN" ] && echo "$V2_PATTERN"
}

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

# Check for v2 migration needed
check_v2_migration_needed
