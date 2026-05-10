#!/bin/bash
# Ron Memory - List all memories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# List all keys matching ron:*
RESPONSE=$(curl -s -X GET "$REDIS_URL/keys/ron:*" \
    -H "Authorization: $REDIS_TOKEN")

# Check for error
if echo "$RESPONSE" | grep -q '"error"'; then
    echo "ERROR: Redis error: $RESPONSE"
    exit 1
fi

# Extract keys - Upstash returns array of keys
echo "$RESPONSE" | grep -o '"result":\[[^]]*\]' | sed 's/.*"result":\[//;s/\].*//;s/"//g' | tr ',' '\n' | while read -r key; do
    if [ -n "$key" ]; then
        echo "$key" | sed 's/^ron:user://'
    fi
done

# If no output, try alternative parsing
if [ ! -s /dev/stdout ] 2>/dev/null; then
    echo "$RESPONSE" | grep -oP 'ron:user:\K[^"]+' 
fi