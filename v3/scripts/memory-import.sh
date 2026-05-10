#!/bin/bash
# memory-import.sh v3 — Import memories from a JSON backup file
# Supports --dry-run, --merge, and --replace modes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

TOKEN="${UPSTASH_REDIS_TOKEN:-gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw}"
URL="${UPSTASH_REDIS_URL:-https://summary-hare-109926.upstash.io}"

usage() {
    cat << EOF
Usage: memory-import.sh <backup-file> [--dry-run] [--merge|--replace]
Import memories from a JSON backup file.

Options:
  <backup-file>     Path to the JSON backup file (required)
  --dry-run         Preview what would be imported without making changes
  --merge           Add to existing memories (default)
  --replace         Clear all ron:* keys first, then import

Examples:
  memory-import.sh backups/ron-memory-2025-01-15.json
  memory-import.sh backup.json --dry-run
  memory-import.sh backup.json --replace
EOF
}

BACKUP_FILE=""
DRY_RUN=false
MODE="merge"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --merge) MODE="merge"; shift ;;
        --replace) MODE="replace"; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            if [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE="$1"
                shift
            else
                shift
            fi
            ;;
    esac
done

if [ -z "$BACKUP_FILE" ]; then
    usage
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Validate JSON format
if ! python3 -c "import sys, json; json.load(open('$BACKUP_FILE'))" 2>/dev/null; then
    echo "❌ Invalid JSON format in $BACKUP_FILE"
    exit 1
fi

echo "📥 Importing memories from $BACKUP_FILE"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN — Preview of what would be imported:"
    echo ""
fi

if [ "$MODE" = "replace" ] && [ "$DRY_RUN" = false ]; then
    echo "⚠️  Replace mode: Clearing all ron:* keys first..."
    
    # Get all keys to delete
    KEYS_JSON=$(curl -s "$URL/keys/ron:*" -H "Authorization: Bearer $TOKEN")
    KEYS=$(echo "$KEYS_JSON" | python3 -c "
import sys, json
keys = json.loads(sys.stdin.read()).get('result', [])
for k in keys:
    print(k)
" 2>/dev/null || echo "")
    
    deleted=0
    while IFS= read -r key; do
        [ -z "$key" ] && continue
        curl -s -X DELETE "$URL/del/$key" -H "Authorization: Bearer $TOKEN" >/dev/null 2>&1
        deleted=$((deleted + 1))
    done <<< "$KEYS"
    
    echo "✅ Deleted $deleted existing keys"
    echo ""
fi

# Parse and import entries
entries=$(python3 -c "
import sys, json
data = json.load(open('$BACKUP_FILE'))
if not isinstance(data, list):
    print('[]')
    sys.exit(1)
print(json.dumps(data))
" 2>/dev/null)

if [ -z "$entries" ] || [ "$entries" = "[]" ]; then
    echo "No entries found in backup file."
    exit 0
fi

count=0
imported=0

python3 << PYEOF
import sys, json

data = json.load(open('$BACKUP_FILE'))

for entry in data:
    key = entry.get('key', '')
    value = entry.get('value', '')
    timestamp = entry.get('timestamp', '')
    
    if not key:
        continue
    
    count += 1
    
    if '$DRY_RUN' == 'true':
        print(f"  [{count}] Would import: {key}")
        if len(value) > 100:
            print(f"       Value: {value[:100]}...")
        else:
            print(f"       Value: {value}")
        if timestamp:
            print(f"       Timestamp: {timestamp}")
        print()
    else:
        # Import to Redis
        import subprocess
        
        redis_key = key if key.startswith('ron:') else f"ron:{key}"
        
        payload = json.dumps({"value": value, "timestamp": timestamp or ""})
        
        cmd = [
            'curl', '-s', '-X', 'POST',
            f'$URL/set/{redis_key}',
            '-H', 'Content-Type: application/json',
            '-H', 'Authorization: Bearer $TOKEN',
            '-d', payload
        ]
        
        result = subprocess.run(cmd, capture_output=True)
        
        if result.returncode == 0:
            imported += 1
        else:
            print(f"  ❌ Failed to import: {key}", file=sys.stderr)

print(f"Processed {count} entries.", file=sys.stderr)
PYEOF

echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN complete — $count entries would be imported"
    echo "   Run without --dry-run to actually import"
else
    echo "✅ Successfully imported $imported of $count entries"
fi