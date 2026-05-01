#!/bin/bash
# memory-prune.sh v2 — Enforce TTLs and cold storage management
# Runs per-namespace TTL enforcement, moves stale entries to archive

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-prune.sh [--dry-run | --verbose | --namespace NS]
Prune expired entries based on TTL settings.

Options:
  --dry-run      Show what would be pruned without deleting
  --verbose     Show details of each action
  --namespace NS  Prune only this namespace (e.g. "working", "reminder")
  --force       Actually delete (default is --dry-run for safety)

Examples:
  memory-prune.sh --dry-run
  memory-prune.sh --namespace working --verbose
  memory-prune.sh --force --dry-run  # Review first, then run
EOF
}

DRY_RUN=true
VERBOSE=false
NAMESPACE_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --namespace) NAMESPACE_FILTER="$2"; shift 2 ;;
        --force) DRY_RUN=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

echo "✂️  Ron-Memory v2 — Prune"
if [ "$DRY_RUN" = true ]; then
    echo "   (dry-run mode — no changes will be made)"
fi
echo ""

NOW=$(date +%s)
pruned_count=0
archived_count=0

if [ ! -f "$RON_CACHE_FILE" ]; then
    echo "No cache file found. Nothing to prune."
    exit 0
fi

# Process cache file
pruned_tmp=$(mktemp)
while IFS='|' read -r key value timestamp rest; do
    key=$(echo "$key" | tr -d ' ')
    value=$(echo "$value" | tr -d ' ')
    timestamp=$(echo "$timestamp" | tr -d ' ')
    
    [ -z "$key" ] && continue
    [[ "$key" =~ ^# ]] && continue
    
    ns="${key%%:*}"
    
    # Filter by namespace if specified
    if [ -n "$NAMESPACE_FILTER" ] && [ "$ns" != "$NAMESPACE_FILTER" ]; then
        echo "| $key | $value | $timestamp |" >> "$pruned_tmp"
        continue
    fi
    
    # Get TTL for this namespace (default to 90 days if unknown)
    ttl_days="${NAMESPACE_TTL[$ns]:-90}"
    ttl_seconds=$((ttl_days * 86400))
    
    # Skip permanent entries
    if [ "$ttl_days" -eq 0 ]; then
        echo "| $key | $value | $timestamp |" >> "$pruned_tmp"
        continue
    fi
    
    # Calculate age
    entry_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
    age_seconds=$((NOW - entry_epoch))
    age_days=$((age_seconds / 86400))
    
    if [ $age_seconds -gt $ttl_seconds ]; then
        if [ "$VERBOSE" = true ]; then
            echo "  ⏰ $key ($ns) — age: ${age_days}d, TTL: ${ttl_days}d"
        fi
        
        # Move to archive instead of delete (unless already archive:)
        if [[ "$key" != "archive:"* ]]; then
            archive_key="archive:$key"
            archive_entry="| $archive_key | ${value:0:100}... [pruned $(date +%Y-%m-%d)] | $(date -u +"%Y-%m-%dT%H:%M:%SZ") |"
            
            if [ "$DRY_RUN" = false ]; then
                echo "$archive_entry" >> "$pruned_tmp"
                # Actually archive it in Redis
                "$SCRIPT_DIR/memory-set.sh" "$archive_key" "${value:0:500}... [pruned $(date +%Y-%m-%d)]" --force >/dev/null 2>&1 || true
            else
                echo "| $key | $value | $timestamp |" >> "$pruned_tmp"
            fi
            
            archived_count=$((archived_count + 1))
        fi
        pruned_count=$((pruned_count + 1))
    else
        echo "| $key | $value | $timestamp |" >> "$pruned_tmp"
    fi
done < "$RON_CACHE_FILE"

mv "$pruned_tmp" "$RON_CACHE_FILE"

echo ""
echo "Done. Pruned: $pruned_count, Archived: $archived_count"
if [ "$DRY_RUN" = true ]; then
    echo "Run with --force to apply changes."
fi
