#!/bin/bash
# memory-export.sh v3 — Export all Redis memories to a JSON file
# Supports exporting to stdout for piping

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true

TOKEN="${UPSTASH_REDIS_TOKEN:-gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I4ZGRhYWU1MDc0OTc5YzA1YWMyYw}"
URL="${UPSTASH_REDIS_URL:-https://summary-hare-109926.upstash.io}"

usage() {
    cat << EOF
Usage: memory-export.sh [--output <path>] [--stdout] [--all]
Export all Redis memories to JSON.

Options:
  --output <path>   Output file path (default: exports/ron-memory-YYYY-MM-DD.json)
  --stdout          Write to stdout instead of file
  --all             Include all keys including reinforce:* (default: excludes reinforce:*)

Examples:
  memory-export.sh                       # Export to dated file in exports/
  memory-export.sh --stdout              # Pipe to another command
  memory-export.sh --output backup.json  # Custom output path
EOF
}

OUTPUT_FILE=""
USE_STDOUT=false
INCLUDE_REINFORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --stdout) USE_STDOUT=true; shift ;;
        --all) INCLUDE_REINFORCE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

# Default output file with date
if [ -z "$OUTPUT_FILE" ] && [ "$USE_STDOUT" = false ]; then
    DATE=$(date -u +"%Y-%m-%d")
    OUTPUT_DIR="$SCRIPT_DIR/../exports"
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="$OUTPUT_DIR/ron-memory-$DATE.json"
fi

echo "📤 Exporting memories from Redis..."

# Export using Python script
if [ "$USE_STDOUT" = true ]; then
    UPSTASH_REDIS_TOKEN="$TOKEN" UPSTASH_REDIS_URL="$URL" INCLUDE_REINFORCE="$INCLUDE_REINFORCE" \
        python3 "$SCRIPT_DIR/memory-export.py"
    echo "✅ Export complete (stdout)"
else
    # Capture output and write to file
    RESULT=$(UPSTASH_REDIS_TOKEN="$TOKEN" UPSTASH_REDIS_URL="$URL" INCLUDE_REINFORCE="$INCLUDE_REINFORCE" \
        python3 "$SCRIPT_DIR/memory-export.py" 2>&1)
    
    # Validate JSON before writing
    if echo "$RESULT" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        echo "$RESULT" > "$OUTPUT_FILE"
        count=$(echo "$RESULT" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")
        echo "✅ Exported $count entries to $OUTPUT_FILE"
    else
        echo "❌ Export failed - invalid JSON"
        echo "$RESULT"
        exit 1
    fi
fi