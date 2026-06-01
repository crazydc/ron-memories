#!/bin/bash
# memory-consolidate.sh — Summarize old episodic memories into semantic
# Like human sleep: condense episodic → semantic
# Run weekly via cron

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-consolidate.sh [--dry-run] [--days N]

Consolidate old episodic memories into semantic summaries.
This is like human memory consolidation during sleep.

Options:
  --dry-run    Show what would be consolidated without making changes
  --days N     Consider memories older than N days (default: 14)
  --help       Show this help

Examples:
  memory-consolidate.sh           # Run consolidation
  memory-consolidate.sh --dry-run # Preview what would change
EOF
}

DRY_RUN=false
DAYS=14

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --days) DAYS="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

CUTOFF_DATE=$(date -d "$DAYS days ago" +%Y-%m-%d 2>/dev/null || date -v-${DAYS}d +%Y-%m-%d)
CUTOFF_EPOCH=$(date -d "$CUTOFF_DATE" +%s 2>/dev/null || echo 0)

echo "📦 Memory Consolidation"
echo "======================="
echo "Cutoff: $CUTOFF_DATE ($DAYS days old)"
echo "Mode: $(if [ "$DRY_RUN" = true ]; then echo "DRY RUN (no changes)"; else echo "LIVE"; fi)"
echo ""

# Find episodic keys older than cutoff
OLD_ENTRIES=$(grep "^| " "$RON_CACHE_FILE" 2>/dev/null | while IFS='|' read -r key value timestamp rest; do
    key=$(echo "$key" | tr -d ' ')
    timestamp=$(echo "$timestamp" | tr -d ' ')
    
    # Only look at episodic keys
    [[ "$key" =~ ^episodic: ]] && continue
    [[ "$key" =~ ^reminder: ]] && continue
    
    [ -z "$timestamp" ] && continue
    
    ts_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
    if [ "$ts_epoch" -gt 0 ] && [ "$ts_epoch" -lt "$CUTOFF_EPOCH" ]; then
        echo "$key|$value|$timestamp"
    fi
done)

if [ -z "$OLD_ENTRIES" ]; then
    echo "No old episodic memories found. Nothing to consolidate."
    exit 0
fi

# Group by topic (simple version - extract first part of key after episodic:)
echo "Found entries to consolidate:"
echo ""

declare -A grouped
while IFS='|' read -r key value timestamp; do
    # Extract topic from key (e.g., episodic:2026_05_24_trip → trip)
    topic=$(echo "$key" | sed 's/^episodic://' | sed 's/^[0-9_]*_//')
    if [ -z "$topic" ]; then topic="misc"; fi
    
    grouped["$topic"]="${grouped[$topic]:-}${grouped[$topic]:+ | }$value"
    
    echo "  - $key: $value"
done <<< "$OLD_ENTRIES"

echo ""
echo "Would create semantic summaries:"
for topic in "${!grouped[@]}"; do
    summary="Consolidated from episodic: ${grouped[$topic]}"
    echo "  semantic:summary:$topic = $summary"
done

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "(DRY RUN - no changes made)"
else
    echo ""
    read -p "Proceed with consolidation? (y/N) " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        for topic in "${!grouped[@]}"; do
            summary="Consolidated from episodic: ${grouped[$topic]}"
            bash "$SCRIPT_DIR/memory-set.sh" "semantic:summary:$topic" "$summary" --importance 30
        done
        echo ""
        echo "✅ Consolidation complete"
    else
        echo "Cancelled."
    fi
fi