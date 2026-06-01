#!/bin/bash
# memory-healthcheck.sh — Verify Ron-Memory is fully operational

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"
MIGRATION_FLAG_KEY="ron:migration:v2to:v3:done"
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
if [ "$TEST_VALUE" = "Alex" ]; then
    echo "✅ Redis READ: Working (user_name = Alex)"
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

# 5. Check for v2 keys if migration not flagged
MIGRATION_FLAG_JSON=$(curl -s "$URL/get/$MIGRATION_FLAG_KEY" -H "Authorization: Bearer $TOKEN")
MIGRATION_DONE=$(echo "$MIGRATION_FLAG_JSON" | python3 -c "
import sys,json
d=json.loads(sys.stdin.read())
inner=d.get('result','{}')
if inner and inner!='null':
    inner=json.loads(inner) if isinstance(inner,str) else inner
    print(inner.get('value',''))
else:
    print('')
" 2>/dev/null)

if [ -z "$MIGRATION_DONE" ]; then
    # Check for v2 keys
    V2_KEYS=$(echo "$KEYS_JSON" | python3 -c "
import sys,json
keys=json.loads(sys.stdin.read()).get('result',[])
v2=[]
for k in keys:
    if k.startswith('ron:health:') or k.startswith('ron:reinforce:') or k.startswith('ron:migration:'):
        continue
    short=k[4:] if k.startswith('ron:') else k
    if ':' not in short and not short.startswith('user:') and not short.startswith('family:') and not short.startswith('story:') and not short.startswith('contact:') and not short.startswith('project:') and not short.startswith('vehicle:') and not short.startswith('pref:') and not short.startswith('archive:') and not short.startswith('reminder:') and not short.startswith('goal:'):
        v2.append(k)
print(f'V2_KE YS_FOUND:{len(v2)}')
for k in v2[:3]:
    print(k)
" 2>/dev/null)
    
    V2_COUNT=$(echo "$V2_KEYS" | head -1 | grep -oP 'V2_KEYS_FOUND:\K\d+' || echo "0")
    
    if [ -n "$V2_KEYS" ] && [ "$V2_COUNT" -gt 0 ]; then
        echo "⚠️  WARNING: v2 keys detected but migration not flagged!"
        echo "    Found $V2_COUNT v2-style keys"
        echo "    Run: ./scripts/memory-migrate-v2-to-v3.sh --force"
    else
        echo "✅ Migration status: v2 keys detected (migration may be needed)"
    fi
else
    echo "✅ Migration status: v2 → v3 migration complete"
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