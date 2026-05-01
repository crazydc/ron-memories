#!/bin/bash
# Ron Memory - Configuration Loader

load_config() {
    # Priority: environment variables > .env file > examples
    # This allows override via env vars for testing
    
    # Only load from file if env vars not already set
    if [ -z "$UPSTASH_REDIS_URL" ] && [ -z "$UPSTASH_REDIS_REST_URL" ]; then
        if [ -n "$HOME" ] && [ -f "$HOME/.openclaw/.env.ron-memory" ]; then
            . "$HOME/.openclaw/.env.ron-memory"
        elif [ -f "/root/.openclaw/.env.ron-memory" ]; then
            . "/root/.openclaw/.env.ron-memory"
        elif [ -n "$OPENCLAW_WORKSPACE" ] && [ -f "$OPENCLAW_WORKSPACE/.env.ron-memory" ]; then
            . "$OPENCLAW_WORKSPACE/.env.ron-memory"
        elif [ -f "/root/.openclaw/workspace/.env.ron-memory" ]; then
            . "/root/.openclaw/workspace/.env.ron-memory"
        fi
    fi
    
    # Set REDIS_URL from env if present
    if [ -n "$UPSTASH_REDIS_URL" ]; then
        REDIS_URL="$UPSTASH_REDIS_URL"
    elif [ -n "$UPSTASH_REDIS_REST_URL" ]; then
        REDIS_URL="$UPSTASH_REDIS_REST_URL"
    fi
    
    # Set REDIS_TOKEN from env if present  
    if [ -n "$UPSTASH_REDIS_TOKEN" ]; then
        REDIS_TOKEN="$UPSTASH_REDIS_TOKEN"
    elif [ -n "$UPSTASH_REDIS_REST_TOKEN" ]; then
        REDIS_TOKEN="$UPSTASH_REDIS_REST_TOKEN"
    fi
    
    if [ -z "$REDIS_URL" ] || [ -z "$REDIS_TOKEN" ]; then
        echo "ERROR: Redis credentials not found."
        echo "Set UPSTASH_REDIS_URL and UPSTASH_REDIS_TOKEN, or create .env.ron-memory"
        exit 1
    fi
    
    # Local cache location
    if [ -n "$OPENCLAW_WORKSPACE" ]; then
        MEMORY_DIR="$OPENCLAW_WORKSPACE/memory"
    elif [ -n "$HOME" ]; then
        MEMORY_DIR="$HOME/.openclaw/workspace/memory"
    else
        MEMORY_DIR="/root/.openclaw/workspace/memory"
    fi
    MEMORY_FILE="${RON_MEMORY_FILE:-$MEMORY_DIR/ron-memory.md}"
    
    # Ensure directory exists
    mkdir -p "$MEMORY_DIR"
}

load_config