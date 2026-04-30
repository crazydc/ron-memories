#!/bin/bash
# Ron Memory - Configuration Loader

load_config() {
    # Find workspace
    WORKSPACE=""
    if [ -n "$OPENCLAW_WORKSPACE" ]; then
        WORKSPACE="$OPENCLAW_WORKSPACE"
    elif [ -n "$HOME" ]; then
        WORKSPACE="$HOME/.openclaw/workspace"
    fi
    
    # Check for env file in multiple locations
    if [ -n "$WORKSPACE" ] && [ -f "$WORKSPACE/.env.ron-memory" ]; then
        . "$WORKSPACE/.env.ron-memory"
    elif [ -n "$HOME" ] && [ -f "$HOME/.openclaw/.env.ron-memory" ]; then
        . "$HOME/.openclaw/.env.ron-memory"
    elif [ -f "/root/.openclaw/workspace/.env.ron-memory" ]; then
        . "/root/.openclaw/workspace/.env.ron-memory"
    fi
    
    # Fall back to environment variables
    if [ -z "$REDIS_URL" ] && [ -n "$UPSTASH_REDIS_URL" ]; then
        REDIS_URL="$UPSTASH_REDIS_URL"
    fi
    if [ -z "$REDIS_TOKEN" ] && [ -n "$UPSTASH_REDIS_TOKEN" ]; then
        REDIS_TOKEN="$UPSTASH_REDIS_TOKEN"
    fi
    
    if [ -z "$REDIS_URL" ] || [ -z "$REDIS_TOKEN" ]; then
        echo "ERROR: Redis credentials not found."
        echo "Set UPSTASH_REDIS_URL and UPSTASH_REDIS_TOKEN, or create .env.ron-memory"
        exit 1
    fi
    
    # Local cache location
    if [ -n "$WORKSPACE" ]; then
        MEMORY_DIR="$WORKSPACE/memory"
    else
        MEMORY_DIR="$HOME/.openclaw/workspace/memory"
    fi
    MEMORY_FILE="${RON_MEMORY_FILE:-$MEMORY_DIR/ron-memory.md}"
    
    # Ensure directory exists
    mkdir -p "$MEMORY_DIR"
}

load_config