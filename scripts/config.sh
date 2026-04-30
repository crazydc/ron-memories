#!/bin/bash
# Ron Memory - Configuration Loader

# Load credentials from env file or environment
load_config() {
    # Check for env file in multiple locations (in order of priority)
    for env_file in \
        "$HOME/.openclaw/.env.ron-memory" \
        "/root/.openclaw/workspace/.env.ron-memory" \
        "$(dirname "${BASH_SOURCE[0]}")/../../.env.ron-memory" \
        "$(dirname "${BASH_SOURCE[0]}")/../../../.env.ron-memory"; do
        if [ -f "$env_file" ]; then
            source "$env_file"
            break
        fi
    done
    
    # Fall back to environment variables
    REDIS_URL="${UPSTASH_REDIS_URL:-${UPSTASH_REDIS_REST_URL}}"
    REDIS_TOKEN="${UPSTASH_REDIS_TOKEN:-${UPSTASH_REDIS_REST_TOKEN}}"
    
    if [ -z "$REDIS_URL" ] || [ -z "$REDIS_TOKEN" ]; then
        echo "ERROR: Redis credentials not found."
        echo "Set UPSTASH_REDIS_URL and UPSTASH_REDIS_TOKEN, or create .env.ron-memory"
        exit 1
    fi
    
    # Local cache file - default to workspace memory folder
    MEMORY_DIR="${HOME}/.openclaw/workspace/memory"
    MEMORY_FILE="${RON_MEMORY_FILE:-$MEMORY_DIR/ron-memory.md}"
    MEMORY_DIR="$(dirname "$MEMORY_FILE")"
    
    # Ensure directory exists
    mkdir -p "$MEMORY_DIR"
}

# Call load_config on sourced
load_config