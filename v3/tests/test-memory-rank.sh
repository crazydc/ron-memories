#!/bin/bash
# test-memory-rank.sh — Test ranking functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/memory-rank.sh"

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
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
| family:wife | Pat | $NOW |
| user:name | Alex | $NOW |
| vehicle:car | car | $NOW |
EOF
}

cleanup() {
    rm -f /tmp/memory_rank_input.txt
}

trap cleanup EXIT

# Setup: Create test cache
setup

# Test 1: Basic ranking returns results
echo "Testing basic ranking..."
output=$(memory-rank.sh "working on project" --limit 5)
if [ -n "$output" ]; then
    echo "✅ PASS: Basic ranking returns results"
else
    echo "❌ FAIL: Basic ranking returned no results"
    exit 1
fi

# Test 2: Project keyword boosts project namespace
echo "Testing namespace boosting..."
output=$(memory-rank.sh "coding on project" --limit 5)
if echo "$output" | grep -q "project:heyron"; then
    echo "✅ PASS: Project namespace boosted"
else
    echo "❌ FAIL: Project namespace not boosted"
    echo "   Output: $output"
    exit 1
fi

# Test 3: Family keyword boosts family namespace
echo "Testing family namespace boosting..."
output=$(memory-rank.sh "family birthday" --limit 5)
if echo "$output" | grep -q "family:wife"; then
    echo "✅ PASS: Family namespace boosted"
else
    echo "❌ FAIL: Family namespace not boosted"
    exit 1
fi

# Test 4: --limit flag works
echo "Testing --limit flag..."
output=$(memory-rank.sh "anything" --limit 2)
line_count=$(echo "$output" | grep -c "\[")
if [ "$line_count" -le 2 ]; then
    echo "✅ PASS: --limit flag works"
else
    echo "❌ FAIL: --limit flag not respected ($line_count lines)"
    exit 1
fi

# Test 5: --namespaces filter works
echo "Testing --namespaces filter..."
output=$(memory-rank.sh "anything" --namespaces project --limit 5)
if echo "$output" | grep -q "project:"; then
    if echo "$output" | grep -q "family:"; then
        echo "❌ FAIL: --namespaces filter not working (family included)"
        exit 1
    else
        echo "✅ PASS: --namespaces filter works"
    fi
else
    echo "❌ FAIL: --namespaces filter not working"
    exit 1
fi

# Test 6: Empty task shows usage
echo "Testing empty task handling..."
empty_output=$(memory-rank.sh "" 2>&1)
if echo "$empty_output" | grep -q "Usage\|task_context"; then
    echo "✅ PASS: Empty task handled correctly"
else
    echo "❌ FAIL: Empty task not handled"
    exit 1
fi

echo ""
echo "=== All memory-rank tests passed ==="
exit 0