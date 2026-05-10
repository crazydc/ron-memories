#!/bin/bash
# memory-search.sh v3 — Fuzzy/natural language search for memories
# Search Redis + local cache by key patterns or value content
# Results ranked by relevance (match location + reinforce score)

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
  -h, --help      Show this help

Examples:
  memory-search.sh "car"
  memory-search.sh "what car does Alex have"
  memory-search.sh "heyron project status"
  memory-search.sh "sam birthday" --limit 5
  memory-search.sh "london office" --namespace work
EOF
}

QUERY=""
LIMIT=10
SEARCH_REDIS=true
SEARCH_CACHE=true
NAMESPACE_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --limit) LIMIT="$2"; shift 2 ;;
        --redis) SEARCH_REDIS=true; SEARCH_CACHE=false; shift ;;
        --cache) SEARCH_CACHE=true; SEARCH_REDIS=false; shift ;;
        --namespace) NAMESPACE_FILTER="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) QUERY="$1"; shift ;;
    esac
done

if [ -z "$QUERY" ]; then
    usage
    exit 1
fi

# Normalize query
QUERY_LC=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
# Split into terms
IFS=' ' read -ra TERMS <<< "$QUERY_LC"

# Temp file for results
TMP_RESULTS=$(mktemp)
TMP_ALL_ENTRIES=$(mktemp)

# Function to extract entries from Redis scan
search_redis() {
    local token="$UPSTASH_REDIS_TOKEN"
    local url="$UPSTASH_REDIS_URL"
    
    if [ -z "$token" ] || [ -z "$url" ]; then
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
            
            # Check if query matches key or value
            local key_match=false
            local value_match=false
            local best_score=0
            
            # Strip "ron:" prefix for matching
            local stripped_key="${key#ron:}"
            local stripped_key_lc=$(echo "$stripped_key" | tr '[:upper:]' '[:lower:]')
            local value_lc=$(echo "$value" | tr '[:upper:]' '[:lower:]')
            
            for term in "${TERMS[@]}"; do
                # Key match (higher score)
                if echo "$stripped_key_lc" | grep -q "$term"; then
                    key_match=true
                    best_score=$((best_score + 30))
                fi
                # Value match
                if echo "$value_lc" | grep -q "$term"; then
                    value_match=true
                    best_score=$((best_score + 10))
                fi
            done
            
            if [ "$best_score" -gt 0 ]; then
                local reinforce_key="ron:reinforce:count:${stripped_key}"
                local reinforce_response=$(curl -s "$url/get/$reinforce_key" \
                    -H "Authorization: Bearer $token" 2>/dev/null)
                local reinforce_count=$(echo "$reinforce_response" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
print(inner.get('value', '0'))
" 2>/dev/null || echo "0")
                
                local total_score=$((best_score + reinforce_count))
                
                # Output: score|key|value|timestamp
                echo "$total_score|$stripped_key|$value|$timestamp" >> "$TMP_RESULTS"
                echo "$total_score|$stripped_key|$value|$timestamp" >> "$TMP_ALL_ENTRIES"
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

# Function to search local cache
search_cache() {
    if [ ! -f "$RON_CACHE_FILE" ]; then
        return
    fi
    
    local cache_lc=$(cat "$RON_CACHE_FILE" | tr '[:upper:]' '[:lower:]')
    
    # Check each line
    while IFS= read -r line; do
        # Parse: | key | value | timestamp | ...
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
        
        local best_score=0
        
        for term in "${TERMS[@]}"; do
            if echo "$key_lc" | grep -q "$term"; then
                best_score=$((best_score + 30))
            fi
            if echo "$value_lc" | grep -q "$term"; then
                best_score=$((best_score + 10))
            fi
        done
        
        if [ "$best_score" -gt 0 ]; then
            # Get reinforce count from Redis if available
            local reinforce_count=0
            if [ -n "$UPSTASH_REDIS_TOKEN" ] && [ -n "$UPSTASH_REDIS_URL" ]; then
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
            
            local total_score=$((best_score + reinforce_count))
            echo "$total_score|$key|$value|$timestamp" >> "$TMP_RESULTS"
            
            # Only add to all entries if not already there (avoid duplicates from cache)
            if ! grep -q "|$key|" "$TMP_ALL_ENTRIES" 2>/dev/null; then
                echo "$total_score|$key|$value|$timestamp" >> "$TMP_ALL_ENTRIES"
            fi
        fi
    done < "$RON_CACHE_FILE"
}

# Run searches
[ "$SEARCH_REDIS" = true ] && search_redis
[ "$SEARCH_CACHE" = true ] && search_cache

# Deduplicate and sort results
if [ -f "$TMP_RESULTS" ] && [ -s "$TMP_RESULTS" ]; then
    # Sort by score (descending), then output
    sort -t'|' -k1 -rn "$TMP_RESULTS" | head -n "$LIMIT" | while IFS='|' read -r score key value timestamp; do
        echo "[score: $score] $key"
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

# Cleanup
rm -f "$TMP_RESULTS" "$TMP_ALL_ENTRIES"