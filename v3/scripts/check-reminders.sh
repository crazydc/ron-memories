#!/bin/bash
# check-reminders.sh — Check due reminders, output to stdout
# Designed for cron (every 5 min), not heartbeat

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DUE_COUNT=0

# Get all reminder keys
KEYS_JSON=$(curl -s "$URL/keys/ron:reminder:*" -H "Authorization: Bearer $TOKEN" 2>/dev/null)

if [ -z "$KEYS_JSON" ] || echo "$KEYS_JSON" | grep -q '"result":null'; then
    exit 0
fi

# Parse reminder keys
KEYS=$(echo "$KEYS_JSON" | python3 -c "
import sys, json
keys = json.loads(sys.stdin.read()).get('result', [])
for k in keys:
    print(k)
" 2>/dev/null || echo "")

# Check each reminder
while IFS= read -r key; do
    [ -z "$key" ] && continue
    
    # Get reminder data
    DATA_JSON=$(curl -s "$URL/get/$key" -H "Authorization: Bearer $TOKEN")
    
    # Parse: {"result": "{\"value\": \"...\", \"timestamp\": \"...\", \"due\": \"...\"}"}
    RESULT=$(echo "$DATA_JSON" | python3 -c "
import sys, json, sys
from datetime import datetime
d = json.loads(sys.stdin.read())
inner = json.loads(d.get('result', '{}'))
v = inner.get('value', '')
due = inner.get('due', '')
ts = inner.get('timestamp', '')
print(f'{v}|{due}|{ts}')
" 2>/dev/null || echo "")
    
    [ -z "$RESULT" ] && continue
    
    VALUE="${RESULT%%|*}"
    REST="${RESULT#*|}"
    DUE="${REST%%|*}"
    TS="${REST##*|}"
    
    # Check if due
    if [ -n "$DUE" ] && [ "$DUE" != "None" ]; then
        # Simple comparison (ISO format)
        if [[ "$DUE" < "$NOW" ]]; then
            SHORT_KEY="${key#ron:reminder:}"
            echo "🔔 REMINDER: $VALUE"
            echo "   Key: $SHORT_KEY"
            echo "   Due: $DUE"
            echo "   Created: $TS"
            echo ""
            DUE_COUNT=$((DUE_COUNT + 1))
        fi
    fi
done <<< "$KEYS"

# Log summary
if [ $DUE_COUNT -gt 0 ]; then
    echo "[$(date)] Found $DUE_COUNT due reminder(s)" >&2
fi

exit 0
