#!/bin/bash
# memory-migrate-v2-to-v3.sh
# Migrates Ron-Memory from v2 format to v3 format
# 
# v2 keys: flat format (user_name, family:freddie:name)
# v3 keys: namespaced format (user:dale:name, family:freddie:name)
#
# Usage: ./memory-migrate-v2-to-v3.sh [--dry-run] [--force]
#   --dry-run  Show what would be migrated without making changes
#   --force    Actually write changes (required for actual migration)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--force]"
            echo "  --dry-run  Preview migrations without writing"
            echo "  --force    Actually perform the migration"
            exit 0
            ;;
        *) shift ;;
    esac
done

if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
    echo "ERROR: Use --dry-run to preview or --force to migrate"
    exit 1
fi

CACHE_FILE="$RON_CACHE_DIR/ron-memory.md"
BACKUP_FILE="$RON_CACHE_DIR/ron-memory.md.v2-backup-$(date +%Y%m%d%H%M%S)"

echo "============================================"
echo "Ron-Memory v2 → v3 Migration"
echo "============================================"
echo ""

# Check cache exists
if [ ! -f "$CACHE_FILE" ]; then
    echo "ERROR: Cache file not found at $CACHE_FILE"
    echo "Nothing to migrate."
    exit 1
fi

# Counters
total=0
migrated=0
skipped=0
errors=0

# Migration rules: v2 key → v3 key
# Format: "OLD_KEY_PREFIX|OLD_KEY_PATTERN|NEW_KEY"
# Pattern can be * for wildcard

declare -a MIGRATIONS=(
    # v2 → v3 namespace changes
    "user_name|user_name|user:dale:name"
    "user_preference|user:preference:|pref:"
    "user_pref|user:pref:|pref:"
    
    # Move vehicles under user namespace (optional - comment out to keep flat)
    # "vehicle|vehicle:|user:dale:vehicle:"
    
    # Stories namespace (v2 didn't have this, but migrate any matching patterns)
    # (none expected in v2)
)

echo "Scanning cache file: $CACHE_FILE"
echo ""

# Process each line
while IFS='|' read -r _ key value timestamp _; do
    # Skip empty/comment lines
    [ -z "$key" ] && continue
    [[ "$key" =~ ^# ]] && continue
    [[ "$key" =~ ^-$ ]] && continue  # Skip table separator lines
    
    # Clean whitespace
    key=$(echo "$key" | tr -d ' ')
    value=$(echo "$value" | tr -d ' ')
    timestamp=$(echo "$timestamp" | tr -d ' ')
    
    # Skip if key still empty after cleaning
    [ -z "$key" ] && continue
    
    total=$((total + 1))
    new_key="$key"
    was_migrated=false
    
    # Apply migrations
    if [ "$key" = "user_name" ]; then
        new_key="user:dale:name"
        was_migrated=true
    elif [[ "$key" =~ ^user:preference: ]]; then
        new_key="${key/user:preference:/pref:}"
        was_migrated=true
    elif [[ "$key" =~ ^user:pref: ]]; then
        new_key="${key/user:pref:/pref:}"
        was_migrated=true
    fi
    
    # Check if it's already v3 format (skip if already migrated or never needed migration)
    if [[ "$key" =~ ^user:dale: ]] || \
       [[ "$key" =~ ^family: ]] || \
       [[ "$key" =~ ^story: ]] || \
       [[ "$key" =~ ^contact: ]] || \
       [[ "$key" =~ ^project: ]] || \
       [[ "$key" =~ ^vehicle: ]] || \
       [[ "$key" =~ ^pref: ]] || \
       [[ "$key" =~ ^reinforce: ]] || \
       [[ "$key" =~ ^health: ]] || \
       [[ "$key" =~ ^reminder: ]] || \
       [[ "$key" =~ ^archive: ]]; then
        # Already v3 format or correct namespace
        if [ "$was_migrated" = false ]; then
            skipped=$((skipped + 1))
            continue
        fi
    fi
    
    if [ "$was_migrated" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [MIGRATE] $key → $new_key"
            echo "           value: $value"
        else
            # Write to Redis
            result=$(curl -s -X SET "$UPSTASH_REDIS_URL" \
                -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "[\"$new_key\", \"$value\"]")
            
            if echo "$result" | grep -q '"OK"'; then
                echo "  [MIGRATED] $key → $new_key ✓"
                migrated=$((migrated + 1))
            else
                echo "  [ERROR] $key → $new_key (Redis write failed)"
                errors=$((errors + 1))
            fi
        fi
    else
        skipped=$((skipped + 1))
    fi
done < "$CACHE_FILE"

echo ""
echo "============================================"
echo "Migration Summary"
echo "============================================"
echo "Total entries scanned:  $total"
echo "Migrated:                $migrated"
echo "Skipped (already v3):   $skipped"
echo "Errors:                  $errors"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "↑ This was a DRY RUN. No changes written."
    echo "  Run with --force to actually migrate."
else
    echo "✓ Migration complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify: ./scripts/memory-get.sh user:dale:name"
    echo "  2. Sync:   ./scripts/memory-sync.sh"
    echo "  3. Check:  ./scripts/memory-list.sh --stats"
fi