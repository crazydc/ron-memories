#!/bin/bash
# memory-list.sh v2 — List all memories with namespace filtering and stats

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-list.sh [--namespace NS] [--summarize] [--stats]
List all memories from local cache.

Options:
  --namespace NS   Filter by namespace (e.g. "family", "vehicle")
  --summarize      Show summary stats per namespace
  --stats          Show storage statistics

Examples:
  memory-list.sh
  memory-list.sh --namespace family
  memory-list.sh --stats
EOF
}

NAMESPACE_FILTER=""
SUMMARIZE=false
STATS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace) NAMESPACE_FILTER="$2"; shift 2 ;;
        --summarize) SUMMARIZE=true; shift ;;
        --stats) STATS=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

echo "📋 Ron-Memory v2 — Memory List"
echo "=============================="
echo ""

if [ ! -f "$RON_CACHE_FILE" ]; then
    echo "No cache file found."
    exit 0
fi

# Stats mode
if [ "$STATS" = true ]; then
    total_entries=0
    total_chars=0
    declare -A ns_counts
    declare -A ns_chars
    
    while IFS='|' read -r key value timestamp rest; do
        key=$(echo "$key" | tr -d ' ')
        value=$(echo "$value" | tr -d ' ')
        [ -z "$key" ] && continue
        [[ "$key" =~ ^# ]] && continue
        
        ns="${key%%:*}"
        ns_counts[$ns]=$((${ns_counts[$ns]:-0} + 1))
        ns_chars[$ns]=$((${ns_chars[$ns]:-0} + ${#value}))
        total_entries=$((total_entries + 1))
        total_chars=$((total_chars + ${#value}))
    done < "$RON_CACHE_FILE"
    
    echo "Total entries: $total_entries"
    echo "Total data: ~${total_chars} chars"
    echo ""
    echo "By namespace:"
    for ns in "${!ns_counts[@]}"; do
        echo "  $ns: ${ns_counts[$ns]} entries (~${ns_chars[$ns]} chars)"
    done | sort
    echo ""
    echo "TTL settings:"
    for ns in "${!NAMESPACE_TTL[@]}"; do
        ttl="${NAMESPACE_TTL[$ns]}"
        if [ "$ttl" = "0" ]; then
            echo "  $ns: permanent"
        else
            echo "  $ns: ${ttl} days"
        fi
    done | sort
    exit 0
fi

# Summarize mode
if [ "$SUMMARIZE" = true ]; then
    declare -A ns_entries
    while IFS='|' read -r key value timestamp rest; do
        key=$(echo "$key" | tr -d ' ')
        [ -z "$key" ] && continue
        [[ "$key" =~ ^# ]] && continue
        
        ns="${key%%:*}"
        ns_entries[$ns]=$((${ns_entries[$ns]:-0} + 1))
    done < "$RON_CACHE_FILE"
    
    echo "Entries by namespace:"
    for ns in "${!ns_entries[@]}"; do
        count="${ns_entries[$ns]}"
        echo "  $ns: $count entries"
    done | sort -k2 -rn
    exit 0
fi

# Normal list
entry_count=0
while IFS='|' read -r key value timestamp rest; do
    key=$(echo "$key" | tr -d ' ')
    value=$(echo "$value" | tr -d ' ')
    timestamp=$(echo "$timestamp" | tr -d ' ')
    
    [ -z "$key" ] && continue
    [[ "$key" =~ ^# ]] && continue
    
    ns="${key%%:*}"
    
    # Filter by namespace
    if [ -n "$NAMESPACE_FILTER" ] && [ "$ns" != "$NAMESPACE_FILTER" ]; then
        continue
    fi
    
    echo "$key = $value"
    echo "   Updated: $timestamp"
    echo ""
    entry_count=$((entry_count + 1))
done < "$RON_CACHE_FILE"

echo "($entry_count entries shown)"
