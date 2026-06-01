#!/bin/bash
# memory-embed.sh v1.0 — Ollama embedding support for ron-memory
# Generates vector embeddings for memories enabling semantic similarity search
# 
# Requires: Ollama running on a local network node (e.g. Sparky at 192.168.0.12)
#           or localhost. Falls back to keyword-only search if unavailable.
#
# Usage:
#   memory-embed.sh embed "<text>"          Generate embedding for text
#   memory-embed.sh search "<text>" [N]     Find similar memories (default top 5)
#   memory-embed.sh index [--rebuild]       Rebuild index from all memories
#   memory-embed.sh status                  Show index status
#   memory-embed.sh embed-key <key>         Embed a specific memory by key
#   memory-embed.sh remove-key <key>        Remove embedding for a key

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Ollama endpoint (check gaming PC first, then local)
OLLAMA_HOST="${OLLAMA_EMBED_HOST:-http://192.168.0.12:11434}"
OLLAMA_MODEL="${OLLAMA_EMBED_MODEL:-nomic-embed-text}"
OLLAMA_FALLBACK_MODEL="${OLLAMA_EMBED_FALLBACK:-all-minilm:latest}"

# Embedding storage
EMBED_DIR="$RON_CACHE_DIR/embeddings"
EMBED_INDEX_FILE="$EMBED_DIR/index.json"

# Ensure embed dir exists
mkdir -p "$EMBED_DIR"

# ─────────────────────────────────────────────
# Check if Ollama is available
# ─────────────────────────────────────────────
check_ollama() {
    if curl -s --max-time 3 "$OLLAMA_HOST/api/tags" > /dev/null 2>&1; then
        echo "ollama_available"
    elif curl -s --max-time 3 http://localhost:11434/api/tags > /dev/null 2>&1; then
        OLLAMA_HOST="http://localhost:11434"
        echo "ollama_available"
    else
        echo "ollama_unavailable"
    fi
}

# ─────────────────────────────────────────────
# Generate embedding for text using Ollama
# Returns: base64-encoded float array (space-separated in JSON)
# ─────────────────────────────────────────────
generate_embedding() {
    local text="$1"
    local model="${2:-$OLLAMA_MODEL}"
    
    local response
    response=$(curl -s --max-time 30 "$OLLAMA_HOST/api/embeddings" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$model\",\"prompt\":\"$text\"}")
    
    if echo "$response" | jq -e '.embedding' > /dev/null 2>&1; then
        echo "$response" | jq -r '.embedding | @base64'
    else
        # Try with chat endpoint as fallback
        response=$(curl -s --max-time 30 "$OLLAMA_HOST/api/chat" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Embed: $text\"}]}")
        echo "$response" | jq -r '.message.content' 2>/dev/null | head -1 || echo "ERROR"
    fi
}

# ─────────────────────────────────────────────
# Decode base64 embedding back to JSON array
# ─────────────────────────────────────────────
decode_embedding() {
    local b64="$1"
    echo "$b64" | base64 -d 2>/dev/null | jq -c '.' 2>/dev/null || echo "null"
}

# ─────────────────────────────────────────────
# Compute cosine similarity between two vectors
# Both inputs: JSON arrays of floats
# ─────────────────────────────────────────────
cosine_similarity() {
    local vec1="$1"
    local vec2="$2"
    
    # Use jq for vector math
    local dot_product norm1 norm2 similarity
    dot_product=$(echo "$vec1" "$vec2" | jq -s 'transpose | map($[0] * $[1]) | add')
    norm1=$(echo "$vec1" | jq 'map(. * .) | add | sqrt')
    norm2=$(echo "$vec2" | jq 'map(. * .) | add | sqrt')
    
    if [ "$(echo "$norm1 > 0 and $norm2 > 0" | bc)" = "1" ]; then
        similarity=$(echo "scale=6; $dot_product / ($norm1 * $norm2)" | bc)
        echo "$similarity"
    else
        echo "0"
    fi
}

# ─────────────────────────────────────────────
# Save embedding to Redis and local index
# ─────────────────────────────────────────────
save_embedding() {
    local key="$1"
    local text="$2"
    local embedding_b64="$3"
    
    # Save to Redis if credentials available
    if [ -n "$UPSTASH_REDIS_URL" ] && [ -n "$UPSTASH_REDIS_TOKEN" ]; then
        curl -s -X POST "$UPSTASH_REDIS_URL" \
            -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"command\":\"SET\",\"args\":[\"embedding:$key\",\"$embedding_b64\",\"EX\",\"7776000\"]}" \
            > /dev/null 2>&1 || true
    fi
    
    # Save to local index (JSON file with key → embedding mapping)
    local index
    if [ -f "$EMBED_INDEX_FILE" ]; then
        index=$(cat "$EMBED_INDEX_FILE")
    else
        index="{}"
    fi
    
    # Update index with new embedding
    index=$(echo "$index" | jq --arg k "$key" --arg v "$embedding_b64" '.[$k] = $v')
    echo "$index" > "$EMBED_INDEX_FILE"
}

# ─────────────────────────────────────────────
# Remove embedding from Redis and local index
# ─────────────────────────────────────────────
remove_embedding() {
    local key="$1"
    
    # Remove from Redis
    if [ -n "$UPSTASH_REDIS_URL" ] && [ -n "$UPSTASH_REDIS_TOKEN" ]; then
        curl -s -X POST "$UPSTASH_REDIS_URL" \
            -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"command\":\"DEL\",\"args\":[\"embedding:$key\"]}" \
            > /dev/null 2>&1 || true
    fi
    
    # Remove from local index
    if [ -f "$EMBED_INDEX_FILE" ]; then
        local index
        index=$(cat "$EMBED_INDEX_FILE")
        index=$(echo "$index" | jq --arg k "$key" 'del(.[$k])')
        echo "$index" > "$EMBED_INDEX_FILE"
    fi
}

# ─────────────────────────────────────────────
# Get embedding for a key from local index
# ─────────────────────────────────────────────
get_embedding() {
    local key="$1"
    
    if [ -f "$EMBED_INDEX_FILE" ]; then
        local b64
        b64=$(cat "$EMBED_INDEX_FILE" | jq -r --arg k "$key" '.[$k] // empty')
        if [ -n "$b64" ] && [ "$b64" != "null" ]; then
            echo "$b64"
            return 0
        fi
    fi
    
    return 1
}

# ─────────────────────────────────────────────
# Get all indexed keys and their embeddings
# ─────────────────────────────────────────────
get_all_indexed() {
    if [ -f "$EMBED_INDEX_FILE" ]; then
        cat "$EMBED_INDEX_FILE" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"'
    fi
}

# ─────────────────────────────────────────────
# Command: embed — generate and save embedding for text
# ─────────────────────────────────────────────
cmd_embed() {
    local text="$1"
    
    if [ -z "$text" ]; then
        echo "Usage: memory-embed.sh embed \"<text>\""
        exit 1
    fi
    
    local status
    status=$(check_ollama)
    
    if [ "$status" = "ollama_unavailable" ]; then
        echo "ERROR: Ollama not available at $OLLAMA_HOST or localhost:11434"
        echo "       Falling back to keyword-only search (use memory-search.sh without --embed)"
        exit 1
    fi
    
    echo "Generating embedding via Ollama at $OLLAMA_HOST..."
    
    local embedding_b64
    embedding_b64=$(generate_embedding "$text")
    
    if [ "$embedding_b64" = "ERROR" ] || [ -z "$embedding_b64" ]; then
        echo "ERROR: Failed to generate embedding"
        exit 1
    fi
    
    echo "Embedding generated: ${embedding_b64:0:40}..."
    echo "$embedding_b64"
}

# ─────────────────────────────────────────────
# Command: embed-key — embed a specific memory by key
# ─────────────────────────────────────────────
cmd_embed_key() {
    local mem_key="$1"
    
    if [ -z "$mem_key" ]; then
        echo "Usage: memory-embed.sh embed-key <memory-key>"
        exit 1
    fi
    
    # Get memory value from Redis or cache
    local text
    text=$("$SCRIPT_DIR/memory-get.sh" "$mem_key" 2>/dev/null | head -1 || echo "")
    
    if [ -z "$text" ]; then
        echo "ERROR: Memory key not found: $mem_key"
        exit 1
    fi
    
    local status
    status=$(check_ollama)
    
    if [ "$status" = "ollama_unavailable" ]; then
        echo "ERROR: Ollama not available"
        exit 1
    fi
    
    echo "Embedding memory: $mem_key"
    local embedding_b64
    embedding_b64=$(generate_embedding "$text")
    
    if [ "$embedding_b64" = "ERROR" ] || [ -z "$embedding_b64" ]; then
        echo "ERROR: Failed to generate embedding"
        exit 1
    fi
    
    save_embedding "$mem_key" "$text" "$embedding_b64"
    echo "Saved embedding for: $mem_key"
}

# ─────────────────────────────────────────────
# Command: remove-key — remove embedding for a key
# ─────────────────────────────────────────────
cmd_remove_key() {
    local mem_key="$1"
    
    if [ -z "$mem_key" ]; then
        echo "Usage: memory-embed.sh remove-key <memory-key>"
        exit 1
    fi
    
    remove_embedding "$mem_key"
    echo "Removed embedding for: $mem_key"
}

# ─────────────────────────────────────────────
# Command: search — find similar memories using vector search
# ─────────────────────────────────────────────
cmd_search() {
    local query="$1"
    local top_n="${2:-5}"
    
    if [ -z "$query" ]; then
        echo "Usage: memory-embed.sh search \"<text>\" [N]"
        exit 1
    fi
    
    local status
    status=$(check_ollama)
    
    if [ "$status" = "ollama_unavailable" ]; then
        echo "ERROR: Ollama not available. Cannot perform vector search."
        echo "       Use memory-search.sh for keyword-only search."
        exit 1
    fi
    
    if [ ! -f "$EMBED_INDEX_FILE" ]; then
        echo "No embedding index found. Run: memory-embed.sh index --rebuild"
        exit 1
    fi
    
    echo "Generating query embedding..."
    local query_b64
    query_b64=$(generate_embedding "$query")
    
    if [ "$query_b64" = "ERROR" ] || [ -z "$query_b64" ]; then
        echo "ERROR: Failed to generate query embedding"
        exit 1
    fi
    
    local query_vec
    query_vec=$(decode_embedding "$query_b64")
    
    if [ "$query_vec" = "null" ] || [ -z "$query_vec" ]; then
        echo "ERROR: Failed to decode query embedding"
        exit 1
    fi
    
    echo "Computing similarity against $(cat "$EMBED_INDEX_FILE" | jq 'length') indexed memories..."
    
    # Score all indexed memories
    local results=""
    local best_score=0
    local best_key=""
    
    while IFS='=' read -r key emb_b64; do
        [ -z "$key" ] && continue
        
        local emb_vec
        emb_vec=$(decode_embedding "$emb_b64")
        [ "$emb_vec" = "null" ] || [ -z "$emb_vec" ] && continue
        
        local score
        score=$(cosine_similarity "$query_vec" "$emb_vec")
        
        results="$results$key\t$score\n"
        
        # Track best
        local cmp
        cmp=$(echo "scale=6; $score > $best_score" | bc)
        if [ "$cmp" = "1" ]; then
            best_score=$score
            best_key=$key
        fi
    done <<< "$(get_all_indexed)"
    
    if [ -z "$results" ]; then
        echo "No similar memories found."
        exit 0
    fi
    
    # Sort by score descending and show top N
    echo "$results" | sort -t$'\t' -k2 -nr | head -"$top_n" | while IFS=$'\t' read -r key score; do
        [ -z "$key" ] && continue
        # Fetch the actual memory value for context
        local mem_val
        mem_val=$("$SCRIPT_DIR/memory-get.sh" "$key" 2>/dev/null | head -c 200 || echo "(not found)")
        echo "[score: $score] $key"
        echo "  -> $mem_val"
    done
}

# ─────────────────────────────────────────────
# Command: index — rebuild embedding index
# ─────────────────────────────────────────────
cmd_index() {
    local rebuild="${1:-}"
    
    local status
    status=$(check_ollama)
    
    if [ "$status" = "ollama_unavailable" ]; then
        echo "ERROR: Ollama not available. Cannot build embedding index."
        exit 1
    fi
    
    echo "Rebuilding embedding index..."
    
    if [ "$rebuild" = "--rebuild" ]; then
        echo "Clearing existing index..."
        rm -f "$EMBED_INDEX_FILE"
    fi
    
    # Get all memory keys from Redis
    local keys
    if [ -n "$UPSTASH_REDIS_URL" ] && [ -n "$UPSTASH_REDIS_TOKEN" ]; then
        keys=$(curl -s -X POST "$UPSTASH_REDIS_URL" \
            -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"command":"KEYS","args":["*"]}' | jq -r '.[]' 2>/dev/null || echo "")
    fi
    
    if [ -z "$keys" ]; then
        echo "No Redis keys found."
        exit 0
    fi
    
    local count=0
    local errors=0
    
    for key in $keys; do
        # Skip already indexed or non-memory keys
        if [ "${key:0:10}" = "embedding:" ]; then
            continue
        fi
        
        # Check if already indexed
        if [ -f "$EMBED_INDEX_FILE" ] && [ -n "$(cat "$EMBED_INDEX_FILE" | jq -r --arg k "$key" '.[$k] // empty')" ]; then
            continue
        fi
        
        # Get memory value
        local val
        val=$(curl -s -X POST "$UPSTASH_REDIS_URL" \
            -H "Authorization: Bearer $UPSTASH_REDIS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"command\":\"GET\",\"args\":[\"$key\"]}" | jq -r '.[]' 2>/dev/null || echo "")
        
        if [ -z "$val" ] || [ "$val" = "null" ]; then
            continue
        fi
        
        echo -n "Embedding $key... "
        
        local emb
        emb=$(generate_embedding "$val")
        
        if [ "$emb" = "ERROR" ] || [ -z "$emb" ]; then
            echo "FAILED"
            errors=$((errors + 1))
            continue
        fi
        
        save_embedding "$key" "$val" "$emb"
        echo "OK"
        count=$((count + 1))
        
        # Rate limit to avoid overwhelming Ollama
        sleep 0.2
    done
    
    echo ""
    echo "Index rebuild complete: $count indexed, $errors errors"
}

# ─────────────────────────────────────────────
# Command: status — show embedding index status
# ─────────────────────────────────────────────
cmd_status() {
    echo "=== Ollama Embedding Status ==="
    
    local status
    status=$(check_ollama)
    
    echo "Ollama: $status"
    echo "Endpoint: $OLLAMA_HOST"
    echo "Model: $OLLAMA_MODEL"
    
    if [ -f "$EMBED_INDEX_FILE" ]; then
        local count
        count=$(cat "$EMBED_INDEX_FILE" | jq 'length')
        echo "Indexed memories: $count"
        
        # Show some indexed keys
        echo ""
        echo "Sample indexed keys:"
        cat "$EMBED_INDEX_FILE" | jq -r 'keys | .[0:10] | .[]' 2>/dev/null | while read -r k; do
            echo "  - $k"
        done
    else
        echo "Indexed memories: 0 (no index file)"
    fi
    
    echo ""
    echo "Index file: $EMBED_INDEX_FILE"
    echo "Run 'memory-embed.sh index --rebuild' to build the index"
}

# ─────────────────────────────────────────────
# Main dispatcher
# ─────────────────────────────────────────────
COMMAND="${1:-}"

case "$COMMAND" in
    embed)
        cmd_embed "$2"
        ;;
    embed-key)
        cmd_embed_key "$2"
        ;;
    remove-key)
        cmd_remove_key "$2"
        ;;
    search)
        cmd_search "$2" "$3"
        ;;
    index)
        cmd_index "$2"
        ;;
    status)
        cmd_status
        ;;
    "")
        echo "memory-embed.sh — Ollama embedding support for ron-memory"
        echo ""
        echo "Usage:"
        echo "  memory-embed.sh embed \"<text>\"        Generate embedding for text"
        echo "  memory-embed.sh search \"<text>\" [N]    Find similar memories (default top 5)"
        echo "  memory-embed.sh index [--rebuild]      Rebuild index from all memories"
        echo "  memory-embed.sh embed-key <key>        Embed a specific memory by key"
        echo "  memory-embed.sh remove-key <key>       Remove embedding for a key"
        echo "  memory-embed.sh status                 Show index status"
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Run without args to see usage."
        exit 1
        ;;
esac