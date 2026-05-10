#!/bin/bash
# memory-cleanup.sh v3 — Bulk cleanup of test/system entries
# Removes old test entries and optionally entries older than N days

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Upstash Redis (inline for portability)
TOKEN="${UPSTASH_REDIS_TOKEN:-gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw}"
URL="${UPSTASH_REDIS_URL:-https://summary-hare-109926.upstash.io}"

# Namespaces that are SAFE to clean (test/system)
SAFE_NAMESPACES="health ron"

# Namespaces that are NEVER cleaned (user data)
PROTECTED_NAMESPACES="user family story contact vehicle project goal pref reminder reinforce archive"

usage() {
    cat << EOF
Usage: memory-cleanup.sh [--dry-run] [--force] [--keep-days N]

Bulk cleanup of old test/system entries from Ron-Memory v3.

Options:
  --dry-run      Preview what would be deleted (default)
  --force        Actually delete matching entries
  --keep-days N  Also delete entries older than N days (any namespace)
  --help         Show this help

Patterns deleted in --force mode:
  - ron:health:1777* (timestamp entries from 2026-05-02 testing)
  - ron:test:* (ron namespace test keys)
  - ron:jeff:test:* (jeff-specific test keys)
  - ron:health:test:* (health test entries)
  - testkey (legacy test key)

Protected namespaces (never deleted):
  user, family, story, contact, vehicle, project, goal, pref,
  reminder, reinforce, archive

Examples:
  # Preview what would be deleted
  memory-cleanup.sh

  # Actually delete the test entries
  memory-cleanup.sh --force

  # Delete entries older than 30 days (any namespace except protected)
  memory-cleanup.sh --keep-days 30 --force
EOF
}

DRY_RUN=true
KEEP_DAYS=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --force) DRY_RUN=false; shift ;;
        --keep-days)
            KEEP_DAYS="$2"
            if ! [[ "$KEEP_DAYS" =~ ^[0-9]+$ ]]; then
                echo "Error: --keep-days requires a number"
                exit 1
            fi
            shift 2
            ;;
        --help|-h) usage; exit 0 ;;
        *) shift ;;
    esac
done

echo "🧹 Ron-Memory v3 — Bulk Cleanup"
echo "==============================="
echo ""

# Check Redis connectivity first
KEYS_JSON=$(curl -s "$URL/keys/ron:*" -H "Authorization: Bearer $TOKEN" 2>/dev/null)
if [ -z "$KEYS_JSON" ]; then
    echo "❌ Cannot connect to Redis"
    exit 1
fi

count_deleted=0
count_skipped_protected=0

# Function to delete keys matching a pattern
delete_matching() {
    local pattern="$1"
    local description="$2"

    # Use SCAN to find keys matching pattern
    local keys_json
    keys_json=$(curl -s "$URL/keys/$pattern" -H "Authorization: Bearer $TOKEN" 2>/dev/null)

    if [ -z "$keys_json" ] || [ "$keys_json" = "null" ]; then
        return 0
    fi

    # Parse the keys array using python
    local keys_array
    keys_array=$(echo "$keys_json" | python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    keys = data.get('result', [])
    if isinstance(keys, list):
        for k in keys:
            print(k)
except:
    pass
" 2>/dev/null)

    if [ -z "$keys_array" ]; then
        return 0
    fi

    local match_count=0
    local to_delete=""

    while IFS= read -r key; do
        [ -z "$key" ] && continue

        # Security check: ensure key is in a safe namespace
        local ns
        ns="${key%%:*}"

        # Skip protected namespaces as a safety measure
        local is_protected=false
        for protected in $PROTECTED_NAMESPACES; do
            if [ "$ns" = "$protected" ]; then
                is_protected=true
                break
            fi
        done

        if [ "$is_protected" = true ]; then
            count_skipped_protected=$((count_skipped_protected + 1))
            continue
        fi

        to_delete="${to_delete}${key}"$'\n'
        match_count=$((match_count + 1))
    done <<< "$keys_array"

    if [ $match_count -eq 0 ]; then
        return 0
    fi

    echo "📋 Pattern: $pattern ($description)"
    echo "   Found: $match_count key(s)"

    if [ "$DRY_RUN" = true ]; then
        echo "$to_delete" | while IFS= read -r key; do
            [ -z "$key" ] && continue
            echo "   Would delete: $key"
        done
        count_deleted=$((count_deleted + match_count))
    else
        # Actually delete each key
        echo "$to_delete" | while IFS= read -r key; do
            [ -z "$key" ] && continue
            local delete_result
            delete_result=$(curl -s -X DELETE "$URL/del/$key" -H "Authorization: Bearer $TOKEN" 2>/dev/null)
            echo "   ✅ Deleted: $key"
        done
        count_deleted=$((count_deleted + match_count))
    fi
    echo ""
}

# Delete specific test patterns (v3 key format)
delete_matching "ron:health:1777*" "timestamp entries from 2026-05-02 testing"
delete_matching "ron:test:*" "ron test keys"
delete_matching "ron:jeff:test:*" "jeff-specific test keys"
delete_matching "ron:health:test:*" "health test entries"
delete_matching "testkey" "legacy test key"

# Handle --keep-days if specified
if [ "$KEEP_DAYS" -gt 0 ]; then
    echo "🗓️  Checking entries older than $KEEP_DAYS days..."
    echo ""

    NOW=$(date +%s)
    CUTOFF_EPOCH=$((NOW - (KEEP_DAYS * 86400)))

    # Scan ALL keys to check their timestamps
    all_keys_json=$(curl -s "$URL/keys/*" -H "Authorization: Bearer $TOKEN" 2>/dev/null)

    if [ -n "$all_keys_json" ] && [ "$all_keys_json" != "null" ]; then
        echo "$all_keys_json" | python3 -c "
import sys, json, subprocess
try:
    data = json.loads(sys.stdin.read())
    keys = data.get('result', [])
    if isinstance(keys, list):
        for key in keys:
            # Get the full key info
            import urllib.request
            req = urllib.request.Request(
                'https://summary-hare-109926.upstash.io/get/' + key,
                headers={'Authorization': 'Bearer gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'}
            )
            try:
                with urllib.request.urlopen(req, timeout=5) as resp:
                    d = json.loads(resp.read())
                    inner = json.loads(d.get('result', '{}'))
                    ts_str = inner.get('timestamp', '')
                    if ts_str:
                        # Parse ISO timestamp
                        from datetime import datetime
                        try:
                            dt = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                            epoch = int(dt.timestamp())
                            if epoch < $CUTOFF_EPOCH:
                                print(key + '|' + ts_str)
                        except:
                            pass
            except:
                pass
except:
    pass
" 2>/dev/null | while IFS='|' read -r key ts; do
            [ -z "$key" ] && continue

            # Double-check namespace protection
            ns="${key%%:*}"
            is_protected=false
            for protected in user family story contact vehicle project goal pref reminder reinforce archive; do
                if [ "$ns" = "$protected" ]; then
                    is_protected=true
                    break
                fi
            done

            if [ "$is_protected" = true ]; then
                continue
            fi

            if [ "$DRY_RUN" = true ]; then
                echo "   Would delete (age > ${KEEP_DAYS}d): $key (timestamp: $ts)"
            else
                delete_result=$(curl -s -X DELETE "$URL/del/$key" -H "Authorization: Bearer $TOKEN" 2>/dev/null)
                echo "   ✅ Deleted (age > ${KEEP_DAYS}d): $key"
            fi
            count_deleted=$((count_deleted + 1))
        done
    fi
    echo ""
fi

# Summary
echo "═══════════════════════════════════"
echo "Summary"
echo "═══════════════════════════════════"
echo "Total keys processed: $count_deleted"
if [ $count_skipped_protected -gt 0 ]; then
    echo "Protected keys skipped: $count_skipped_protected"
fi
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "ℹ️  This was a DRY RUN — no keys were actually deleted"
    echo "   Run with --force to actually delete"
else
    echo "✅ Cleanup complete — $count_deleted key(s) removed"
fi