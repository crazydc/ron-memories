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
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$REDIS_URL/set/$REDIS_KEY" \
    -H "Authorization: $REDIS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"value\": \"$VALUE\", \"timestamp\": \"$TIMESTAMP\"}")

# Extract HTTP status code (last line)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | head -n-1)

# Check for network/curl errors
if [ "$HTTP_CODE" = "000" ]; then
    echo "ERROR: Could not connect to Redis - check URL and credentials"
    exit 1
fi

# Check HTTP status
if [ "$HTTP_CODE" -ge 400 ]; then
    echo "ERROR: Redis returned HTTP $HTTP_CODE: $RESPONSE_BODY"
    exit 1
fi

# Check if Redis returned an error
if echo "$RESPONSE_BODY" | grep -q '"error"'; then
    echo "ERROR: Failed to write to Redis: $RESPONSE_BODY"
    exit 1
fi

# Verify the write actually worked (result should not be null)
if echo "$RESPONSE_BODY" | grep -q '"result":null'; then
    echo "ERROR: Write failed - check credentials. Response: $RESPONSE_BODY"
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