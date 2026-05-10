#!/bin/bash
# memory-audit.sh v2 — Audit memory for staleness and conflicts
# Flags: stale entries, conflicting updates, never-accessed keys

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-audit.sh [--stale | --conflicts | --never-accessed | --all]
Audit memory entries for issues.

Options:
  --stale            Show entries older than COLD_STORAGE_DAYS ($COLD_STORAGE_DAYS days)
  --conflicts        Show entries that were overwritten (exist in archive:)
  --never-accessed  Show entries never retrieved since save (needs access log)
  --all              Run all audits

Examples:
  memory-audit.sh --stale
  memory-audit.sh --all
EOF
}

MODE="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        --stale) MODE="stale"; shift ;;
        --conflicts) MODE="conflicts"; shift ;;
        --never-accessed) MODE="never-accessed"; shift ;;
        --all) MODE="all"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

echo "🔍 Ron-Memory v2 — Memory Audit"
echo "================================"
echo ""

# Track current timestamp for age calculations
NOW=$(date +%s)

# 1. Stale entries check
check_stale() {
    local count=0
    echo "📅 Stale Entries (older than $COLD_STORAGE_DAYS days):"
    echo ""
    
    if [ ! -f "$RON_CACHE_FILE" ]; then
        echo "  (no cache file found)"
        echo ""
        return
    fi
    
    while IFS='|' read -r key value timestamp rest; do
        key=$(echo "$key" | tr -d ' ')
        timestamp=$(echo "$timestamp" | tr -d ' ')
        
        [ -z "$key" ] && continue
        [[ "$key" =~ ^# ]] && continue
        [[ "$key" =~ ^archive: ]] && continue
        
        # Calculate age
        entry_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
        age_days=$(( (NOW - entry_epoch) / 86400 ))
        
        if [ $age_days -gt $COLD_STORAGE_DAYS ]; then
            echo "  ⚠️  $key"
            echo "      Value: ${value:0:60}${3:+...}"
            echo "      Age: $age_days days (last updated: $timestamp)"
            echo ""
            count=$((count + 1))
        fi
    done < "$RON_CACHE_FILE"
    
    if [ $count -eq 0 ]; then
        echo "  ✅ No stale entries found"
    fi
    echo ""
}

# 2. Conflict check (entries that have been archived due to overwrite)
check_conflicts() {
    local count=0
    echo "🔄 Conflicting/Archived Entries:"
    echo ""
    
    if [ ! -f "$RON_CACHE_FILE" ]; then
        echo "  (no cache file found)"
        echo ""
        return
    fi
    
    while IFS='|' read -r key value timestamp rest; do
        key=$(echo "$key" | tr -d ' ')
        [ -z "$key" ] && continue
        
        # Check if original key has an archive
        archive_key="archive:$key"
        archive_value=$(grep "^| $archive_key " "$RON_CACHE_FILE" 2>/dev/null | awk -F'|' '{gsub(/^ *| *$/, "", $3); print $3}')
        
        if [ -n "$archive_value" ]; then
            echo "  📦 $key was previously updated"
            echo "      Current: ${value:0:50}${4:+...}"
            echo "      Archived: ${archive_value:0:50}..."
            echo ""
            count=$((count + 1))
        fi
    done < "$RON_CACHE_FILE"
    
    if [ $count -eq 0 ]; then
        echo "  ✅ No archived conflicts found"
    fi
    echo ""
}

# 3. Never-accessed check (simplified - checks if key exists in cache but not in access log)
check_never_accessed() {
    echo "🔒 Never-Accessed Entries:"
    echo "  (requires access logging to be enabled)"
    echo "  To enable: export RON_TRACK_ACCESS=true"
    echo ""
    echo "  📝 Access tracking is not yet implemented in v2"
    echo "  Future: memory-get.sh will log access timestamps"
    echo "          memory-audit.sh --never-accessed will show unused entries"
    echo ""
}

# Run requested checks
case $MODE in
    stale) check_stale ;;
    conflicts) check_conflicts ;;
    never-accessed) check_never_accessed ;;
    all)
        check_stale
        check_conflicts
        check_never_accessed
        ;;
esac

echo "================================"
echo "Audit complete. Run with --help for more options."
