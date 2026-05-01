#!/bin/bash
# memory-set.sh v2 — Save a memory with staleness detection + summarization
# If key already exists, detects conflicts and optionally compresses old value

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-set.sh <key> <value> [--compress | --force | --archive-old]
Save a memory to Redis + local cache.

Options:
  --compress    If old value exists, compress it before overwriting
  --force       Overwrite without staleness check
  --archive-old Move current value to archive: prefix before writing new value

Examples:
  memory-set.sh user_name "Dale"
  memory-set.sh vehicle:tesla:reg "XY51 ABC"
  memory-set.sh project:heyron:status "active" --compress
EOF
}

COMPRESS=false
ARCHIVE_OLD=false
FORCE=false
KEY=""
VALUE=""

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --compress) COMPRESS=true; shift ;;
        --force) FORCE=true; shift ;;
        --archive-old) ARCHIVE_OLD=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) 
            if [ -z "$KEY" ]; then
                KEY="$1"
                shift
            elif [ -z "$VALUE" ]; then
                VALUE="$1"
                shift
            else
                # Unknown extra arg
                shift
            fi
            ;;
    esac
done

if [ -z "$KEY" ] || [ -z "$VALUE" ]; then
    usage
    exit 1
fi

# Extract namespace from key
NAMESPACE="${KEY%%:*}"

# Check if key already exists (staleness detection)
if [ -f "$RON_CACHE_FILE" ] && grep -q "^| $KEY " "$RON_CACHE_FILE" 2>/dev/null; then
    # Key exists - check for staleness
    OLD_VALUE=$(grep "^| $KEY " "$RON_CACHE_FILE" | awk -F'|' '{gsub(/^ *| *$/, "", $3); print $3}')
    
    if [ -n "$OLD_VALUE" ] && [ "$OLD_VALUE" != "$VALUE" ] && [ "$FORCE" = false ]; then
        echo "⚠️  Staleness detected: '$KEY' already exists with value '$OLD_VALUE'"
        echo "   New value: '$VALUE'"
        echo "   Use --force to overwrite, --archive-old to archive old value first"
        exit 1
    fi
fi

# Archive old value if requested
if [ "$ARCHIVE_OLD" = true ] && [ -n "$OLD_VALUE" ]; then
    ARCHIVE_KEY="archive:$KEY"
    echo "📦 Archiving old value to '$ARCHIVE_KEY'"
    "$SCRIPT_DIR/memory-set.sh" "$ARCHIVE_KEY" "$OLD_VALUE" --force >/dev/null 2>&1 || true
fi

# Compress old value if requested
if [ "$COMPRESS" = true ] && [ -n "$OLD_VALUE" ] && [ ${#OLD_VALUE} -gt $SUMMARIZE_THRESHOLD ]; then
    ARCHIVE_KEY="archive:$KEY"
    echo "📝 Compressing old value to '$ARCHIVE_KEY' (${#OLD_VALUE} chars → summarized)"
    # Simple summarization: first 100 chars + "..." if too long
    if [ ${#OLD_VALUE} -gt 100 ]; then
        COMPRESSED="${OLD_VALUE:0:100}... [archived $(date +%Y-%m-%d)]"
    else
        COMPRESSED="$OLD_VALUE [archived $(date +%Y-%m-%d)]"
    fi
    "$SCRIPT_DIR/memory-set.sh" "$ARCHIVE_KEY" "$COMPRESSED" --force >/dev/null 2>&1 || true
fi

# Save to Redis
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

REDIS_PAYLOAD="{\"key\": \"$KEY\", \"value\": \"$VALUE\", \"timestamp\": \"$TIMESTAMP\"}"
REDIS_RESPONSE=$(curl -s -X POST "$UPSTASH_REDIS_URL/set" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" \
    -d "{\"data\": {\"key\": \"$KEY\", \"value\": \"$VALUE\", \"timestamp\": \"$TIMESTAMP\"}}")

# Save to local cache
mkdir -p "$RON_CACHE_DIR"
touch "$RON_CACHE_FILE"

# Remove existing entry if present
if [ -f "$RON_CACHE_FILE" ]; then
    grep -v "^| $KEY " "$RON_CACHE_FILE" > "$RON_CACHE_FILE.tmp" 2>/dev/null || true
    mv "$RON_CACHE_FILE.tmp" "$RON_CACHE_FILE"
fi

# Append new entry
echo "| $KEY | $VALUE | $TIMESTAMP |" >> "$RON_CACHE_FILE"

echo "✅ Saved '$KEY' = '$VALUE'"
