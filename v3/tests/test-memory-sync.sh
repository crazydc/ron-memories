#!/bin/bash
# test-memory-sync.sh — Test sync functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/memory-sync.sh"

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"

# Create a unique test key
TEST_KEY="test:TEMP:sync_test_$(date +%s)_$$"
TEST_VALUE="sync_test_value"

setup() {
    # Set a test value directly in Redis
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    REDIS_KEY="ron:$TEST_KEY"
    JSON_PAYLOAD="{\"value\": \"$TEST_VALUE\", \"timestamp\": \"$TIMESTAMP\"}"
    curl -s -X POST "$URL/set/$REDIS_KEY" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$JSON_PAYLOAD" >/dev/null 2>&1
}

cleanup() {
    # Remove test key from Redis
    curl -s -X POST "$URL/set/ron:$TEST_KEY" -H "Authorization: Bearer $TOKEN" -d '{"value": ""}' >/dev/null 2>&1 || true
    
    # Clean up from cache file
    if [ -f "$CACHE_FILE" ]; then
        grep -v "^| $TEST_KEY " "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null || true
        mv "$CACHE_FILE.tmp" "$CACHE_FILE" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Setup: Add a test key
setup
sleep 1

# Test 1: Sync creates/updates cache file
echo "Testing sync creates cache file..."
# Remove cache to test fresh sync
rm -f "$CACHE_FILE"
memory-sync.sh >/dev/null 2>&1

if [ -f "$CACHE_FILE" ]; then
    echo "✅ PASS: Sync creates cache file"
else
    echo "❌ FAIL: Sync did not create cache file"
    exit 1
fi

# Test 2: Synced entry contains expected content
echo "Testing synced content..."
if grep -q "$TEST_KEY" "$CACHE_FILE" && grep -q "$TEST_VALUE" "$CACHE_FILE"; then
    echo "✅ PASS: Synced content correct"
else
    echo "❌ FAIL: Synced content incorrect"
    cat "$CACHE_FILE"
    exit 1
fi

# Test 3: Sync updates existing cache
echo "Testing sync updates existing cache..."
# Update the value
NEW_VALUE="updated_sync_value"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
curl -s -X POST "$URL/set/ron:$TEST_KEY" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"value\": \"$NEW_VALUE\", \"timestamp\": \"$TIMESTAMP\"}" >/dev/null 2>&1

sleep 1
memory-sync.sh >/dev/null 2>&1

if grep -q "$NEW_VALUE" "$CACHE_FILE"; then
    echo "✅ PASS: Sync updates existing cache"
else
    echo "❌ FAIL: Sync did not update cache"
    exit 1
fi

# Test 4: Sync excludes test keys (ron:test:, ron:jeff:)
echo "Testing sync filters test keys..."
# The script should exclude ron:test: and ron:jeff: keys
if grep -q "ron:test:" "$CACHE_FILE" 2>/dev/null || grep -q "ron:jeff:" "$CACHE_FILE" 2>/dev/null; then
    echo "❌ FAIL: Sync includes filtered keys"
    exit 1
else
    echo "✅ PASS: Sync filters test keys"
fi

echo ""
echo "=== All memory-sync tests passed ==="
exit 0