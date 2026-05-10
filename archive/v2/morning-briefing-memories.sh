#!/bin/bash
# morning-briefing-memories.sh — Get new memories from last 24h for briefing

TOKEN='gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw'
URL='https://summary-hare-109926.upstash.io'

python3 << PYEOF
import subprocess, json
from datetime import datetime, timedelta

TOKEN = '$TOKEN'
URL = '$URL'

r = subprocess.run(['curl', '-s', f'{URL}/keys/ron:*', '-H', f'Authorization: Bearer {TOKEN}'], capture_output=True)
keys = json.loads(r.stdout.decode('utf-8', errors='replace')).get('result', [])

now = datetime.utcnow()
cutoff = now - timedelta(hours=24)

entries = []
for key in keys:
    if any(k in key for k in ['jefftest', 'test:', 'archive', 'ron:health:']):
        continue
    rv = subprocess.run(['curl', '-s', f'{URL}/get/{key}', '-H', f'Authorization: Bearer {TOKEN}'], capture_output=True)
    try:
        data = json.loads(rv.stdout.decode('utf-8', errors='replace'))
        inner = json.loads(data.get('result', '{}'))
        ts_str = inner.get('timestamp', '')
        if ts_str:
            ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
            if ts.replace(tzinfo=None) >= cutoff:
                short_key = key.replace('ron:user:', '')
                entries.append((short_key, inner.get('value', ''), ts_str))
    except:
        pass

if entries:
    print(f"🆕 New memories in last 24h ({len(entries)}):")
    for k, v, t in sorted(entries, key=lambda x: x[2]):
        print(f"   • {k}: {v}")
else:
    print("No new memories in last 24h")
PYEOF