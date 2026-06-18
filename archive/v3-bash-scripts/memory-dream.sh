#!/bin/bash
# memory-dream.sh — Autonomous overnight memory processing
# Like human REM sleep: consolidate, enrich, identify gaps
# Run via cron at 2am daily: 0 2 * * * ...

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Redis credentials (same as other scripts)
TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'

# Dream state file
DREAM_STATE_FILE="$RON_CACHE_DIR/dream-state.json"
DREAM_STATS_FILE="$RON_CACHE_DIR/dream-stats.json"
DREAM_LOG_DIR="$RON_CACHE_DIR/dream-logs"
DREAM_LOG_FILE="$DREAM_LOG_DIR/current.log"

# Inhibit file (pause dream cycle)
INHIBIT_FILE="$RON_CACHE_DIR/dream-inhibit"

mkdir -p "$DREAM_LOG_DIR"

usage() {
    cat << EOF
Usage: memory-dream.sh <command> [options]

Autonomous overnight memory processing — consolidates episodic memories,
detects stale citations, enriches entity pages, and identifies gaps.

Commands:
  run [--dry-run] [--focus TOPIC]   Run dream cycle now
  status                            Show last run info and stats
  inhibit [--hours N]               Pause dream cycle for N hours (default: 8)
  allow                            Remove inhibit (resume dream cycle)
  trigger                          Run immediately (for testing)
  install-cron                      Install the 2am daily cron job

Cron setup:
  0 2 * * * /root/.openclaw/skills/ron-memory/scripts/memory-dream.sh run >> /root/.openclaw/workspace/logs/dream.log 2>&1

Examples:
  memory-dream.sh run              # Full dream cycle
  memory-dream.sh run --dry-run    # Preview changes only
  memory-dream.sh run --focus heyron  # Only process heyron-related memories
  memory-dream.sh status           # Check last run
  memory-dream.sh inhibit --hours 12  # Pause for 12 hours
EOF
}

# Log with timestamp (to both stdout and log file)
dream_log() {
    local msg="$1"
    local ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    echo "[$ts] $msg" >&2
    echo "[$ts] $msg" >> "$DREAM_LOG_FILE"
}

# Check if dream cycle is inhibited
is_inhibited() {
    if [ -f "$INHIBIT_FILE" ]; then
        local expiry=$(cat "$INHIBIT_FILE" 2>/dev/null | grep -v '^#' | head -1)
        if [ -n "$expiry" ] && [ "$expiry" -gt "$(date +%s)" ]; then
            return 0
        fi
    fi
    return 1
}

# Load or init dream state
load_dream_state() {
    if [ -f "$DREAM_STATE_FILE" ]; then
        cat "$DREAM_STATE_FILE"
    else
        printf '%s\n' \
            '{"last_run": null, "last_run_epoch": 0, "entries_consolidated": 0, "syntheses_updated": 0, "gaps_identified": 0, "citations_fixed": 0, "enrichments": 0}'
    fi
}

# Save dream state
save_dream_state() {
    printf '%s\n' "$1" > "$DREAM_STATE_FILE"
}

# Init stats file
init_stats() {
    if [ ! -f "$DREAM_STATS_FILE" ]; then
        printf '%s\n' '{"runs": [], "total_consolidated": 0, "total_runs": 0}' > "$DREAM_STATS_FILE"
    fi
}

# Update stats file - write clean JSON
update_stats() {
    local action="$1"
    local count="$2"
    
    init_stats
    
    local tmpfile=$(mktemp)
    cp "$DREAM_STATS_FILE" "$tmpfile"
    
    python3 - "$action" "$count" "$DREAM_STATS_FILE" << 'PYEOF'
import json, sys

action = sys.argv[1]
count = int(sys.argv[2])
stats_file = sys.argv[3]

with open(stats_file, 'r') as f:
    stats = json.load(f)

if action == 'run':
    ts = __import__('datetime').datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    stats.setdefault('runs', [])
    stats['runs'].insert(0, {
        'timestamp': ts,
        'consolidated': 0,
        'synth_updated': 0,
        'gaps': 0,
        'citations': 0,
        'enrichments': 0
    })
    stats['runs'] = stats['runs'][:30]
elif action == 'consolidated':
    if stats['runs']:
        stats['runs'][0]['consolidated'] = count
elif action == 'synth_updated':
    if stats['runs']:
        stats['runs'][0]['synth_updated'] = count
elif action == 'gaps':
    if stats['runs']:
        stats['runs'][0]['gaps'] = count
elif action == 'citations':
    if stats['runs']:
        stats['runs'][0]['citations'] = count
elif action == 'enrichments':
    if stats['runs']:
        stats['runs'][0]['enrichments'] = count

if action == 'consolidated':
    stats['total_consolidated'] = stats.get('total_consolidated', 0) + count
if action == 'run':
    stats['total_runs'] = stats.get('total_runs', 0) + 1

with open(stats_file, 'w') as f:
    json.dump(stats, f, indent=2)
PYEOF
}

# Get Redis value
redis_get() {
    local key="$1"
    curl -s "$URL/get/$key" -H "Authorization: Bearer $TOKEN" | \
        python3 -c "import sys,json; d=json.loads(sys.stdin.read()); r=d.get('result',{}); print(r.get('value','') if isinstance(r,dict) else (r if r else ''))" 2>/dev/null
}

# Set Redis value
redis_set() {
    local key="$1"
    local value="$2"
    local timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local payload="{\"value\": \"$(echo "$value" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))')\", \"timestamp\": \"$timestamp\"}"
    curl -s -X POST "$URL/set/$key" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$payload" >/dev/null 2>&1
}

# Extract topic from episodic key
extract_topic() {
    local key="$1"
    # episodic:2026_05_25_morning_context -> morning_context
    echo "$key" | sed 's/^episodic://' | sed 's/^[0-9_]*_//'
}

# Find episodic entries older than N days (returns to stdout, logs to dream log)
find_old_episodic() {
    local days="${1:-7}"
    local cutoff_epoch=$(date -d "$days days ago" +%s 2>/dev/null || date -v-"${days}"d +%s)
    
    if [ ! -f "$RON_CACHE_FILE" ]; then
        return
    fi
    
    while IFS='|' read -r key value timestamp rest; do
        key=$(echo "$key" | tr -d ' ')
        ts=$(echo "$timestamp" | tr -d ' ')
        
        [[ "$key" != episodic:* ]] && continue
        
        # Parse timestamp
        ts_epoch=$(date -d "$ts" +%s 2>/dev/null || echo 0)
        
        if [ "$ts_epoch" -gt 0 ] && [ "$ts_epoch" -lt "$cutoff_epoch" ]; then
            printf '%s|%s|%s' "$key" "$value" "$ts"
            printf '\n'
        fi
    done < "$RON_CACHE_FILE"
}

# Consolidate old episodic entries
do_consolidate() {
    local dry_run="${1:-false}"
    local focus_topic="${2:-}"
    local consolidated=0
    
    # Use a temp file to capture output cleanly
    local tmpfile=$(mktemp)
    find_old_episodic 7 > "$tmpfile"
    
    local linecount=$(wc -l < "$tmpfile")
    
    if [ "$linecount" -eq 0 ] || [ ! -s "$tmpfile" ]; then
        dream_log "No episodic entries older than 7 days. Nothing to consolidate."
        rm -f "$tmpfile"
        echo "0"
        return
    fi
    
    # Group by topic
    declare -A grouped
    
    while IFS='|' read -r key value timestamp; do
        [ -z "$key" ] && continue
        
        # Optional focus filter
        if [ -n "$focus_topic" ]; then
            if ! echo "$key" | grep -qi "$focus_topic"; then
                continue
            fi
        fi
        
        topic=$(extract_topic "$key")
        if [ -z "$topic" ]; then
            topic="misc"
        fi
        
        grouped["$topic"]="${grouped[$topic]:-}${grouped[$topic]:+|||NEWENTRY|||}$key|$value|$timestamp"
    done < "$tmpfile"
    
    rm -f "$tmpfile"
    
    # Create consolidated summaries
    for topic in "${!grouped[@]}"; do
        # Build consolidated text
        local entries_text=""
        local entry_count=0
        local sources_list=""
        
        IFS='|||NEWENTRY|||' read -ra entries <<< "${grouped[$topic]}"
        for entry in "${entries[@]}"; do
            IFS='|' read -r ek ev et <<< "$entry"
            [ -z "$ek" ] && continue
            
            entry_count=$((entry_count + 1))
            
            # Format date nicely
            local nice_date=$(date -d "$et" +'%b %d' 2>/dev/null || echo "$et")
            entries_text="${entries_text}${entries_text:+, }[${nice_date}] $ev"
            sources_list="${sources_list}${sources_list:+, }\"$ek\""
        done
        
        if [ "$entry_count" -eq 0 ]; then
            continue
        fi
        
        # Create semantic summary key
        local semantic_key="semantic:dream:${topic}"
        local summary="Dream consolidation from $entry_count episodic entries: $entries_text"
        
        if [ "$dry_run" = "true" ]; then
            dream_log "[DRY RUN] Would save: $semantic_key"
            dream_log "  Summary: $summary"
        else
            # Save consolidated summary using memory-set.sh
            bash "$SCRIPT_DIR/memory-set.sh" "$semantic_key" "$summary" --tier semantic --importance 40 --stale-ok >/dev/null 2>&1
            
            # Track citations
            redis_set "ron:citations:$semantic_key" "{\"sources\": [${sources_list}]}"
            
            dream_log "CONSOLIDATED: $topic ($entry_count entries) -> $semantic_key"
        fi
        
        consolidated=$((consolidated + entry_count))
    done
    
    echo "$consolidated"
}

# Check for stale citations
do_check_citations() {
    local fixed=0
    
    # Get all citation keys from Redis
    local citation_keys=$(curl -s "$URL/keys/ron:citations:*" -H "Authorization: Bearer $TOKEN" | \
        python3 -c "import sys,json; keys=json.loads(sys.stdin.read()).get('result',[]); print('\n'.join(keys))" 2>/dev/null)
    
    while IFS= read -r cite_key; do
        [ -z "$cite_key" ] && continue
        local short_key=$(echo "$cite_key" | sed 's/^ron://')
        
        # Get citations for this key
        local citations_json=$(redis_get "ron:$short_key")
        [ -z "$citations_json" ] && continue
        
        # Parse source keys
        local source_keys=$(echo "$citations_json" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print('\n'.join(d.get('sources',[])))" 2>/dev/null)
        
        # Check if any source has been updated after this entry
        local current_ts=$(redis_get "ron:reinforce:last:$short_key")
        [ -z "$current_ts" ] && continue
        
        for source in $source_keys; do
            local source_ts=$(redis_get "ron:reinforce:last:$source")
            if [ -n "$source_ts" ] && [[ "$source_ts" > "$current_ts" ]]; then
                dream_log "STALE CITATION: $short_key references $source (source updated after citation)"
                redis_set "ron:stale:$short_key" "true"
                fixed=$((fixed + 1))
                break
            fi
        done
    done <<< "$citation_keys"
    
    echo "$fixed"
}

# Enrich entity pages
do_enrich() {
    local enriched=0
    
    # Use temp file to capture episodic entries
    local tmpfile=$(mktemp)
    find_old_episodic 7 > "$tmpfile"
    
    # Find entities mentioned across entries
    declare -A entity_entries
    declare -A entity_values
    
    while IFS='|' read -r key value timestamp; do
        [ -z "$key" ] && continue
        
        # Extract words from key name
        if [[ "$key" =~ ^episodic:[0-9_]+_(.+)$ ]]; then
            local topic="${BASH_REMATCH[1]}"
            for word in $(echo "$topic" | tr '_' ' '); do
                if [ ${#word} -gt 4 ]; then
                    entity_entries["$word"]=$((${entity_entries["$word"]:-0} + 1))
                    entity_values["$word"]="${entity_values[$word]:-}${entity_values[$word]:+, }$value"
                fi
            done
        fi
    done < "$tmpfile"
    
    rm -f "$tmpfile"
    
    # Create enrichment entries for entities with multiple entries
    for entity in "${!entity_entries[@]}"; do
        local count=${entity_entries["$entity"]}
        if [ "$count" -gt 1 ]; then
            local enrichment="Enriched from dream cycle: $count related entries found"
            redis_set "ron:enriched:$entity" "$enrichment"
            enriched=$((enriched + 1))
            dream_log "ENRICHED: $entity has $count related entries"
        fi
    done
    
    echo "$enriched"
}

# Identify memory gaps
do_gaps() {
    local gaps=0
    local timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local cutoff_epoch=$(date -d "30 days ago" +%s)
    
    # Known important topics
    declare -a important_topics=(
        "heyron" "perforce" "fitness-app" "sam" "pat"
        "family" "holiday" "career" "health" "projects"
    )
    
    for topic in "${important_topics[@]}"; do
        local found=0
        if [ -f "$RON_CACHE_FILE" ]; then
            while IFS='|' read -r key value ts rest; do
                ts=$(echo "$ts" | tr -d ' ')
                local ts_epoch=$(date -d "$ts" +%s 2>/dev/null || echo 0)
                if [ "$ts_epoch" -gt "$cutoff_epoch" ]; then
                    if echo "$key $value" | grep -qi "$topic"; then
                        found=1
                        break
                    fi
                fi
            done < "$RON_CACHE_FILE"
        fi
        
        if [ "$found" -eq 0 ]; then
            dream_log "GAP: No recent entries for topic '$topic' (last 30 days)"
            redis_set "ron:gap:$topic" "$timestamp"
            gaps=$((gaps + 1))
        fi
    done
    
    echo "$gaps"
}

# Install cron job
install_cron() {
    local cron_entry="0 2 * * * /root/.openclaw/skills/ron-memory/scripts/memory-dream.sh run >> /root/.openclaw/workspace/logs/dream.log 2>&1"
    
    # Check if already installed
    if crontab -l 2>/dev/null | grep -q "memory-dream.sh"; then
        echo "Cron already installed"
        return
    fi
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    echo "Cron installed: 2am daily dream cycle"
}

# Show status
cmd_status() {
    echo "=== Dream Cycle Status ==="
    echo ""
    
    if [ -f "$DREAM_STATE_FILE" ]; then
        python3 -c "
import json
with open('$DREAM_STATE_FILE') as f:
    state = json.load(f)
print(f\"Last run: {state.get('last_run', 'never')}\")
print(f\"Entries consolidated: {state.get('entries_consolidated', 0)}\")
print(f\"Citations fixed: {state.get('citations_fixed', 0)}\")
print(f\"Gaps identified: {state.get('gaps_identified', 0)}\")
print(f\"Enrichments: {state.get('enrichments', 0)}\")
"
    else
        echo "No dream cycles run yet"
    fi
    
    echo ""
    echo "=== Recent Stats ==="
    if [ -f "$DREAM_STATS_FILE" ]; then
        python3 -c "
import json
with open('$DREAM_STATS_FILE') as f:
    stats = json.load(f)
runs = stats.get('runs', [])
print(f\"Total runs: {stats.get('total_runs', 0)}\")
print(f\"Total consolidated: {stats.get('total_consolidated', 0)}\")
print()
print('Last 5 runs:')
for run in runs[:5]:
    print(f\"  {run.get('timestamp','')}: {run.get('consolidated',0)} consolidated, {run.get('gaps',0)} gaps\")
"
    else
        echo "No stats available"
    fi
    
    echo ""
    echo "=== Inhibition Status ==="
    if is_inhibited; then
        local expiry=$(cat "$INHIBIT_FILE" | grep -v '^#' | head -1)
        local remaining=$((expiry - $(date +%s)))
        local hours=$((remaining / 3600))
        echo "INHIBITED for ~${hours} more hours"
    else
        echo "Active (not inhibited)"
    fi
    
    echo ""
    echo "=== Cron ==="
    if crontab -l 2>/dev/null | grep -q "memory-dream.sh"; then
        echo "Cron installed: 0 2 * * * (2am daily)"
    else
        echo "Cron NOT installed. Run 'memory-dream.sh install-cron' to set up."
    fi
}

# Main run
cmd_run() {
    DRY_RUN=false
    FOCUS=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN=true; shift ;;
            --focus) FOCUS="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    # Check inhibition
    if is_inhibited; then
        dream_log "Dream cycle SKIPPED (inhibited)"
        exit 0
    fi
    
    dream_log "=== DREAM CYCLE START ==="
    dream_log "Mode: $(if [ "$DRY_RUN" = true ]; then echo "DRY RUN"; else echo "LIVE"; fi)"
    [ -n "$FOCUS" ] && dream_log "Focus: $FOCUS"
    
    # Init stats for this run
    update_stats "run" 0
    
    # 1. Consolidate old episodic entries
    local consolidated=$(do_consolidate "$DRY_RUN" "$FOCUS")
    update_stats "consolidated" "$consolidated"
    
    # 2. Check for stale citations
    local citations_fixed=0
    if [ "$DRY_RUN" = "false" ]; then
        citations_fixed=$(do_check_citations)
    fi
    update_stats "citations" "$citations_fixed"
    
    # 3. Enrich entity pages
    local enrichments=$(do_enrich)
    update_stats "enrichments" "$enrichments"
    
    # 4. Identify gaps
    local gaps=$(do_gaps)
    update_stats "gaps" "$gaps"
    
    # Update state
    local now_ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local now_epoch=$(date +%s)
    
    python3 - "$DREAM_STATE_FILE" "$now_ts" "$now_epoch" "$consolidated" "$citations_fixed" "$gaps" "$enrichments" << 'PYEOF'
import json, sys
state_file = sys.argv[1]
now_ts = sys.argv[2]
now_epoch = int(sys.argv[3])
consolidated = int(sys.argv[4])
citations = int(sys.argv[5])
gaps = int(sys.argv[6])
enrichments = int(sys.argv[7])

state = {
    "last_run": now_ts,
    "last_run_epoch": now_epoch,
    "entries_consolidated": consolidated,
    "syntheses_updated": 0,
    "gaps_identified": gaps,
    "citations_fixed": citations,
    "enrichments": enrichments
}
with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)
PYEOF
    
    dream_log "=== DREAM CYCLE COMPLETE ==="
    dream_log "Summary: $consolidated consolidated, $citations_fixed citations fixed, $enrichments enrichments, $gaps gaps"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "(DRY RUN - no changes made)"
    fi
}

# Command dispatcher
COMMAND="${1:-run}"
case "$COMMAND" in
    run) shift; cmd_run "$@" ;;
    status) cmd_status ;;
    inhibit)
        HOURS=8
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --hours) HOURS="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        expiry_ts=$(($(date +%s) + HOURS * 3600))
        mkdir -p "$(dirname "$INHIBIT_FILE")"
        echo "$expiry_ts" > "$INHIBIT_FILE"
        echo "Dream cycle inhibited for $HOURS hours (expires $(date -d "@$expiry_ts" +'%Y-%m-%d %H:%M'))"
        ;;
    allow)
        rm -f "$INHIBIT_FILE"
        echo "Dream cycle resumed"
        ;;
    trigger) shift; cmd_run "$@" ;;
    install-cron) install_cron ;;
    -h|--help|help) usage ;;
    *) echo "Unknown command: $COMMAND"; usage; exit 1 ;;
esac