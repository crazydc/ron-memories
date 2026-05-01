#!/usr/bin/env python3
# memory-sync.py - Pull all namespaces from Redis, update local cache

import os
import re
import json
import subprocess
from datetime import datetime

# Load config
cache_dir = os.path.expanduser("~/.openclaw/workspace/memory")
cache_file = os.path.join(cache_dir, "ron-memory.md")
env_file = os.path.expanduser("~/.openclaw/.env.ron-memory")

# Parse .env.ron-memory
with open(env_file) as f:
    for line in f:
        line = line.strip()
        if line.startswith("UPSTASH_REDIS_URL="):
            REDIS_URL = line.split("=", 1)[1].strip()
        elif line.startswith("UPSTASH_REDIS_TOKEN="):
            REDIS_TOKEN = line.split("=", 1)[1].strip()

NOW = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

# Get all keys
keys_response = subprocess.check_output([
    "curl", "-s", f"{REDIS_URL}/keys/ron:*",
    "-H", f"Authorization: Bearer {REDIS_TOKEN}"
], text=True)

# Parse JSON array - extract all "ron:xxx" strings
keys = re.findall(r'"(ron:[^"]+)"', keys_response)
print(f"Found {len(keys)} keys in Redis")

# Build new cache
with open(cache_file, "w") as f:
    f.write("# Ron Memory Cache\n")
    f.write(f"# Last synced: {NOW}\n")
    f.write("\n")
    f.write("| Key | Value | Updated |\n")
    f.write("|-----|-------|--------|\n")
    
    entry_count = 0
    for redis_key in keys:
        key = redis_key.replace("ron:user:", "", 1)
        
        if key.startswith("archive:"):
            continue
        
        # Get value and timestamp
        get_response = subprocess.check_output([
            "curl", "-s", f"{REDIS_URL}/get/{redis_key}",
            "-H", f"Authorization: Bearer {REDIS_TOKEN}"
        ], text=True)
        
        try:
            raw = json.loads(get_response).get("result", "{}")
            result = json.loads(raw) if isinstance(raw, str) else raw
            if result:
                value = result.get("value", "")
                timestamp = result.get("timestamp", "")
                if value:
                    f.write(f"| {key} | {value} | {timestamp} |\n")
                    entry_count += 1
        except Exception as e:
            pass

print(f"OK: Synced {entry_count} entries to {cache_file}")
