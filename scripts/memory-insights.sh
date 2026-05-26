#!/bin/bash
# memory-insights.sh - Analyze memory corpus and produce insights
# Analyzes: most accessed topics, stale entries, orphans, consolidation suggestions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-insights.sh [options]
Analyze the memory corpus and produce insights about usage patterns,
stale entries, orphaned memories, and consolidation opportunities.

Options:
  --stale-threshold N  Days before entry is considered stale (default: 14)
  --orphans           Only show orphan entries (no references to them)
  --consolidate      Show consolidation suggestions (episodic → semantic)
  --top N             Show top N most accessed (default: 10)
  --summary           Short summary only
  -h, --help          Show this help

Examples:
  memory-insights.sh
  memory-insights.sh --stale-threshold 30
  memory-insights.sh --consolidate
  memory-insights.sh --top 5 --summary
EOF
}

STALE_THRESHOLD=14
SHOW_ORPHANS=false
SHOW_CONSOLIDATE=false
TOP_N=10
SUMMARY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --stale-threshold) STALE_THRESHOLD="$2"; shift 2 ;;
        --orphans) SHOW_ORPHANS=true; shift ;;
        --consolidate) SHOW_CONSOLIDATE=true; shift ;;
        --top) TOP_N="$2"; shift 2 ;;
        --summary) SUMMARY_ONLY=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Memory Insights Analysis ===${NC}"

NOW=$(date +%s)
CACHE_FILE="$RON_CACHE_FILE"

if [ ! -f "$CACHE_FILE" ]; then
    echo "❌ Cache file not found: $CACHE_FILE"
    exit 1
fi

# ============================================
# Extract entries from cache
# ============================================
TMP_ALL=$(mktemp)
TMP_STALE=$(mktemp)
TMP_BY_NAMESPACE=$(mktemp)
TMP_EPISODIC=$(mktemp)

grep "^| " "$CACHE_FILE" | grep -v "^| #" > "$TMP_ALL"

if [ ! -s "$TMP_ALL" ]; then
    echo "No entries found in cache."
    rm -f "$TMP_ALL" "$TMP_STALE" "$TMP_BY_NAMESPACE" "$TMP_EPISODIC"
    exit 0
fi

# ============================================
# 1. STALE ENTRIES ANALYSIS
# ============================================
echo ""
echo -e "${YELLOW}--- Stale Entries (>$STALE_THRESHOLD days without update) ---${NC}"

stale_count=0
while IFS= read -r line; do
    key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
    value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
    timestamp=$(echo "$line" | cut -d'|' -f4 | tr -d ' ')
    
    [ -z "$timestamp" ] && continue
    [[ "$key" =~ ^# ]] && continue
    
    ts_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
    [ "$ts_epoch" -eq 0 ] && continue
    
    age_seconds=$((NOW - ts_epoch))
    age_days=$((age_seconds / 86400))
    
    if [ $age_days -gt $STALE_THRESHOLD ]; then
        ns="${key%%:*}"
        echo "| $key | ${age_days}d old |" >> "$TMP_STALE"
        ((stale_count++))
    fi
    
    # Track episodic for consolidation
    if [ "$ns" = "episodic" ]; then
        echo "$age_days|$key|$value|$timestamp" >> "$TMP_EPISODIC"
    fi
done < "$TMP_ALL"

if [ -s "$TMP_STALE" ]; then
    cat "$TMP_STALE" | head -20
    stale_total=$(wc -l < "$TMP_STALE")
    echo ""
    echo "Total stale entries: $stale_total"
else
    echo "No stale entries found."
fi

# ============================================
# 2. MOST ACCESSED (via reinforce counts)
# ============================================
echo ""
echo -e "${YELLOW}--- Most Accessed Memories ---${NC}"

# Count entries by namespace
declare -A ns_count
declare -A ns_total_importance
while IFS= read -r line; do
    key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
    value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
    
    [ -z "$key" ] && continue
    [[ "$key" =~ ^# ]] && continue
    
    ns="${key%%:*}"
    ((ns_count[$ns]++))
    
    # Extract importance from metadata if present
    importance=$(echo "$line" | grep -o 'importance=[0-9]*' | head -1 | cut -d'=' -f2)
    [ -z "$importance" ] && importance=50
    ns_total_importance[$ns]=$((ns_total_importance[$ns] + importance))
done < "$TMP_ALL"

echo "Top namespaces by entry count:"
for ns in "${!ns_count[@]}"; do
    count=${ns_count[$ns]}
    importance=${ns_total_importance[$ns]:-0}
    echo "  $ns: $count entries (avg importance: $((importance / count)))"
done | sort -t':' -k2 -rn | head -10

# ============================================
# 3. ORPHAN ENTRIES (no cross-references)
# ============================================
if [ "$SHOW_ORPHANS" = true ]; then
    echo ""
    echo -e "${YELLOW}--- Orphan Entries (no references from other entries) ---${NC}"
    
    orphans=0
    while IFS= read -r line; do
        key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
        
        [ -z "$key" ] && continue
        [[ "$key" =~ ^# ]] && continue
        
        # Check if any other entry references this key
        key_short="${key#episodic:}"
        key_short="${key_short#semantic:}"
        key_short="${key_short#anchored:}"
        key_short="${key_short#reminder:}"
        key_short="${key_short#working:}"
        
        # Search for references to this key in other values
        if ! grep -v "^| $key |" "$TMP_ALL" | grep -q "$key_short"; then
            echo "| $key | $value |"
            ((orphans++))
        fi
    done < "$TMP_ALL"
    
    echo ""
    echo "Total orphan entries: $orphans"
fi

# ============================================
# 4. CONSOLIDATION SUGGESTIONS
# ============================================
if [ "$SHOW_CONSOLIDATE" = true ]; then
    echo ""
    echo -e "${YELLOW}--- Consolidation Suggestions (episodic → semantic) ---${NC}"
    
    if [ -s "$TMP_EPISODIC" ]; then
        echo "Old episodic entries that might deserve semantic promotion:"
        while IFS='|' read -r age_days key value timestamp; do
            # 30+ days old episodic might be worth promoting
            if [ $age_days -gt 30 ]; then
                key_short="${key#episodic:}"
                echo "| $key | ${age_days}d old | Consider promoting to semantic"
            fi
        done < "$TMP_EPISODIC" | sort -t'|' -k3 -rn | head -10
    else
        echo "No episodic entries found."
    fi
fi

# ============================================
# 5. SUMMARY
# ============================================
if [ "$SUMMARY_ONLY" = true ]; then
    echo ""
    echo -e "${BLUE}=== Summary ===${NC}"
    total_entries=$(wc -l < "$TMP_ALL")
    echo "Total entries: $total_entries"
    echo "Stale entries (>${STALE_THRESHOLD}d): $stale_count"
    echo ""
    echo "Top namespaces:"
    for ns in "${!ns_count[@]}"; do
        count=${ns_count[$ns]}
        echo "  $ns: $count"
    done | sort -t':' -k2 -rn | head -5
fi

# Cleanup
rm -f "$TMP_ALL" "$TMP_STALE" "$TMP_BY_NAMESPACE" "$TMP_EPISODIC"

echo ""
echo -e "${BLUE}=== Analysis Complete ===${NC}"
