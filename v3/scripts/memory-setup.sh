#!/bin/bash
# memory-setup.sh — Interactive setup for Ron-Memory v3
# Run this once to configure your Redis credentials and cron jobs
#
# Usage:
#   ./memory-setup.sh           # Interactive Q&A
#   ./memory-setup.sh --non-interactive  # CI/scripted (uses existing config or fails)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V3_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="${HOME}/.openclaw/workspace"
ENV_FILE="${HOME}/.openclaw/.env.ron-memory"
CACHE_DIR="${WORKSPACE_DIR}/memory"
CACHE_FILE="${CACHE_DIR}/ron-memory.md"
NON_INTERACTIVE=false

# Parse flags
for arg in "$@"; do
    case $arg in
        --non-interactive)
            NON_INTERACTIVE=true
            ;;
        -h|--help)
            echo "Usage: $0 [--non-interactive]"
            echo "  --non-interactive  Run in CI mode (use existing config or fail)"
            exit 0
            ;;
    esac
done

# Colors (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
step()    { echo -e "${BOLD}[STEP]${NC} $1"; }

# -----------------------------------------------------------------------------
# STEP 0: Welcome
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║           Ron-Memory v3 Interactive Setup                    ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "This script will help you set up Ron-Memory v3."
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Check/Configure Redis credentials
# -----------------------------------------------------------------------------
step "1/5 — Redis Credentials"
echo ""

# Source existing credentials if they exist
REDIS_URL=""
REDIS_TOKEN=""

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    if [ -n "$UPSTASH_REDIS_URL" ] && [ -n "$UPSTASH_REDIS_TOKEN" ]; then
        REDIS_URL="$UPSTASH_REDIS_URL"
        REDIS_TOKEN="$UPSTASH_REDIS_TOKEN"
        success "Found existing config at $ENV_FILE"
        info "URL: $REDIS_URL"
    fi
elif [ -f "${WORKSPACE_DIR}/.env.ron-memory" ]; then
    source "${WORKSPACE_DIR}/.env.ron-memory"
    if [ -n "$UPSTASH_REDIS_URL" ] && [ -n "$UPSTASH_REDIS_TOKEN" ]; then
        REDIS_URL="$UPSTASH_REDIS_URL"
        REDIS_TOKEN="$UPSTASH_REDIS_TOKEN"
        success "Found existing config at ${WORKSPACE_DIR}/.env.ron-memory"
        info "URL: $REDIS_URL"
    fi
fi

# If non-interactive and no config found, fail
if [ "$NON_INTERACTIVE" = true ] && [ -z "$REDIS_URL" ]; then
    error "No .env.ron-memory found and --non-interactive was set."
    error "Please create ${ENV_FILE} with UPSTASH_REDIS_URL and UPSTASH_REDIS_TOKEN"
    exit 1
fi

# Ask for credentials if not found
if [ -z "$REDIS_URL" ]; then
    echo "Let's set up your Upstash Redis credentials."
    echo ""
    
    if [ "$NON_INTERACTIVE" = true ]; then
        error "Redis credentials required but --non-interactive is set. Please set UPSTASH_REDIS_URL and UPSTASH_REDIS_TOKEN in ${ENV_FILE}"
        exit 1
    fi
    
    echo -n "  Enter REDIS_URL (e.g. https://your-redis.upstash.io): "
    read -r REDIS_URL
    
    echo -n "  Enter REDIS_TOKEN: "
    read -r REDIS_TOKEN
    
    echo ""
fi

# Trim whitespace
REDIS_URL=$(echo "$REDIS_URL" | tr -d '[:space:]')
REDIS_TOKEN=$(echo "$REDIS_TOKEN" | tr -d '[:space:]')

if [ -z "$REDIS_URL" ] || [ -z "$REDIS_TOKEN" ]; then
    error "REDIS_URL and REDIS_TOKEN are required."
    echo "  Create ${ENV_FILE} with:"
    echo "    UPSTASH_REDIS_URL=https://your-redis.upstash.io"
    echo "    UPSTASH_REDIS_TOKEN=your-token-here"
    exit 1
fi

# Save to .env.ron-memory if new/changed
if [ ! -f "$ENV_FILE" ]; then
    mkdir -p "$(dirname "$ENV_FILE")"
    cat > "$ENV_FILE" << EOF
# Ron Memory - Upstash Configuration
# Generated: $(date +%Y-%m-%d)
UPSTASH_REDIS_URL=$REDIS_URL
UPSTASH_REDIS_TOKEN=$REDIS_TOKEN
EOF
    success "Saved credentials to $ENV_FILE"
else
    # Update existing file
    if ! grep -q "UPSTASH_REDIS_URL=$REDIS_URL" "$ENV_FILE" || ! grep -q "UPSTASH_REDIS_TOKEN=$REDIS_TOKEN" "$ENV_FILE"; then
        sed -i "s|UPSTASH_REDIS_URL=.*|UPSTASH_REDIS_URL=$REDIS_URL|" "$ENV_FILE"
        sed -i "s|UPSTASH_REDIS_TOKEN=.*|UPSTASH_REDIS_TOKEN=$REDIS_TOKEN|" "$ENV_FILE"
        success "Updated credentials in $ENV_FILE"
    fi
fi

# Validate by pinging Redis
info "Validating Redis connection..."
PING_RESULT=$(curl -s -X GET "$REDIS_URL/ping" -H "Authorization: Bearer $REDIS_TOKEN" 2>/dev/null || echo "FAILED")

if echo "$PING_RESULT" | grep -qi "PONG\|pong"; then
    success "Redis connection verified!"
elif echo "$PING_RESULT" | grep -qi "error\|AUTH"; then
    error "Redis authentication failed. Please check your token."
    exit 1
else
    # Try a keys query as alternative ping
    KEYS_RESULT=$(curl -s "$REDIS_URL/keys/ron:*" -H "Authorization: Bearer $REDIS_TOKEN" 2>/dev/null || echo "FAILED")
    if echo "$KEYS_RESULT" | grep -q '"result"'; then
        success "Redis connection verified (via keys query)!"
    else
        warn "Could not verify Redis connection. Please check your URL and token."
        warn "Result: $PING_RESULT"
    fi
fi

echo ""

# -----------------------------------------------------------------------------
# STEP 2: Cron setup for reminders
# -----------------------------------------------------------------------------
step "2/5 — Reminder Cron"
echo ""

CRON_ENTRY="*/5 * * * * bash ${V3_DIR}/scripts/check-reminders.sh >> /var/log/ron-reminders.log 2>&1"
CRON_MARKER="# RON-MEMORY-REMINDERS"

# Check if cron is already set up
if crontab -l 2>/dev/null | grep -q "$CRON_MARKER"; then
    success "Reminder cron already configured."
elif crontab -l 2>/dev/null | grep -q "check-reminders.sh"; then
    success "Reminder cron already configured (legacy check).";
else
    warn "Reminder cron is NOT configured."
    echo ""
    
    if [ "$NON_INTERACTIVE" = true ]; then
        info "Skipping cron setup in non-interactive mode."
        info "To enable reminders, add this to your crontab:"
        echo "  $CRON_ENTRY"
    else
        echo "  Reminders run on a 5-minute cron interval."
        echo "  Without this, reminders will only fire during heartbeats."
        echo ""
        echo -n "  Add reminder cron now? [Y/n]: "
        read -r ADD_CRON
        echo ""
        
        if [ "$ADD_CRON" != "n" ] && [ "$ADD_CRON" != "N" ]; then
            # Append to crontab
            (crontab -l 2>/dev/null || true) | grep -v "check-reminders.sh" | crontab -
            (crontab -l 2>/dev/null || true; echo "") | crontab -
            (crontab -l 2>/dev/null || true; echo "$CRON_MARKER $CRON_ENTRY") | crontab -
            success "Added reminder cron!"
        else
            info "Skipped. You can add it later with: crontab -e"
            info "Entry: $CRON_ENTRY"
        fi
    fi
fi

echo ""

# -----------------------------------------------------------------------------
# STEP 3: Workspace paths
# -----------------------------------------------------------------------------
step "3/5 — Workspace Paths"
echo ""

MISSING_PATHS=0

# Check cache directory
if [ ! -d "$CACHE_DIR" ]; then
    warn "Cache directory missing: $CACHE_DIR"
    info "Creating..."
    mkdir -p "$CACHE_DIR"
    success "Created $CACHE_DIR"
else
    success "Cache directory exists: $CACHE_DIR"
fi

# Check cache file
if [ ! -f "$CACHE_FILE" ]; then
    warn "Cache file missing: $CACHE_FILE"
    info "Creating..."
    touch "$CACHE_FILE"
    success "Created $CACHE_FILE"
else
    success "Cache file exists: $CACHE_FILE"
fi

# Ensure .dreams subdirectory exists (used by some features)
if [ ! -d "$CACHE_DIR/.dreams" ]; then
    mkdir -p "$CACHE_DIR/.dreams"
    success "Created $CACHE_DIR/.dreams"
fi

echo ""

# -----------------------------------------------------------------------------
# STEP 4: Run healthcheck
# -----------------------------------------------------------------------------
step "4/5 — Health Check"
echo ""

# Source our env for the healthcheck script
export UPSTASH_REDIS_URL="$REDIS_URL"
export UPSTASH_REDIS_TOKEN="$REDIS_TOKEN"

bash "${SCRIPT_DIR}/memory-healthcheck.sh"
HEALTHCHECK_RESULT=$?

echo ""

# -----------------------------------------------------------------------------
# STEP 5: Summary
# -----------------------------------------------------------------------------
step "5/5 — Summary"
echo ""

if [ $HEALTHCHECK_RESULT -eq 0 ]; then
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                    Setup Complete!                          ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    success "Ron-Memory v3 is ready to use."
    echo ""
    echo "Next steps:"
    echo "  • Save a memory:   ${SCRIPT_DIR}/memory-set.sh user:name Alex"
    echo "  • Get a memory:    ${SCRIPT_DIR}/memory-get.sh user:name"
    echo "  • List all:        ${SCRIPT_DIR}/memory-list.sh"
    echo "  • Rank for task:   ${SCRIPT_DIR}/memory-rank.sh \"my task context\""
    echo ""
    echo "Documentation:"
    echo "  • ${V3_DIR}/README.md"
    echo "  • ${V3_DIR}/INSTALLATION_GUIDE.md"
    echo ""
    echo "Happy remembering! 🧠"
else
    warn "Health check had issues. Please review the output above."
    echo ""
    echo "Common fixes:"
    echo "  • Check your Redis URL and token in $ENV_FILE"
    echo "  • Verify Redis instance is active at upstash.com"
    echo "  • Run this script again: ${SCRIPT_DIR}/memory-setup.sh"
    exit 1
fi

exit 0