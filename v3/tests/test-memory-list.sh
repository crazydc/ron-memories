#!/bin/bash
# test-memory-list.sh — Test listing functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/memory-list.sh"

CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"

setup() {
    # Create a minimal cache file with test entries
    mkdir -p "$(dirname "$CACHE_FILE")"
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$CACHE_FILE" << EOF
# Ron Memory Cache
# Last synced: $NOW

| Key | Value | Updated |
|-----|-------|--------|
| project:heyron | Heyron AI project | $NOW |
| family:wife | Louise | $NOW |
| user:name | Dale | $NOW |
| vehicle:car | BMW | $NOW |
EOF
}

cleanup() {
    rm -f "$CACHE_FILE"
}

trap cleanup EXIT

# Setup: Create test cache
setup

# Test 1: Basic list shows all entries
echo "Testing basic list..."
output=$(memory-list.sh 2>&1)
if echo "$output" | grep -q "project:heyron" && \
   echo "$output" | grep -q "family:wife"; then
    echo "✅ PASS: Basic list works"
else
    echo "❌ FAIL: Basic list missing entries"
    exit 1
fi

# Test 2: --namespace filter works
echo "Testing --namespace filter..."
output=$(memory-list.sh --namespace family 2>&1)
if echo "$output" | grep -q "family:wife"; then
    if echo "$output" | grep -q "project:heyron"; then
        echo "❌ FAIL: --namespace filter not working (project included)"
        exit 1
    else
        echo "✅ PASS: --namespace filter works"
    fi
else
    echo "❌ FAIL: --namespace filter not working"
    exit 1
fi

# Test 3: --stats shows statistics
echo "Testing --stats mode..."
output=$(memory-list.sh --stats 2>&1)
if echo "$output" | grep -q "Total entries:" && \
   echo "$output" | grep -q "By namespace:"; then
    echo "✅ PASS: --stats mode works"
else
    echo "❌ FAIL: --stats mode not working"
    exit 1
fi

# Test 4: --summarize shows summary
echo "Testing --summarize mode..."
output=$(memory-list.sh --summarize 2>&1)
if echo "$output" | grep -q "project:" && \
   echo "$output" | grep -q "family:"; then
    echo "✅ PASS: --summarize mode works"
else
    echo "❌ FAIL: --summarize mode not working"
    exit 1
fi

# Test 5: Handles missing cache file gracefully
echo "Testing missing cache file..."
rm -f "$CACHE_FILE"
output=$(memory-list.sh 2>&1)
if echo "$output" | grep -q "No cache file found"; then
    echo "✅ PASS: Missing cache file handled"
else
    echo "❌ FAIL: Missing cache file not handled"
    exit 1
fi

# Test 6: Entry count shown
echo "Testing entry count..."
setup
output=$(memory-list.sh 2>&1)
if echo "$output" | grep -q "entries shown"; then
    echo "✅ PASS: Entry count shown"
else
    echo "❌ FAIL: Entry count not shown"
    exit 1
fi

echo ""
echo "=== All memory-list tests passed ==="
exit 0