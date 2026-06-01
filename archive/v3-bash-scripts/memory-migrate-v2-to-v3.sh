#!/bin/bash
# memory-migrate-v2-to-v3.sh
# Migrates Ron-Memory from v2 format to v3 format
# 
# v2 keys: flat format (user_name, family:sam:name)
# v3 keys: namespaced format (user:acasey:name, family:sam:name)
#
# After migration completes, sets flag key: ron:migration:v2to:v3:done
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

if [ -z "$UPSTASH_REDIS_URL" ] || [ -z "$UPSTASH_REDIS_TOKEN" ]; then
    echo "ERROR: Redis credentials not found."
    echo "Set UPSTASH_REDIS_URL and UPSTASH_REDIS_TOKEN in config.sh or .env.ron-memory"
    exit 1
fi

# Migration flag key - set after successful migration
MIGRATION_FLAG_KEY="ron:migration:v2to:v3:done"

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
    "user_name|user_name|user:acasey:name"
    "user_preference|user:preference:|pref:"
    "user_pref|user:pref:|pref:"
    
    # Move vehicles under user namespace (optional - comment out to keep flat)
    # "vehicle|vehicle:|user:acasey:vehicle:"
    
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
    [[ "$key" =~ ^|- ]] && continue  # Skip separator lines
    
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
        new_key="user:acasey:name"
        was_migrated=true
    elif [[ "$key" =~ ^user:preference: ]]; then
        new_key="${key/user:preference:/pref:}"
        was_migrated=true
    elif [[ "$key" =~ ^user:pref: ]]; then
        new_key="${key/user:pref:/pref:}"
        was_migrated=true
    fi
    
    # Check if already v3 format (skip if already migrated or correct namespace)
    if [[ "$key" =~ ^user:acasey: ]] || \
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
echo "Skipped (already v3):   $skipped
echo "Errors:                  $errors"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "↑ This was a DRY RUN. No changes written."
    echo "  Run with --force to actually migrate."
else
    if [ $errors -eq 0 ] && [ $migrated -gt 0 ]; then
        # Set migration flag
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        FLAG_RESULT=$(curl -s -X POST "$UPSTASH_REDIS_URL/set/$MIGRATION_FLAG_KEY" \
            -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"value\":\"done\",\"timestamp\":\"$TIMESTAMP\"}")
        
        if echo "$FLAG_RESULT" | grep -q '"OK"'; then
            echo "✓ Migration complete!"
            echo "✓ Migration flag set: $MIGRATION_FLAG_KEY"
        else
            echo "✓ Migration complete (WARNING: Could not set migration flag)"
        fi
    else
        echo "Migration complete with errors - not setting flag."
        echo "Fix errors and re-run to complete migration."
    fi
    
    echo ""
    echo "Next steps:"
    echo "  1. Verify: ./scripts/memory-get.sh user:acasey:name"
    echo "  2. Sync:   ./scripts/memory-sync.sh"
    echo "  3. Check:  ./scripts/memory-healthcheck.sh
fi