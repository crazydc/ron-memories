#!/bin/bash
# memory-healthcheck.sh — Verify Ron-Memory is fully operational

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"
ERRORS=0

echo "🔍 Checking Ron-Memory health..."

# 1. Redis connectivity
KEYS_JSON=$(curl -s "$URL/keys/ron:*" -H "Authorization: Bearer $TOKEN" 2>/dev/null)
if [ -z "$KEYS_JSON" ]; then
    echo "❌ Redis: NO CONNECTION"
    ERRORS=$((ERRORS + 1))
else
    KEY_COUNT=$(echo "$KEYS_JSON" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read()).get('result',[])))" 2>/dev/null || echo "0")
    echo "✅ Redis: Connected ($KEY_COUNT keys)"
fi

# 2. Can read a known key
TEST_VALUE=$(curl -s "$URL/get/ron:user:user_name" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
inner=json.loads(d.get('result','{}'))
print(inner.get('value',''))
" 2>/dev/null)
if [ "$TEST_VALUE" = "Dale" ]; then
    echo "✅ Redis READ: Working (user_name = Dale)"
else
    echo "❌ Redis READ: Failed (got: $TEST_VALUE)"
    ERRORS=$((ERRORS + 1))
fi

# 3. Can write and read back
TEST_KEY="health:$(date +%s)"
TEST_VAL="test_$$"
curl -s -X POST "$URL/set/ron:$TEST_KEY" -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d "{\"value\":\"$TEST_VAL\",\"timestamp\":\"2026-05-02T21:00:00Z\"}" >/dev/null 2>&1

READ_BACK=$(curl -s "$URL/get/ron:$TEST_KEY" -H "Authorization: Bearer $TOKEN" | python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
inner=json.loads(d.get('result','{}'))
print(inner.get('value',''))
" 2>/dev/null)

if [ "$READ_BACK" = "$TEST_VAL" ]; then
    echo "✅ Redis WRITE: Working"
else
    echo "❌ Redis WRITE: Failed (wrote '$TEST_VAL', got '$READ_BACK')"
    ERRORS=$((ERRORS + 1))
fi

# 4. Local cache exists
if [ -f "$CACHE_FILE" ]; then
    CACHE_LINES=$(wc -l < "$CACHE_FILE")
    echo "✅ Local cache: exists ($CACHE_LINES lines)"
else
    echo "❌ Local cache: missing"
    ERRORS=$((ERRORS + 1))
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All checks passed"
    exit 0
else
    echo "❌ $ERRORS check(s) failed"
    exit 1
fi