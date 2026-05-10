#!/bin/bash
# memory-search.sh v3 — Fuzzy/natural language search across Redis and local cache
# Allows searching without knowing exact key names

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"

usage() {
    cat << EOF
Usage: memory-search.sh <query> [--limit N] [--namespace NS]
Fuzzy search across all memories without needing exact key names.

Options:
  <query>        Search query (e.g. "car", "what car does Alex have")
  --limit N      Maximum results to return (default: 10)
  --namespace NS Filter to specific namespace (e.g. "vehicle", "family")

Examples:
  memory-search.sh "car"
  memory-search.sh "what car does Alex have"
  memory-search.sh "wife birthday" --limit 5
  memory-search.sh "Pat" --namespace user
EOF
}

QUERY=""
LIMIT=10
NAMESPACE_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --limit) LIMIT="$2"; shift 2 ;;
        --namespace) NAMESPACE_FILTER="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) QUERY="$1"; shift ;;
    esac
done

if [ -z "$QUERY" ]; then
    usage
    exit 1
fi

# Normalize query
QUERY_LC=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

echo "🔍 Searching for: $QUERY"
echo "=============================="
echo ""

# Write Python script to temp file to avoid bash heredoc issues
PYTHON_SCRIPT=$(mktemp)
cat > "$PYTHON_SCRIPT" << 'PYEOF'
import json
import sys
import subprocess

TOKEN = 'gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL = 'https://summary-hare-109926.upstash.io'

QUERY_LC = sys.argv[1]
LIMIT = int(sys.argv[2]) if len(sys.argv) > 2 else 10
NAMESPACE_FILTER = sys.argv[3] if len(sys.argv) > 3 else ""
QUERY_WORDS = [w.strip() for w in QUERY_LC.split() if w.strip()]

def calculate_score(key, value):
    key_lc = key.lower()
    value_lc = value.lower()
    score = 0
    
    if QUERY_LC in key_lc:
        score += 50
    
    for word in QUERY_WORDS:
        if word in key_lc:
            score += 20
        if word in value_lc:
            score += 10
    
    ns = key.split(':')[0] if ':' in key else key
    if ns == 'family':
        for kw in ['family', 'wife', 'husband', 'kids', 'children', 'son', 'daughter', 'birthday', 'parent', 'sibling']:
            if kw in QUERY_LC:
                score += 15
    elif ns == 'vehicle':
        for kw in ['car', 'vehicle', 'drive', 'commute', 'auto']:
            if kw in QUERY_LC:
                score += 15
    elif ns == 'project':
        for kw in ['project', 'code', 'feature', 'build', 'debug', 'test', 'deploy']:
            if kw in QUERY_LC:
                score += 15
    elif ns in ['user', 'contact', 'goal']:
        for kw in ['name', 'preference', 'setting']:
            if kw in QUERY_LC:
                score += 15
    
    return score

results = []

result = subprocess.run(
    ['curl', '-s', f'{URL}/keys/ron:*', '-H', f'Authorization: Bearer {TOKEN}'],
    capture_output=True, text=True, timeout=30
)
all_keys = json.loads(result.stdout).get('result', [])

for redis_key in all_keys:
    if not isinstance(redis_key, str):
        continue
    if redis_key.startswith('ron:reinforce:') or redis_key.startswith('ron:archive:'):
        continue
    
    short_key = redis_key[4:]
    
    if NAMESPACE_FILTER:
        ns = short_key.split(':')[0] if ':' in short_key else short_key
        if ns != NAMESPACE_FILTER:
            continue
    
    try:
        result = subprocess.run(
            ['curl', '-s', f'{URL}/get/{redis_key}', '-H', f'Authorization: Bearer {TOKEN}'],
            capture_output=True, text=True, timeout=5
        )
        data = json.loads(result.stdout)
        inner = json.loads(data.get('result', '{}'))
        value = inner.get('value', '')
        
        if value:
            score = calculate_score(short_key, value)
            if score > 0:
                results.append((score, short_key, value))
    except Exception as e:
        continue

results.sort(key=lambda x: -x[0])

if not results:
    print(f"No results found for: {QUERY_LC}")
else:
    for score, key, value in results[:LIMIT]:
        print(f"[{score}] {key} = {value}")
PYEOF

python3 "$PYTHON_SCRIPT" "$QUERY_LC" "$LIMIT" "$NAMESPACE_FILTER"
rm -f "$PYTHON_SCRIPT"
