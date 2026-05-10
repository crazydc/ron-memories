#!/bin/bash
# test-memory-get.sh — Test retrieval functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/memory-set.sh"
source "$SCRIPT_DIR/../scripts/memory-get.sh"

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"

TEST_KEY="test:TEMP:key_$(date +%s)_$$"
TEST_VALUE="get_test_value_456"

cleanup() {
    # Clean up test key from Redis
    curl -s -X POST "$URL/set/$TEST_KEY" -H "Authorization: Bearer $TOKEN" -d '{"value": ""}' >/dev/null 2>&1 || true
    curl -s -X POST "$URL/set/ron:reinforce:last:$TEST_KEY" -H "Authorization: Bearer $TOKEN" -d '{"value": ""}' >/dev/null 2>&1 || true
    curl -s -X POST "$URL/set/ron:reinforce:count:$TEST_KEY" -H "Authorization: Bearer $TOKEN" -d '{"value": ""}' >/dev/null 2>&1 || true
    
    # Clean up from cache file
    if [ -f "$CACHE_FILE" ]; then
        grep -v "^| $TEST_KEY " "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null || true
        mv "$CACHE_FILE.tmp" "$CACHE_FILE" 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Pre-condition: Set a known value
memory-set.sh "$TEST_KEY" "$TEST_VALUE" >/dev/null 2>&1
sleep 1

# Test 1: Basic retrieval from Redis
echo "Testing basic retrieval..."
output=$(memory-get.sh "$TEST_KEY")
if [ "$output" = "$TEST_VALUE" ]; then
    echo "✅ PASS: Basic retrieval works"
else
    echo "❌ FAIL: Basic retrieval failed"
    echo "   Expected: $TEST_VALUE"
    echo "   Got: $output"
    exit 1
fi

# Test 2: Access count is incremented
echo "Testing access count tracking..."
sleep 1
count_response=$(curl -s "$URL/get/ron:reinforce:count:$TEST_KEY" -H "Authorization: Bearer $TOKEN")
if echo "$count_response" | grep -q "1"; then
    echo "✅ PASS: Access count incremented"
else
    echo "❌ FAIL: Access count not incremented"
    echo "   Response: $count_response"
    exit 1
fi

# Test 3: Multiple accesses increment counter
echo "Testing multiple access tracking..."
memory-get.sh "$TEST_KEY" >/dev/null 2>&1
sleep 1
count_response=$(curl -s "$URL/get/ron:reinforce:count:$TEST_KEY" -H "Authorization: Bearer $TOKEN")
if echo "$count_response" | grep -q "2"; then
    echo "✅ PASS: Multiple access tracking works"
else
    echo "❌ FAIL: Multiple access tracking failed"
    exit 1
fi

# Test 4: Last access time updated
echo "Testing last access time..."
last_response=$(curl -s "$URL/get/ron:reinforce:last:$TEST_KEY" -H "Authorization: Bearer $TOKEN")
if echo "$last_response" | grep -q "timestamp"; then
    echo "✅ PASS: Last access time updated"
else
    echo "❌ FAIL: Last access time not updated"
    exit 1
fi

# Test 5: Non-existent key returns error
echo "Testing non-existent key..."
non_existent_output=$(memory-get.sh "test:TEMP:nonexistent_$$" 2>&1)
if echo "$non_existent_output" | grep -q "not found"; then
    echo "✅ PASS: Non-existent key handled correctly"
else
    echo "❌ FAIL: Non-existent key not handled correctly"
    exit 1
fi

echo ""
echo "=== All memory-get tests passed ==="
exit 0