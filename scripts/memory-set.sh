#!/bin/bash
# memory-set.sh v3.3 — Save a memory with tier + importance + context support
# Enhanced with --stale-ok flag and auto-archive for conflicting values

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"
ARCHIVE_DIR="/root/.openclaw/workspace/memory/archive"
MIGRATION_FLAG_KEY="ron:migration:v2to:v3:done"

# Default tier based on key prefix (can be overridden with --tier)
get_default_tier() {
    local key="$1"
    case "$key" in
        anchored:*|family:*|user:*|contact:*|vehicle:*|book:*|career:*)
            echo "anchored"
            ;;
        semantic:*|pref:*|project:*|goal:*|service:*|agent:*)
            echo "semantic"
            ;;
        episodic:*|reminder:*)
            echo "episodic"
            ;;
        working:*)
            echo "working"
            ;;
        *)
            echo "semantic"  # default tier
            ;;
    esac
}

# Archive an old value before overwriting
archive_value() {
    local key="$1"
    local old_value="$2"
    local timestamp="$3"
    
    mkdir -p "$ARCHIVE_DIR"
    
    # Create archive entry with timestamp of when it was archived
    local archive_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local archive_key="${key}.archived.$(date +%Y%m%d_%H%M%S)"
    
    # Write to archive file
    local archive_file="$ARCHIVE_DIR/$(date +%Y-%m).md"
    mkdir -p "$ARCHIVE_DIR"
    echo "| $archive_key | $old_value | $timestamp | archived=$archive_time |" >> "$archive_file"
    
    # Also save to Redis for long-term archival
    local redis_key="ron:archive:$archive_key"
    cat << EOF > /tmp/archive_payload.json
{"value": "$old_value", "timestamp": "$timestamp", "archived": "$archive_time", "original_key": "$key"}
EOF
    curl -s -X POST "$URL/set/$redis_key" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d @/tmp/archive_payload.json >/dev/null 2>&1
    rm -f /tmp/archive_payload.json
}

check_v2_migration_needed() {
    KEYS_JSON=$(curl -s "$URL/keys/ron:*" -H "Authorization: Bearer $TOKEN")
    
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
    
    [ -n "$MIGRATION_DONE" ] && return
    
    V2_PATTERN=$(echo "$KEYS_JSON" | python3 -c "
import sys, json
keys = json.loads(sys.stdin.read()).get('result', [])
v2_keys = []
for k in keys:
    if k.startswith('ron:health:') or k.startswith('ron:reinforce:') or k.startswith('ron:migration:'):
        continue
    short = k[4:] if k.startswith('ron:') else k
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
Usage: memory-set.sh <key> <value> [--tier TIER] [--importance N] [--context TAGS] [--force] [--stale-ok]

Save a memory to Redis + local cache with optional tier, importance, and context tags.

Arguments:
  <key>           Memory key (use prefixed format: tier:key)
  <value>         Memory value

Options:
  --tier TIER     Memory tier: anchored, semantic, episodic, reminder, working
                  (auto-detected from key prefix if not specified)
  --importance N  Importance score 1-100 (higher = more persistent)
                  Default: 50
  --context TAGS  Comma-separated context tags (e.g. "holiday,lakes,sam")
                  Used for context-aware retrieval
  --force         Overwrite existing key without warning
  --stale-ok      Override staleness warning (auto-archives old conflicting value)
                  This archives the old value instead of rejecting the overwrite

Examples:
  # Basic save (auto-detects tier from prefix)
  memory-set.sh anchored:sam_birthday "2020-04-15"
  memory-set.sh semantic:acasey_preferences "concise communication"
  
  # Explicit tier + importance + context
  memory-set.sh "trip_lakes" "lakes holiday" --tier episodic --importance 70 --context "holiday,lakes"
  
  # Family info with context
  memory-set.sh "sam_loves" "reptiles and birds" --context "holiday,animals,sam" --importance 60
  
  # Overwrite existing (no questions)
  memory-set.sh reminder:call_zoo "Follow up" --force
  
  # Overwrite with auto-archive of old value
  memory-set.sh reminder:call_zoo "Follow up" --stale-ok
EOF
}

FORCE=false
STALE_OK=false
TIER=""
IMPORTANCE=50
CONTEXT=""
KEY=""
VALUE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=true; shift ;;
        --stale-ok) STALE_OK=true; shift ;;
        --tier) TIER="$2"; shift 2 ;;
        --importance) IMPORTANCE="$2"; shift 2 ;;
        --context) CONTEXT="$2"; shift 2 ;;
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

# Auto-detect tier from key prefix if not specified
if [ -z "$TIER" ]; then
    TIER=$(get_default_tier "$KEY")
fi

# Validate tier
case "$TIER" in
    anchored|semantic|episodic|reminder|working) ;;
    *)
        echo "❌ Invalid tier: $TIER"
        echo "Valid tiers: anchored, semantic, episodic, reminder, working"
        exit 1
        ;;
esac

# Validate importance
if ! [[ "$IMPORTANCE" =~ ^[0-9]+$ ]] || [ "$IMPORTANCE" -lt 1 ] || [ "$IMPORTANCE" -gt 100 ]; then
    echo "❌ Invalid importance: $IMPORTANCE (must be 1-100)"
    exit 1
fi

# Build metadata string
METADATA="tier=$TIER importance=$IMPORTANCE"
if [ -n "$CONTEXT" ]; then
    METADATA="$METADATA context=$CONTEXT"
fi

# Check for staleness and handle conflict
if [ -f "$CACHE_FILE" ] && grep -q "^| $KEY |" "$CACHE_FILE" 2>/dev/null; then
    OLD_LINE=$(grep "^| $KEY |" "$CACHE_FILE" | head -1)
    OLD_VALUE=$(echo "$OLD_LINE" | awk -F'|' '{gsub(/^ *| *$/, "", $3); print $3}')
    OLD_TS=$(echo "$OLD_LINE" | awk -F'|' '{gsub(/^ *| *$/, "", $4); print $4}')
    
    if [ -n "$OLD_VALUE" ] && [ "$OLD_VALUE" != "$VALUE" ]; then
        if [ "$FORCE" = true ]; then
            # Force mode: just overwrite, no archive
            echo "⚠️  Overwriting '$KEY' (--force)"
        elif [ "$STALE_OK" = true ]; then
            # Stale-ok mode: archive old value then overwrite
            echo "📦 Archiving old value for '$KEY'"
            archive_value "$KEY" "$OLD_VALUE" "$OLD_TS"
        else
            # Default: reject with warning
            echo "⚠️  Staleness detected: '$KEY' already exists"
            echo "   Old: '$OLD_VALUE' (updated: $OLD_TS)"
            echo "   New: '$VALUE'"
            echo ""
            echo "Options:"
            echo "  --force    Overwrite without archiving (old value lost)"
            echo "  --stale-ok Archive old value and save new one"
            exit 1
        fi
    fi
fi

# Save to Redis with extended JSON format (includes tier + importance + context)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REDIS_KEY="ron:$KEY"
JSON_PAYLOAD="{\"value\": \"$VALUE\", \"timestamp\": \"$TIMESTAMP\", \"tier\": \"$TIER\", \"importance\": $IMPORTANCE}"
if [ -n "$CONTEXT" ]; then
    JSON_PAYLOAD="$JSON_PAYLOAD, \"context\": \"$CONTEXT\""
fi
JSON_PAYLOAD="$JSON_PAYLOAD}"

curl -s -X POST "$URL/set/$REDIS_KEY" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$JSON_PAYLOAD" >/dev/null 2>&1

# Update local cache
mkdir -p "$(dirname "$CACHE_FILE")"
touch "$CACHE_FILE"
grep -v "^| $KEY |" "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null || true
mv "$CACHE_FILE.tmp" "$CACHE_FILE"
echo "| $KEY | $VALUE | $TIMESTAMP | $METADATA |" >> "$CACHE_FILE"

# Touch reinforce:last:<key> to mark freshness on save
LAST_KEY="ron:reinforce:last:$KEY"
curl -s -X POST "$URL/set/$LAST_KEY" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"value\": \"$TIMESTAMP\", \"timestamp\": \"$TIMESTAMP\"}" >/dev/null 2>&1

CONTEXT_INFO=""
if [ -n "$CONTEXT" ]; then
    CONTEXT_INFO=" context=$CONTEXT"
fi
echo "✅ Saved '$KEY' = '$VALUE' (tier=$TIER, importance=$IMPORTANCE$CONTEXT_INFO)"

# Auto-detect relationships and suggest links (using Python for better regex)
AUTO_LINK_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/memory-links.sh"
if [ -f "$AUTO_LINK_SCRIPT" ]; then
    # Extract entity from key (first part before underscore or colon)
    entity_from_key=""
    if [[ "$KEY" =~ ^([^:_]+) ]]; then
        entity_from_key="${BASH_REMATCH[1]}"
    fi
    
    # Use Python for more robust relationship detection
    python3 << PYSCRIPT
import re, subprocess

key = """$KEY"""
value = """$VALUE"""
entity_from_key = "$entity_from_key"
auto_script = "$AUTO_LINK_SCRIPT"

value_lc = value.lower()
detected_links = []

# loves pattern: "loves X and Y and Z"
if 'loves' in value_lc:
    match = re.search(r'loves\s+(.+)', value, re.IGNORECASE)
    if match:
        rest = match.group(1).strip()
        items = re.split(r'\s+and\s+', rest)
        for item in items:
            # Get capitalized words from original item
            caps = re.findall(r'[A-Z][a-z]+', item)
            if caps:
                target = caps[-1].lower()  # Last capitalized word
                detected_links.append(("loves", target))
            else:
                # No capitals - use first meaningful word
                words = item.split()
                for word in words:
                    if word.lower() not in ['the', 'a', 'an', 'at', 'in', 'on']:
                        detected_links.append(("loves", word.lower()))
                        break

# works_at pattern
if re.search(r'works?\s+(?:at|for)', value_lc):
    match = re.search(r'works?\s+(?:at|for)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)', value, re.IGNORECASE)
    if match:
        target = match.group(1).lower().replace(' ', '_')
        detected_links.append(("works_at", target))

# visited pattern
if re.search(r'visited?', value_lc):
    match = re.search(r'visited?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)', value, re.IGNORECASE)
    if match:
        target = match.group(1).lower().replace(' ', '_')
        detected_links.append(("visited", target))

# Output detected links
if detected_links and entity_from_key:
    print("")
    print(f"💡 Detected potential links for '{entity_from_key}':")
    seen = set()
    for rel, target in detected_links:
        link_key = f"{rel}:{target}"
        if link_key not in seen:
            seen.add(link_key)
            print(f"   - {entity_from_key} --{rel}--> {target}")
    print("")
    print(f"   Run '{auto_script} add <entity> <relationship> <target>' to create links")
PYSCRIPT
fi

# Check for v2 migration needed
check_v2_migration_needed
