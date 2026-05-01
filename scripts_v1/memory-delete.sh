#!/bin/bash
# Ron Memory - Delete a memory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    echo "Usage: memory-delete <key>"
    echo "Example: memory-delete favorite_color"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

KEY="$1"
REDIS_KEY="ron:user:$KEY"

# Delete from Redis - Upstash uses DELETE endpoint
RESPONSE=$(curl -s -X DELETE "$REDIS_URL/del/$REDIS_KEY" \
    -H "Authorization: $REDIS_TOKEN")

# Remove from local file
if [ -f "$MEMORY_FILE" ]; then
    sed -i "/| $KEY |/d" "$MEMORY_FILE"
fi

echo "OK: Deleted '$KEY'"