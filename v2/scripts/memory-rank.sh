#!/bin/bash
# memory-rank.sh v2 — Attention-based retrieval
# Returns top N most relevant memories given a task context
# Ranks by: freshness, access frequency, namespace relevance to task

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-rank.sh <task_context> [--limit N] [--budget tokens]
Rank and return the most relevant memories for a given task context.

Options:
  --limit N     Maximum number of entries to return (default: $RANK_MAX_ENTRIES)
  --budget N    Token budget for retrieval (default: $RANK_TOKEN_BUDGET)
  --namespaces  Comma-separated namespaces to filter by (e.g. "project,vehicle,family")

Examples:
  memory-rank.sh "working on heyron documentation"
  memory-rank.sh "family birthday" --limit 5
  memory-rank.sh "coding task" --namespaces project,career
EOF
}

TASK=""
LIMIT=$RANK_MAX_ENTRIES
BUDGET=$RANK_TOKEN_BUDGET
NAMESPACES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --limit) LIMIT="$2"; shift 2 ;;
        --budget) BUDGET="$2"; shift 2 ;;
        --namespaces) NAMESPACES="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) TASK="$1"; shift ;;
    esac
done

if [ -z "$TASK" ]; then
    usage
    exit 1
fi

# Keywords for namespace relevance scoring
declare -A CONTEXT_KEYWORDS=(
    ["project"]="project code feature build debug test deploy"
    ["vehicle"]="car drive travel commute vehicle bmw tesla"
    ["family"]="wife husband kids children family son daughter birthday"
    ["career"]="work job career company promotion office meeting"
    ["pref"]="prefer favorite colour color like dislike"
    ["service"]="account login subscription service"
    ["book"]="book read read finished chapter"
    ["agent"]="agent devops techsupport dave deployment"
    ["goal"]="goal target milestone progress achieve"
)

# Score a single entry
score_entry() {
    local key="$1"
    local value="$2"
    local timestamp="$3"
    
    local score=0
    
    # Extract namespace
    local ns="${key%%:*}"
    
    # Freshness score (newer = higher, max 30 days = full score)
    local age_seconds=$(($(date +%s) - $(date -d "$timestamp" +%s 2>/dev/null || echo 0)))
    local age_days=$((age_seconds / 86400))
    if [ $age_days -lt 30 ]; then
        score=$((score + (30 - age_days)))
    fi
    
    # Namespace relevance to task
    if [ -n "$NAMESPACES" ]; then
        # Filter by requested namespaces
        local found=false
        IFS=',' read -ra NS_FILTER <<< "$NAMESPACES"
        for ns_filter in "${NS_FILTER[@]}"; do
            if [ "$ns" = "$ns_filter" ]; then
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            echo "0"
            return
        fi
    else
        # Score by context match
        local keywords="${CONTEXT_KEYWORDS[$ns]}"
        if [ -n "$keywords" ]; then
            local kw_score=0
            for kw in $keywords; do
                if echo "$TASK" | grep -qi "$kw"; then
                    kw_score=$((kw_score + 5))
                fi
            done
            score=$((score + kw_score))
        fi
    fi
    
    # Long-term memory bonus (permanent namespaces rarely change)
    local ttl="${NAMESPACE_TTL[$ns]}"
    if [ "$ttl" = "0" ]; then
        score=$((score + 10))
    fi
    
    echo "$score"
}

# Score and sort all entries
ranked_output=""
total_chars=0

if [ -f "$RON_CACHE_FILE" ]; then
    while IFS='|' read -r key value timestamp rest; do
        key=$(echo "$key" | tr -d ' ')
        value=$(echo "$value" | tr -d ' ')
        timestamp=$(echo "$timestamp" | tr -d ' ')
        
        [ -z "$key" ] && continue
        [[ "$key" =~ ^# ]] && continue
        
        score=$(score_entry "$key" "$value" "$timestamp")
        
        # Collect all entries with scores
        ranked_output="$ranked_output$score|$key|$value|$timestamp\n"
    done < "$RON_CACHE_FILE"
fi

# Sort by score descending, take top N, within budget
echo -e "$ranked_output" | sort -t'|' -k1 -rn | head -n "$LIMIT" | while IFS='|' read -r score key value timestamp; do
    # Rough token estimate: ~4 chars per token
    entry_chars=$((${#key} + ${#value} + 50))  # +50 for formatting
    entry_tokens=$((entry_chars / 4))
    
    if [ $total_chars -lt $((BUDGET * 4)) ]; then
        echo "[$score] $key = $value (updated: $timestamp)"
        total_chars=$((total_chars + entry_chars))
    fi
done
