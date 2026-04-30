#!/bin/bash
# Ron Memory - Set a memory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    echo "Usage: memory-set <key> <value>"
    echo "Example: memory-set favorite_color blue"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

KEY="$1"
VALUE="$2"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build Redis key
REDIS_KEY="ron:user:$KEY"

# Save to Redis - Upstash REST API uses /set/key endpoint
RESPONSE=$(curl -s -X POST "$REDIS_URL/set/$REDIS_KEY" \
    -H "Authorization: $REDIS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"value\": \"$VALUE\", \"timestamp\": \"$TIMESTAMP\"}")

# Check if Redis write succeeded
if echo "$RESPONSE" | grep -q '"error"'; then
    echo "ERROR: Failed to write to Redis: $RESPONSE"
    exit 1
fi

# Update local memory.md
update_local() {
    local key="$1"
    local value="$2"
    local ts="$3"
    
    local entry="| $key | $value | $ts |"
    
    # Check if key already exists in memory.md
    if grep -q "| $key |" "$MEMORY_FILE" 2>/dev/null; then
        # Update existing entry
        sed -i "s/| $key |.*|.*|/$entry/" "$MEMORY_FILE"
    else
        # Append new entry
        echo "$entry" >> "$MEMORY_FILE"
    fi
}

# Create local file if it doesn't exist
if [ ! -f "$MEMORY_FILE" ]; then
    cat > "$MEMORY_FILE" << 'EOF'
# Ron Memory Cache
# Last synced: 

| Key | Value | Updated |
|-----|-------|---------|
EOF
fi

# Update local file
update_local "$KEY" "$VALUE" "$TIMESTAMP"

echo "OK: Saved '$KEY' = '$VALUE'"
echo "  - Redis: $REDIS_KEY"
echo "  - Local: $MEMORY_FILE"