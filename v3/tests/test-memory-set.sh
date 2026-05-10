#!/bin/bash
# test-memory-set.sh — Test save functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/memory-set.sh"

TEST_KEY="test:TEMP:key_$(date +%s)_$$"
TEST_VALUE="test_value_123"
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"

cleanup() {
    # Clean up test key from Redis
    curl -s -X POST "$URL/set/$TEST_KEY" -H "Authorization: Bearer $TOKEN" -d '{"value": ""}' >/dev/null 2>&1 || true
    
    # Clean up from cache file if it exists
    if [ -f "$CACHE_FILE" ]; then
        grep -v "^| $TEST_KEY " "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null || true
        mv "$CACHE_FILE.tmp" "$CACHE_FILE" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Test 1: Basic save
echo "Testing basic memory save..."
output=$(memory-set.sh "$TEST_KEY" "$TEST_VALUE")
if echo "$output" | grep -q "Saved"; then
    echo "✅ PASS: Basic save works"
else
    echo "❌ FAIL: Basic save failed"
    echo "   Output: $output"
    exit 1
fi

# Test 2: Verify saved in Redis
echo "Testing Redis verification..."
sleep 1
response=$(curl -s "$URL/get/$TEST_KEY" -H "Authorization: Bearer $TOKEN")
if echo "$response" | grep -q "$TEST_VALUE"; then
    echo "✅ PASS: Redis storage verified"
else
    echo "❌ FAIL: Redis verification failed"
    echo "   Response: $response"
    exit 1
fi

# Test 3: Verify reinforce:last key was created
echo "Testing reinforce:last key..."
reinforce_key="ron:reinforce:last:$TEST_KEY"
reinforce_response=$(curl -s "$URL/get/$reinforce_key" -H "Authorization: Bearer $TOKEN")
if echo "$reinforce_response" | grep -q "timestamp"; then
    echo "✅ PASS: reinforce:last key created"
else
    echo "❌ FAIL: reinforce:last key not created"
    exit 1
fi

# Test 4: Staleness detection (same key, different value, no --force)
echo "Testing staleness detection..."
stale_output=$(memory-set.sh "$TEST_KEY" "different_value" 2>&1)
if echo "$stale_output" | grep -q "Staleness detected"; then
    echo "✅ PASS: Staleness detection works"
else
    echo "❌ FAIL: Staleness detection failed"
    exit 1
fi

# Test 5: --force flag bypasses staleness
echo "Testing --force flag..."
force_output=$(memory-set.sh "$TEST_KEY" "forced_value" --force)
if echo "$force_output" | grep -q "Saved"; then
    echo "✅ PASS: --force flag works"
else
    echo "❌ FAIL: --force flag failed"
    exit 1
fi

echo ""
echo "=== All memory-set tests passed ==="
exit 0