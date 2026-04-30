#!/bin/bash
# Ron Memory - Read from local cache

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ ! -f "$MEMORY_FILE" ]; then
    echo "No local cache found. Run 'memory-sync' first."
    exit 1
fi

# Output local file (skip header lines)
tail -n +6 "$MEMORY_FILE"