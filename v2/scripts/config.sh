#!/bin/bash
# ron-memory v2 - Configuration
# TTL defaults per namespace (in days, 0 = permanent)
# Also defines archive behavior and summarization thresholds

# Storage paths
RON_CACHE_DIR="${RON_CACHE_DIR:-$HOME/.openclaw/workspace/memory}"
RON_CACHE_FILE="$RON_CACHE_DIR/ron-memory.md"
RON_ARCHIVE_DIR="$RON_CACHE_DIR/archive"

# Upstash Redis (required)
UPSTASH_REDIS_URL="${UPSTASH_REDIS_URL:-}"
UPSTASH_REDIS_TOKEN="${UPSTASH_REDIS_TOKEN:-}"

# Source credentials from .env.ron-memory if it exists
if [ -f "$HOME/workspace/.env.ron-memory" ]; then
    source "$HOME/workspace/.env.ron-memory"
fi

# TTL defaults per namespace (in days, 0 = permanent)
declare -A NAMESPACE_TTL=(
    ["user"]=0
    ["family"]=0
    ["contact"]=0
    ["vehicle"]=0
    ["project"]=0
    ["goal"]=0
    ["pref"]=30
    ["service"]=90
    ["agent"]=0
    ["book"]=0
    ["career"]=0
    ["reminder"]=7
    ["working"]=1
    ["archive"]=0
)

# Summarization threshold (characters before compression)
SUMMARIZE_THRESHOLD=500

# Cold storage: entries older than this (days) → archive
COLD_STORAGE_DAYS=90

# Maximum entries returned by memory-rank
RANK_MAX_ENTRIES=20

# Token budget for ranked retrieval (rough estimate: 1 token ≈ 4 chars)
RANK_TOKEN_BUDGET=2000
