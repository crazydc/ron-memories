#!/bin/bash
# memory-search.sh v3.1 — Fuzzy/natural language search for memories
# Search Redis + local cache by key patterns or value content
# Results ranked using RRF (Reciprocal Rank Fusion) combining:
#   - Keyword match score (BM25-style)
#   - Recency/freshness score
#   - Reinforce count (access frequency)
#   - Tier importance boost

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

usage() {
    cat << EOF
Usage: memory-search.sh "<query>" [options]
Search memories using natural language or keywords.
No need for exact key names — fuzzy match against keys AND values.

Options:
  --limit N       Maximum results to return (default: 10)
  --redis         Search Redis only
  --cache         Search local cache only
  --namespace NS  Filter to specific namespace (e.g. "vehicle", "family")
  --graph ENTITY  Query knowledge graph for entity relationships
  --depth N       Graph traversal depth (default: 1)
  --embed [N]     Hybrid search: combine keyword RRF + vector similarity (default top 5)
  -h, --help      Show this help

Graph Queries:
  "who does Sam love?"   → shows sam --loves-->
  "where does Alex work?"    → shows acasey --works_at-->
  "what has Sam visited?" → shows sam --visited-->

Examples:
  memory-search.sh "car"
  memory-search.sh "what car does Alex have"
  memory-search.sh "heyron project status"
  memory-search.sh "sam birthday" --limit 5
  memory-search.sh "london office" --namespace work
  memory-search.sh --graph sam
  memory-search.sh --graph sam --depth 2
EOF
}

QUERY=""
LIMIT=10
SEARCH_REDIS=true
SEARCH_CACHE=true
NAMESPACE_FILTER=""
GRAPH_ENTITY=""
GRAPH_DEPTH=1
EMBED_SEARCH=false
EMBED_TOP=5

while [[ $# -gt 0 ]]; do
    case $1 in
        --limit) LIMIT="$2"; shift 2 ;;
        --redis) SEARCH_REDIS=true; SEARCH_CACHE=false; shift ;;
        --cache) SEARCH_CACHE=true; SEARCH_REDIS=false; shift ;;
        --namespace) NAMESPACE_FILTER="$2"; shift 2 ;;
        --graph) GRAPH_ENTITY="$2"; shift 2 ;;
        --depth) GRAPH_DEPTH="$2"; shift 2 ;;
        --embed)
            EMBED_SEARCH=true
            # Check if next arg is a number
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                EMBED_TOP="$2"; shift 2
            else
                shift
            fi
            ;;
        -h|--help) usage; exit 0 ;;
        *) QUERY="$1"; shift ;;
    esac
done

if [ -z "$QUERY" ] && [ -z "$GRAPH_ENTITY" ]; then
    usage
    exit 1
fi

# RRF parameters
RRF_K=60  # Standard RRF damping factor
NOW=$(date +%s)

# ============================================
# Graph Query Mode
# ============================================
if [ -n "$GRAPH_ENTITY" ]; then
    LINKS_DIR="$RON_CACHE_DIR/links"
    mkdir -p "$LINKS_DIR"
    
    echo "Knowledge Graph for: $GRAPH_ENTITY"
    echo "=============================="
    echo ""
    
    # Normalize entity name
    norm_entity=$(echo "$GRAPH_ENTITY" | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g')
    
    # Get outgoing links
    entity_file="$LINKS_DIR/${norm_entity}.json"
    if [ -f "$entity_file" ]; then
        echo "Outgoing relationships:"
        python3 -c "
import json
with open('$entity_file', 'r') as f:
    data = json.load(f)
for link in data.get('links', []):
    rel = link.get('relationship', '')
    to = link.get('to', '')
    ctx = link.get('context', '')
    print(f'  --{rel}--> {to}', end='')
    if ctx:
        print(f' (context: {ctx})', end='')
    print('')
" 2>/dev/null || echo "  (error reading file)"
    else
        echo "  No outgoing relationships found"
    fi
    
    echo ""
    
    # Get back-links
    echo "Incoming relationships (who links TO this entity):"
    found_back=0
    for file in "$LINKS_DIR"/*.json; do
        [ -f "$file" ] || continue
        name=$(basename "$file" .json)
        if [ "$name" = "$norm_entity" ]; then
            continue
        fi
        if grep -q "\"to\": \"$norm_entity\"" "$file" 2>/dev/null; then
            python3 -c "
import json
with open('$file', 'r') as f:
    data = json.load(f)
entity = data.get('entity', '')
for link in data.get('links', []):
    if link.get('to') == '$norm_entity':
        rel = link.get('relationship', '')
        print(f'{entity} --{rel}--> $norm_entity')
" 2>/dev/null
            found_back=1
        fi
    done
    [ "$found_back" = "0" ] && echo "  No incoming relationships found"
    
    echo ""
    echo "=============================="
    
    # Optional: Show linked entities' relationships (depth 2)
    if [ "$GRAPH_DEPTH" -gt 1 ]; then
        echo ""
        echo "Extended (depth $GRAPH_DEPTH):"
        # Get all linked entities
        if [ -f "$entity_file" ]; then
            python3 -c "
import json
with open('$entity_file', 'r') as f:
    data = json.load(f)
links = data.get('links', [])
for link in links:
    to_entity = link.get('to', '')
    print(to_entity)
" > /tmp/linked_entities.txt
            
            for linked in $(cat /tmp/linked_entities.txt); do
                linked_file="$LINKS_DIR/${linked}.json"
                if [ -f "$linked_file" ]; then
                    echo ""
                    echo "  $norm_entity --> $linked -->:"
                    python3 -c "
import json
with open('$linked_file', 'r') as f:
    data = json.load(f)
for link in data.get('links', []):
    rel = link.get('relationship', '')
    to = link.get('to', '')
    print(f'    --{rel}--> {to}')
" 2>/dev/null
                fi
            done
            rm -f /tmp/linked_entities.txt
        fi
    fi
    
    exit 0
fi

# Normalize query
QUERY_LC=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
# Split into terms
IFS=' ' read -ra TERMS <<< "$QUERY_LC"

# Temp files for results from each source (before RRF fusion)
TMP_REDIS=$(mktemp)
TMP_CACHE=$(mktemp)
TMP_FUSED=$(mktemp)

# ============================================
# Tier importance multipliers (higher = more important)
# ============================================
declare -A TIER_BOOST=(
    ["anchored"]=20
    ["semantic"]=10
    ["episodic"]=5
    ["reminder"]=3
    ["working"]=2
)

# ============================================
# Calculate freshness score (days since update)
# ============================================
calc_freshness() {
    local timestamp="$1"
    if [ -z "$timestamp" ] || [ "$timestamp" = "null" ]; then
        echo 0
        return
    fi
    
    local ts_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
    if [ "$ts_epoch" -eq 0 ]; then
        echo 0
        return
    fi
    
    local age_seconds=$((NOW - ts_epoch))
    local age_days=$((age_seconds / 86400))
    
    # Exponential decay: fresh items score higher
    # Score = 100 / (1 + age_days)
    if [ $age_days -lt 1 ]; then
        echo 100
    elif [ $age_days -lt 7 ]; then
        echo $((100 - (age_days * 10)))
    elif [ $age_days -lt 30 ]; then
        echo $((50 - ((age_days - 7) * 1)))
    else
        echo $((25 - ((age_days - 30) / 10)))
    fi
    
    # Floor at 0
    [ $age_days -gt 100 ] && echo 0
}

# ============================================
# Extract tier from key
# ============================================
get_tier_from_key() {
    local key="$1"
    local ns="${key%%:*}"
    case "$ns" in
        anchored|family|user|contact|vehicle|book|career)
            echo "anchored"
            ;;
        semantic|pref|project|goal|service|agent)
            echo "semantic"
            ;;
        episodic|reminder)
            echo "episodic"
            ;;
        working)
            echo "working"
            ;;
        *)
            echo "semantic"
            ;;
    esac
}

# ============================================
# Search Redis via SCAN (cursor-based iteration)
# ============================================
search_redis() {
    local token="$UPSTASH_REDIS_TOKEN"
    local url="$UPSTASH_REDIS_URL"
    
    if [ -z "$token" ] || [ -z "$url" ] || [ "$token" = "your-token" ]; then
        return 1
    fi
    
    # Use SCAN to iterate keys (cursor-based, safer than KEYS for large sets)
    local cursor="0"
    while true; do
        local response=$(curl -s "$url/scan/$cursor?match=ron:*&count=100" \
            -H "Authorization: Bearer $token" 2>/dev/null)
        
        # Extract keys from response
        local keys=$(echo "$response" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
keys = d.get('result', {}).get('keys', [])
print('\n'.join(keys))
" 2>/dev/null)
        
        if [ -z "$keys" ]; then
            break
        fi
        
        # For each key, get value and check for matches
        echo "$keys" | while read -r key; do
            # Skip non-data keys
            [[ "$key" =~ :reinforce: ]] && continue
            [[ "$key" =~ :archive: ]] && continue
            
            # Apply namespace filter
            if [ -n "$NAMESPACE_FILTER" ]; then
                local ns="${key#ron:}"
                ns="${ns%%:*}"
                if [ "$ns" != "$NAMESPACE_FILTER" ]; then
                    continue
                fi
            fi
            
            # Get the value
            local value_response=$(curl -s "$url/get/$key" \
                -H "Authorization: Bearer $token" 2>/dev/null)
            
            local value=$(echo "$value_response" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
print(inner.get('value', ''))
" 2>/dev/null)
            
            local timestamp=$(echo "$value_response" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
print(inner.get('timestamp', ''))
" 2>/dev/null)
            
            # Strip "ron:" prefix for matching
            local stripped_key="${key#ron:}"
            local stripped_key_lc=$(echo "$stripped_key" | tr '[:upper:]' '[:lower:]')
            local value_lc=$(echo "$value" | tr '[:upper:]' '[:lower:]')
            
            # Calculate keyword match score
            local key_rank=0
            local value_rank=0
            local term_count=0
            
            for term in "${TERMS[@]}"; do
                ((term_count++))
                # Key match (higher weight)
                if echo "$stripped_key_lc" | grep -q "$term"; then
                    key_rank=$term_count  # First match ranks highest
                fi
                # Value match
                if echo "$value_lc" | grep -q "$term"; then
                    value_rank=$((value_rank + 1))
                fi
            done
            
            # Best keyword rank for this entry (lower is better for RRF)
            local keyword_rank=$key_rank
            [ $value_rank -gt 0 ] && [ $keyword_rank -eq 0 ] && keyword_rank=$((100 + value_rank))
            
            if [ $keyword_rank -gt 0 ]; then
                local tier=$(get_tier_from_key "$stripped_key")
                local tier_score=${TIER_BOOST[$tier]:-5}
                
                local freshness=$(calc_freshness "$timestamp")
                
                # Get reinforce count from Redis
                local reinforce_key="ron:reinforce:count:$stripped_key"
                local reinforce_response=$(curl -s "$url/get/$reinforce_key" \
                    -H "Authorization: Bearer $token" 2>/dev/null)
                local reinforce_count=$(echo "$reinforce_response" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
print(inner.get('value', '0'))
" 2>/dev/null || echo "0")
                
                # Output: key|value|timestamp|keyword_rank|freshness|reinforce|tier|tier_score
                echo "$stripped_key|$value|$timestamp|$keyword_rank|$freshness|$reinforce_count|$tier|$tier_score" >> "$TMP_REDIS"
            fi
        done
        
        # Get next cursor
        cursor=$(echo "$response" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
print(d.get('result', {}).get('cursor', '0'))
" 2>/dev/null)
        
        if [ "$cursor" = "0" ] || [ "$cursor" = "" ]; then
            break
        fi
    done
}

# ============================================
# Search local cache
# ============================================
search_cache() {
    if [ ! -f "$RON_CACHE_FILE" ]; then
        return
    fi
    
    # Check each line
    while IFS= read -r line; do
        # Parse: | key | value | timestamp | metadata
        if ! echo "$line" | grep -q "^| "; then
            continue
        fi
        
        local key=$(echo "$line" | cut -d'|' -f2 | tr -d ' ')
        local value=$(echo "$line" | cut -d'|' -f3 | tr -d ' ')
        local timestamp=$(echo "$line" | cut -d'|' -f4 | tr -d ' ')
        
        [ -z "$key" ] && continue
        [[ "$key" =~ ^# ]] && continue
        
        # Apply namespace filter
        if [ -n "$NAMESPACE_FILTER" ]; then
            local ns="${key%%:*}"
            if [ "$ns" != "$NAMESPACE_FILTER" ]; then
                continue
            fi
        fi
        
        local key_lc=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        local value_lc=$(echo "$value" | tr '[:upper:]' '[:lower:]')
        
        # Calculate keyword match score
        local key_rank=0
        local value_rank=0
        local term_count=0
        
        for term in "${TERMS[@]}"; do
            ((term_count++))
            if echo "$key_lc" | grep -q "$term"; then
                key_rank=$term_count
            fi
            if echo "$value_lc" | grep -q "$term"; then
                value_rank=$((value_rank + 1))
            fi
        done
        
        local keyword_rank=$key_rank
        [ "$value_rank" -gt 0 ] && [ $keyword_rank -eq 0 ] && keyword_rank=$((100 + value_rank))
        
        if [ $keyword_rank -gt 0 ]; then
            local tier=$(get_tier_from_key "$key")
            local tier_score=${TIER_BOOST[$tier]:-5}
            local freshness=$(calc_freshness "$timestamp")
            
            # Get reinforce count from Redis if available
            local reinforce_count=0
            if [ -n "$UPSTASH_REDIS_TOKEN" ] && [ -n "$UPSTASH_REDIS_URL" ] && \
               [ "$UPSTASH_REDIS_TOKEN" != "your-token" ]; then
                local reinforce_key="ron:reinforce:count:$key"
                local reinforce_response=$(curl -s "$UPSTASH_REDIS_URL/get/$reinforce_key" \
                    -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" 2>/dev/null)
                reinforce_count=$(echo "$reinforce_response" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
print(inner.get('value', '0'))
" 2>/dev/null || echo "0")
            fi
            
            echo "$key|$value|$timestamp|$keyword_rank|$freshness|$reinforce_count|$tier|$tier_score" >> "$TMP_CACHE"
        fi
    done < "$RON_CACHE_FILE"
}

# ============================================
# RRF Fusion (Reciprocal Rank Fusion)
# ============================================
fuse_results() {
    local output_file="$1"
    
    # Combine all results
    cat "$TMP_REDIS" "$TMP_CACHE" > "$output_file"
    
    # Deduplicate by key (keep highest scoring entry)
    sort -t'|' -k1 -u "$output_file" > "${output_file}.dedup"
    
    # Calculate RRF score for each entry
    # RRF formula: score = sum over all systems of (1 / (k + rank_in_system))
    # Using pure bash arithmetic (no bc dependency)
    while IFS='|' read -r key value timestamp keyword_rank freshness reinforce_count tier tier_score; do
        [ -z "$key" ] && continue
        
        # RRF with k=60 (standard damping)
        # Keyword rank contribution (lower rank = higher contribution)
        local keyword_rrf=0
        if [ -n "$keyword_rank" ] && [ "$keyword_rank" -gt 0 ]; then
            # Approximate 1/(60+rank) as integer: multiply by 1000 for precision
            local denom=$((60 + keyword_rank))
            keyword_rrf=$((1000 / denom))
        fi
        
        # Freshness rank (convert freshness to a rank - higher freshness = lower rank)
        local freshness_rrf=0
        if [ -n "$freshness" ] && [ "$freshness" -gt 0 ]; then
            # Freshness 100 = rank 1, Freshness 50 = rank 51, etc.
            local freshness_rank=$((101 - freshness))
            [ $freshness_rank -lt 1 ] && freshness_rank=1
            local denom=$((RRF_K + freshness_rank))
            freshness_rrf=$((1000 / denom))
        fi
        
        # Reinforce rank (higher count = more access = higher contribution)
        # Simplified: reinforce adds directly, scaled by 10
        local reinforce_rrf=0
        if [ -n "$reinforce_count" ] && [ "$reinforce_count" -gt 0 ]; then
            reinforce_rrf=$((reinforce_count * 10))
        fi
        
        # Tier importance boost (additive bonus)
        local tier_boost=0
        case "$tier" in
            anchored) tier_boost=200 ;;
            semantic) tier_boost=100 ;;
            episodic) tier_boost=50 ;;
            reminder) tier_boost=30 ;;
            working) tier_boost=20 ;;
        esac
        
        # Total RRF score (all components scaled by 1000 for integer math)
        local total_score=$((keyword_rrf + freshness_rrf + reinforce_rrf + tier_boost))
        
        # Output: score|key|value|timestamp|tier
        echo "$total_score|$key|$value|$timestamp|$tier"
    done < "${output_file}.dedup" | sort -t'|' -k1 -rn
}

# ============================================
# Run searches
# ============================================
[ "$SEARCH_REDIS" = true ] && search_redis
[ "$SEARCH_CACHE" = true ] && search_cache

# ============================================
# Fuse and output results
# ============================================
if [ -f "$TMP_REDIS" ] || [ -f "$TMP_CACHE" ]; then
    fuse_results "$TMP_FUSED" | head -n "$LIMIT" | while IFS='|' read -r score key value timestamp tier; do
        echo "[score: $score] $key ($tier)"
        echo "    value: $value"
        if [ -n "$timestamp" ]; then
            echo "    updated: $timestamp"
        fi
        echo ""
    done
else
    echo "No results found for: $QUERY"
    echo ""
    echo "Tip: Try broader search terms or check spelling."
fi

# ============================================
# Hybrid Search: combine keyword RRF + vector similarity
# ============================================
if [ "$EMBED_SEARCH" = true ]; then
    echo "[Vector search enabled] Running hybrid search..."
    echo "=========================================="
    
    # Run vector search via memory-embed.sh
    embed_output=$(bash "$SCRIPT_DIR/memory-embed.sh" search "$QUERY" "$EMBED_TOP" 2>&1)
    
    if echo "$embed_output" | grep -q "ERROR: Ollama not available"; then
        echo "[Warning] Ollama not available. Falling back to keyword-only search."
        echo "         Run 'memory-embed.sh index --rebuild' to enable vector search."
    elif echo "$embed_output" | grep -q "No embedding index found"; then
        echo "[Warning] No embedding index found. Run 'memory-embed.sh index --rebuild' first."
    else
        echo "$embed_output"
        echo "=========================================="
        echo "Note: Hybrid search combines keyword RRF + vector similarity."
        echo "      Run 'memory-embed.sh index --rebuild' to rebuild the vector index."
    fi
fi

# Cleanup
rm -f "$TMP_REDIS" "$TMP_CACHE" "$TMP_FUSED" "${TMP_REDIS}.dedup" "${TMP_CACHE}.dedup" "${TMP_FUSED}.dedup" 2>/dev/null
