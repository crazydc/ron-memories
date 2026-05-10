#!/usr/bin/env python3
# memory-export.py v3 — Export all Redis memories to JSON

import sys, json, subprocess, os

# Default credentials (hardcoded for now, can be overridden by env)
TOKEN = os.environ.get('UPSTASH_REDIS_TOKEN', 'gQAAAAAAAa1mAAIgcDE0YzVlNGUwYzE1N2I0ZGRhYWU1MDc0OTc5YzA1YWMyYw')
URL = os.environ.get('UPSTASH_REDIS_URL', 'https://summary-hare-109926.upstash.io')
INCLUDE_REINFORCE = os.environ.get('INCLUDE_REINFORCE', 'false') == 'true'

def api(path):
    cmd = ['curl', '-s', f'{URL}{path}', '-H', f'Authorization: Bearer {TOKEN}']
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except:
        return None

def main():
    # Get all keys
    keys_data = api('/keys/ron:*')
    if not keys_data or 'result' not in keys_data:
        print("[]")
        return

    all_keys = keys_data['result']

    # Filter: exclude test/jeff
    filtered = [k for k in all_keys if not k.startswith('ron:test') and not k.startswith('ron:jeff')]
    if not INCLUDE_REINFORCE:
        filtered = [k for k in filtered if not k.startswith('ron:reinforce:')]

    entries = []
    for key in filtered:
        data = api(f'/get/{key}')
        if data and 'result' in data and data['result']:
            try:
                inner = json.loads(data['result'])
                entries.append({
                    'key': key,
                    'value': inner.get('value', ''),
                    'timestamp': inner.get('timestamp', '')
                })
            except:
                pass

    print(json.dumps(entries))

if __name__ == '__main__':
    main()