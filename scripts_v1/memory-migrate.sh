#!/bin/bash
# Ron Memory - Migrate keys to new namespace structure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    echo "Usage: memory-migrate <old_prefix> <new_prefix>"
    echo "Example: memory-migrate robby contact:robby"
    echo ""
    echo "This will migrate all keys matching <old_prefix>:* to <new_prefix>:*"
    echo "WARNING: This modifies keys in Redis and local file."
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

OLD_PREFIX="$1"
NEW_PREFIX="$2"

echo "Migrating keys from '$OLD_PREFIX' to '$NEW_PREFIX'..."

# Get all keys matching the old prefix
KEYS=$(curl -s -X GET "$REDIS_URL/keys/$REDIS_KEY*" \
    -H "Authorization: $REDIS_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null | \
    grep -o '"[^+"]*"' | tr -d '"' | grep "^${REDIS_KEY}" | sed "s|^${REDIS_KEY}||")

if [ -z "$KEYS" ]; then
    echo "No keys found matching '$OLD_PREFIX:*'"
    exit 0
fi

MIGRATED=0
for OLD_KEY in $KEYS; do
    # Extract the key suffix (everything after the old prefix)
    SUFFIX="${OLD_KEY#$OLD_PREFIX:}"
    
    # Construct new key
    NEW_KEY="${NEW_PREFIX}:${SUFFIX}"
    FULL_OLD_KEY="${REDIS_KEY}${OLD_KEY}"
    FULL_NEW_KEY="${REDIS_KEY}${NEW_KEY}"
    
    # Get current value
    VALUE=$(curl -s -X GET "$REDIS_URL/get/$FULL_OLD_KEY" \
        -H "Authorization: $REDIS_TOKEN" | \
        grep -o '"result":"[^"]*"' | sed 's/"result":"//;s/"$//')
    
    if [ -n "$VALUE" ] && [ "$VALUE" != "null" ]; then
        # Set new key
        curl -s -X POST "$REDIS_URL/set/$FULL_NEW_KEY" \
            -H "Authorization: $REDIS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"value\": \"$VALUE\"}" > /dev/null
        
        # Delete old key
        curl -s -X POST "$REDIS_URL/del/$FULL_OLD_KEY" \
            -H "Authorization: $REDIS_TOKEN" > /dev/null
        
        echo "  ✓ $OLD_KEY → $NEW_KEY"
        MIGRATED=$((MIGRATED + 1))
    fi
done

echo ""
echo "Migrated $MIGRATED keys"

# Update local file
if [ -f "$MEMORY_FILE" ]; then
    echo "Updating local cache..."
    sed -i "s/| $OLD_PREFIX:/| $NEW_PREFIX:/g" "$MEMORY_FILE" 2>/dev/null
    echo "  ✓ Local file updated"
fi

echo ""
echo "Migration complete!"
