#!/bin/bash
# memory-rank.sh v2 — Attention-based retrieval
# Returns top N most relevant memories given a task context
# Ranks by: freshness, access frequency, namespace relevance to task

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

NOW=$(date +%s)
TASK_LC=$(echo "$TASK" | tr '[:upper:]' '[:lower:]')

# Extract only actual data lines (pipe-delimited with | at start)
grep "^| " "$RON_CACHE_FILE" > /tmp/memory_rank_input.txt

# Score and output results
results=""
total_chars=0

while IFS= read -r line; do
    key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
    value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
    timestamp=$(echo "$line" | cut -d'|' -f4 | tr -d ' ')
    
    [ -z "$key" ] && continue
    [[ "$key" =~ ^# ]] && continue
    
    ns="${key%%:*}"
    
    if [ -n "$timestamp" ]; then
        ts_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
        if [ "$ts_epoch" -gt 0 ]; then
            age_days=$(( (NOW - ts_epoch) / 86400 ))
            if [ $age_days -lt 30 ]; then
                freshness=$((30 - age_days))
            else
                freshness=0
            fi
        else
            freshness=0
        fi
    else
        freshness=0
    fi
    
    score=$freshness
    
    case "$ns" in
        family)
            for kw in family wife husband kids children son daughter birthday; do
                if echo "$TASK_LC" | grep -q "$kw"; then score=$((score + 5)); fi
            done
            score=$((score + 10))
            ;;
        vehicle)
            for kw in car vehicle drive bmw tesla commute; do
                if echo "$TASK_LC" | grep -q "$kw"; then score=$((score + 5)); fi
            done
            score=$((score + 10))
            ;;
        project)
            for kw in project code feature build debug test deploy; do
                if echo "$TASK_LC" | grep -q "$kw"; then score=$((score + 5)); fi
            done
            score=$((score + 10))
            ;;
        career)
            for kw in work job career company; do
                if echo "$TASK_LC" | grep -q "$kw"; then score=$((score + 5)); fi
            done
            score=$((score + 10))
            ;;
        user|contact|goal|book|agent)
            score=$((score + 10))
            ;;
    esac
    
    if [ -n "$NAMESPACES" ]; then
        found=0
        IFS=',' read -ra NS_FILTER <<< "$NAMESPACES"
        for ns_filter in "${NS_FILTER[@]}"; do
            if [ "$ns" = "$ns_filter" ]; then found=1; break; fi
        done
        if [ "$found" = 0 ]; then score=0; fi
    fi
    
    if [ "$score" -gt 0 ]; then
        entry_chars=$((${#key} + ${#value} + 50))
        if [ $total_chars -lt $((BUDGET * 4)) ]; then
            results="$results[$score] $key = $value (updated: $timestamp)"$'\n'
            total_chars=$((total_chars + entry_chars))
        fi
    fi
done < /tmp/memory_rank_input.txt

# Sort and display
echo -e "$results" | sort -t'[' -k2 -rn | head -n "$LIMIT"

rm -f /tmp/memory_rank_input.txt
