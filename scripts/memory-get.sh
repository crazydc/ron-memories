#!/bin/bash
# Ron Memory - Get a memory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    echo "Usage: memory-get <key>"
    echo "Example: memory-get favorite_color"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

KEY="$1"
REDIS_KEY="ron:user:$KEY"

# Read from Redis - Upstash REST API uses /get/key endpoint
RESPONSE=$(curl -s -X GET "$REDIS_URL/get/$REDIS_KEY" \
    -H "Authorization: $REDIS_TOKEN")

# Check for error
if echo "$RESPONSE" | grep -q '"error"'; then
    echo "ERROR: Key not found or Redis error: $RESPONSE"
    exit 1
fi

# Use Python to parse the nested JSON
VALUE=$(python3 -c "
import json
import sys
try:
    response = json.loads(sys.stdin.read())
    result = json.loads(response['result'])
    print(result.get('value', ''))
except Exception as e:
    print('', end='')
" <<< "$RESPONSE")

if [ -z "$VALUE" ]; then
    echo "Key '$KEY' not found"
    exit 1
fi

echo "$VALUE"