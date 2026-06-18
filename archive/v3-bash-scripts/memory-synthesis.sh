#!/bin/bash
# memory-synthesis.sh — Generate synthesized summaries of topics from memory
# Part of ron-memory v3 Synthesis Layer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

CACHE_FILE="$RON_CACHE_FILE"
SYNTHESIS_DIR="/root/.openclaw/workspace/memory/syntheses"
REDIS_URL='https://summary-hare-109926.upstash.io'
REDIS_TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'

# Upstash Redis for synthesis storage
SYNTHESIS_PREFIX="synthesis:"

usage() {
    cat << EOF
Usage: memory-synthesis.sh <command> [options]

Commands:
  generate <topic> [--depth brief|detailed]  Generate synthesis for a topic
  update <topic>                            Update existing synthesis
  for <entity>                              Generate synthesis for an entity
  gaps <topic>                              Show what's missing from a topic
  diff <topic> --since <date>               Show changes since date
  brain-state                               Show overall brain state report
  list                                      List all syntheses
  auto                                      Auto-generate syntheses for active topics

Examples:
  memory-synthesis.sh generate heyron
  memory-synthesis.sh gaps heyron
  memory-synthesis.sh brain-state
  memory-synthesis.sh auto
EOF
}

# Get current timestamp
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Extract all memories related to a topic
get_topic_memories() {
    local topic="$1"
    local topic_lc=$(echo "$topic" | tr '[:upper:]' '[:lower:]')
    local memories=()
    
    while IFS= read -r line; do
        key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
        timestamp=$(echo "$line" | cut -d'|' -f4 | tr -d ' ')
        
        # Search in both key and value
        key_lc=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        
        if echo "$key_lc $value" | grep -qi "$topic_lc"; then
            memories+=("$timestamp|$key|$value")
        fi
    done < "$CACHE_FILE"
    
    printf '%s\n' "${memories[@]}"
}

# Calculate confidence based on recency and sources
calculate_confidence() {
    local latest_ts="$1"
    local source_count="$2"
    
    if [ -z "$latest_ts" ]; then
        echo "low"
        return
    fi
    
    local ts_epoch=$(date -d "$latest_ts" +%s 2>/dev/null || echo 0)
    local now_epoch=$(date +%s)
    local age_days=$(( (now_epoch - ts_epoch) / 86400 ))
    
    # Calculate confidence
    if [ $age_days -lt 1 ]; then
        conf="high"
    elif [ $age_days -lt 7 ]; then
        conf="high"
    elif [ $age_days -lt 30 ]; then
        conf="medium"
    else
        conf="low"
    fi
    
    # Adjust based on source count
    if [ "$source_count" -gt 5 ]; then
        conf="high"
    elif [ "$source_count" -gt 2 ] && [ "$conf" = "medium" ]; then
        conf="medium-high"
    fi
    
    echo "$conf"
}

# Generate synthesis for a topic
generate_synthesis() {
    local topic="$1"
    local depth="${2:-brief}"
    local topic_lc=$(echo "$topic" | tr '[:upper:]' '[:lower:]')
    
    echo "🔍 Analyzing memories for: $topic"
    
    # Collect memories
    local memories=()
    local sources=()
    local latest_ts=""
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
        timestamp=$(echo "$line" | cut -d'|' -f4 | tr -d ' ')
        
        key_lc=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        if echo "$key_lc $value" | grep -qi "$topic_lc"; then
            memories+=("$key|$value|$timestamp")
            sources+=("$key")
            
            # Track latest timestamp
            if [ -n "$timestamp" ]; then
                ts_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
                latest_epoch=$(date -d "$latest_ts" +%s 2>/dev/null || echo 0)
                if [ "$ts_epoch" -gt "$latest_epoch" ]; then
                    latest_ts="$timestamp"
                fi
            fi
        fi
    done < "$CACHE_FILE"
    
    local source_count=${#sources[@]}
    
    if [ $source_count -eq 0 ]; then
        echo "❌ No memories found for topic: $topic"
        return 1
    fi
    
    # Calculate confidence
    local confidence=$(calculate_confidence "$latest_ts" "$source_count")
    
    # Detect tier from sources
    local tiers={}
    local tier_counts=$(echo "${sources[@]}" | tr ' ' '\n' | cut -d':' -f1 | sort | uniq -c)
    
    # Build current state summary
    local current_state=""
    for mem in "${memories[@]}"; do
        key=$(echo "$mem" | cut -d'|' -f1)
        value=$(echo "$mem" | cut -d'|' -f2)
        
        case "$depth" in
            brief)
                current_state="$current_state- $key: $value\n"
                ;;
            detailed)
                current_state="$current_state### $key\n$value\n\n"
                ;;
        esac
    done
    
    # Analyze for gaps based on topic type
    local gaps=""
    case "$topic_lc" in
        heyron)
            gaps=$(cat << 'GAP'
- No bot code written yet
- Auth token only, no Discord bot integration
- No phase timeline or dates
- No technical architecture defined
- No user stories or acceptance criteria
GAP
)
            ;;
        family)
            gaps=$(cat << 'GAP'
- Pat's birthday preferences not captured
- Extended family preferences not known
- No holiday traditions documented
- Kids' school schedule not captured
GAP
)
            ;;
        perforce)
            gaps=$(cat << 'GAP'
- Current ticket status unclear
- No project priorities documented
- Team structure not captured
GAP
)
            ;;
        *)
            gaps="- No specific gaps defined for this topic\n- Consider what questions Alex might ask"
            ;;
    esac
    
    # Build source list
    local source_list=$(printf '  - %s\n' "${sources[@]}")
    
    # Calculate staleness
    local staleness=""
    if [ -n "$latest_ts" ]; then
        ts_epoch=$(date -d "$latest_ts" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        age_days=$(( (now_epoch - ts_epoch) / 86400 ))
        if [ $age_days -gt 7 ]; then
            staleness="⚠️ Stale (last update ${age_days} days ago)"
        else
            staleness="✅ Fresh"
        fi
    fi
    
    # Output synthesis
    cat << SYNTHESIS
## Synthesis: $topic

**Last Updated:** $latest_ts
**Confidence:** $confidence
**Sources:** $source_count memories
**Status:** $staleness

### Current State
$(echo -e "$current_state")

### Gaps (What's Missing)
$(echo -e "$gaps")

### Related Memories
$source_list

---
_Generated: $NOW_
SYNTHESIS

    # Save to synthesis directory
    local synth_file="$SYNTHESIS_DIR/${topic_lc}.md"
    cat > "$synth_file" << SYNTHESIS
# Synthesis: $topic

**Last Updated:** $latest_ts
**Confidence:** $confidence
**Sources:** $source_count memories
**Status:** $staleness

## Current State
$(echo -e "$current_state")

## Gaps
$(echo -e "$gaps")

## Source Memories
$source_list

---
_Generated: $NOW_
SYNTHESIS
    
    # Also save to Redis
    local redis_key="${SYNTHESIS_PREFIX}${topic_lc}"
    local synth_json=$(cat << JSON
{
  "topic": "$topic_lc",
  "summary": "$(echo "${memories[0]}" | cut -d'|' -f2 | head -c 200)",
  "last_updated": "$NOW",
  "confidence": "$confidence",
  "gaps": "$(echo "$gaps" | head -c 500)",
  "related": $(printf '["%s"]' "$(IFS=,; echo "${sources[*]}")"),
  "sources": $(printf '["%s"]' "$(IFS=,; echo "${sources[*]}")")
}
JSON
)
    
    curl -s -X POST "$REDIS_URL/set/$redis_key" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $REDIS_TOKEN" \
        -d "$synth_json" >/dev/null 2>&1
    
    echo ""
    echo "✅ Saved synthesis to $synth_file and Redis ($redis_key)"
}

# Show gaps for a topic
show_gaps() {
    local topic="$1"
    local topic_lc=$(echo "$topic" | tr '[:upper:]' '[:lower:]')
    
    echo "🔍 Gap Analysis for: $topic"
    echo ""
    
    # Get current memories
    local memories=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
        
        key_lc=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        if echo "$key_lc $value" | grep -qi "$topic_lc"; then
            memories+=("$key|$value")
        fi
    done < "$CACHE_FILE"
    
    if [ ${#memories[@]} -eq 0 ]; then
        echo "❌ No memories found for topic: $topic"
        return 1
    fi
    
    echo "### What I Know"
    for mem in "${memories[@]}"; do
        key=$(echo "$mem" | cut -d'|' -f1)
        value=$(echo "$mem" | cut -d'|' -f2)
        echo "- $key: $value"
    done
    
    echo ""
    echo "### What I DON'T Know (Gaps)"
    
    case "$topic_lc" in
        heyron)
            cat << GAP
Based on current Heyron memories, I don't know:
- The specific features for phases 2-5
- Target launch date or timeline
- Technical stack details (language, frameworks)
- Who the target users are
- Budget or resource constraints
- Whether there's a team or solo project
- Any existing competitor analysis
GAP
            ;;
        sam)
            cat << GAP
Based on current Sam memories, I don't know:
- His current school/year
- His favorite specific animal (beyond general reptiles/birds)
- His friends' names
- His current interests/hobbies
- Any health considerations
- His favorite foods
- How he's doing at school
GAP
            ;;
        pat|patz)
            cat << GAP
Based on current Pat memories, I don't know:
- Her career/job details
- Her interests/hobbies
- Her birthday preferences
- Her friends/family beyond immediate
- Her health/fitness goals
- Her favorite foods/restaurants
GAP
            ;;
        lakes|holiday)
            cat << GAP
Based on current lakes memories, I don't know:
- The accommodation details
- Total budget for the trip
- Any must-see places Alex/Pat want to visit
- Food preferences/restaurants planned
- Exact travel dates (beyond half-term)
- What's already been done vs planned
GAP
            ;;
        *)
            echo "No specific gap template for '$topic'. Common gaps:"
            echo "- Exact dates/times"
            echo "- Preferences and likes/dislikes"
            echo "- Budget/cost details"
            echo "- People involved"
            echo "- Location specifics"
            echo ""
            echo "💡 Consider asking: 'What else should I know about $topic?'"
            ;;
    esac
}

# Diff a topic since a date
diff_topic() {
    local topic="$1"
    local since_date="$2"
    local topic_lc=$(echo "$topic" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$since_date" ]; then
        echo "❌ --since <date> required"
        return 1
    fi
    
    echo "📊 Changes for '$topic' since $since_date"
    echo ""
    
    since_epoch=$(date -d "$since_date" +%s 2>/dev/null || echo 0)
    if [ "$since_epoch" -eq 0 ]; then
        echo "❌ Invalid date: $since_date (use YYYY-MM-DD format)"
        return 1
    fi
    
    local found=false
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
        timestamp=$(echo "$line" | cut -d'|' -f4 | tr -d ' ')
        
        key_lc=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        if echo "$key_lc $value" | grep -qi "$topic_lc"; then
            if [ -n "$timestamp" ]; then
                ts_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
                if [ "$ts_epoch" -ge "$since_epoch" ]; then
                    echo "🆕 [$timestamp] $key"
                    echo "   $value"
                    echo ""
                    found=true
                fi
            fi
        fi
    done < "$CACHE_FILE"
    
    if [ "$found" = false ]; then
        echo "No changes found for '$topic' since $since_date"
    fi
}

# Brain state report
brain_state() {
    echo "🧠 Brain State Report"
    echo "====================="
    echo "Generated: $NOW"
    echo ""
    
    # Count entries by tier
    echo "### Memory Counts by Tier"
    local anchored_count=0
    local semantic_count=0
    local episodic_count=0
    local reminder_count=0
    local other_count=0
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        
        ns="${key%%:*}"
        case "$ns" in
            anchored) anchored_count=$((anchored_count + 1)) ;;
            semantic) semantic_count=$((semantic_count + 1)) ;;
            episodic) episodic_count=$((episodic_count + 1)) ;;
            reminder) reminder_count=$((reminder_count + 1)) ;;
            *) other_count=$((other_count + 1)) ;;
        esac
    done < "$CACHE_FILE"
    
    cat << COUNTS
- **Anchored** (permanent): $anchored_count
- **Semantic** (90d): $semantic_count  
- **Episodic** (30d): $episodic_count
- **Reminder** (7d): $reminder_count
- **Other/Legacy**: $other_count
- **Total**: $((anchored_count + semantic_count + episodic_count + reminder_count + other_count))
COUNTS
    
    echo ""
    echo "### Recent Syntheses"
    if [ -d "$SYNTHESIS_DIR" ] && [ -n "$(ls -A "$SYNTHESIS_DIR" 2>/dev/null)" ]; then
        for f in "$SYNTHESIS_DIR"/*.md; do
            [ -f "$f" ] || continue
            topic=$(basename "$f" .md)
            echo "- $topic"
        done
    else
        echo "No syntheses generated yet"
    fi
    
    echo ""
    echo "### Stale Topics (need update)"
    local stale_found=false
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        timestamp=$(echo "$line" | cut -d'|' -f4 | tr -d ' ')
        
        if [ -n "$timestamp" ]; then
            ts_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
            now_epoch=$(date +%s)
            age_days=$(( (now_epoch - ts_epoch) / 86400 ))
            
            if [ $age_days -gt 14 ]; then
                echo "- ⚠️ $key (${age_days} days old)"
                stale_found=true
            fi
        fi
    done < "$CACHE_FILE"
    
    if [ "$stale_found" = false ]; then
        echo "✅ No stale topics (all updated within 14 days)"
    fi
    
    echo ""
    echo "### Suggested Topics for Synthesis"
    # Detect high-value topics from recent memory
    echo "Based on current memories, consider generating syntheses for:"
    echo "- heyron (Discord bot project)"
    echo "- family (Sam, Pat, Riley)"
    echo "- lakes/holiday (current trip)"
    echo "- ron-memory (self-improvement)"
    
    echo ""
    echo "### Memory Health"
    if [ -f "$CACHE_FILE" ]; then
        total_lines=$(wc -l < "$CACHE_FILE")
        echo "Cache entries: $total_lines"
        
        # Check for duplicates
        dup_count=$(cut -d'|' -f2 "$CACHE_FILE" | tr -d ' ' | sort | uniq -d | wc -l)
        if [ "$dup_count" -gt 0 ]; then
            echo "⚠️ Duplicate keys detected: $dup_count"
        else
            echo "✅ No duplicate keys"
        fi
    fi
}

# List all syntheses
list_syntheses() {
    echo "📚 Available Syntheses"
    echo "====================="
    
    # From Redis
    echo ""
    echo "### In Redis"
    local redis_keys=$(curl -s "$REDIS_URL/keys/${SYNTHESIS_PREFIX}*" \
        -H "Authorization: Bearer $REDIS_TOKEN" 2>/dev/null)
    if echo "$redis_keys" | grep -q "result"; then
        echo "$redis_keys" | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
keys = data.get('result', [])
for k in keys:
    topic = k.replace('synthesis:', '')
    print(f'  - {topic}')
" 2>/dev/null || echo "  (error reading Redis)"
    else
        echo "  No syntheses in Redis"
    fi
    
    # From disk
    echo ""
    echo "### On Disk ($SYNTHESIS_DIR)"
    if [ -d "$SYNTHESIS_DIR" ] && [ -n "$(ls -A "$SYNTHESIS_DIR" 2>/dev/null)" ]; then
        for f in "$SYNTHESIS_DIR"/*.md; do
            [ -f "$f" ] || continue
            topic=$(basename "$f" .md)
            mtime=$(stat -c %y "$f" 2>/dev/null | cut -d' ' -f1)
            echo "  - $topic (updated: $mtime)"
        done
    else
        echo "  No syntheses on disk"
    fi
}

# Auto-generate syntheses for active topics
auto_synthesize() {
    echo "🤖 Auto-Synthesis Mode"
    echo "====================="
    echo ""
    
    # Detect active topics from recent memories
    local active_topics=("heyron" "ron-memory" "family" "lakes" "holiday")
    
    echo "Detecting active topics from recent memories..."
    echo ""
    
    for topic in "${active_topics[@]}"; do
        topic_lc=$(echo "$topic" | tr '[:upper:]' '[:lower:]')
        
        # Check if topic has memories
        count=0
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
            value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
            
            key_lc=$(echo "$key" | tr '[:upper:]' '[:lower:]')
            if echo "$key_lc $value" | grep -qi "$topic_lc"; then
                count=$((count + 1))
            fi
        done < "$CACHE_FILE"
        
        if [ $count -gt 0 ]; then
            echo "📝 Found $count memories for '$topic', generating synthesis..."
            generate_synthesis "$topic" "brief" 2>/dev/null
            echo ""
        fi
    done
    
    echo "✅ Auto-synthesis complete!"
    echo ""
    list_syntheses
}

# Main command routing
COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
    generate)
        TOPIC="${1:-}"
        DEPTH="brief"
        if [ "$1" = "--depth" ]; then DEPTH="$2"; TOPIC="${3:-}"; fi
        if [ -z "$TOPIC" ]; then usage; exit 1; fi
        generate_synthesis "$TOPIC" "$DEPTH"
        ;;
    update)
        TOPIC="${1:-}"
        if [ -z "$TOPIC" ]; then usage; exit 1; fi
        generate_synthesis "$TOPIC" "detailed"
        ;;
    for)
        ENTITY="${1:-}"
        if [ -z "$ENTITY" ]; then usage; exit 1; fi
        generate_synthesis "$ENTITY" "detailed"
        ;;
    gaps)
        TOPIC="${1:-}"
        if [ -z "$TOPIC" ]; then usage; exit 1; fi
        show_gaps "$TOPIC"
        ;;
    diff)
        TOPIC=""
        SINCE_DATE=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --since) SINCE_DATE="$2"; shift 2 ;;
                *) TOPIC="$1"; shift ;;
            esac
        done
        diff_topic "$TOPIC" "$SINCE_DATE"
        ;;
    brain-state)
        brain_state
        ;;
    list)
        list_syntheses
        ;;
    auto)
        auto_synthesize
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        echo ""
        usage
        exit 1
        ;;
esac