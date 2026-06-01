"""Redis -> local cache sync. Replaces memory-sync.sh.

Incremental-ish: scans all keys once, but writes the cache file atomically.
"""

from __future__ import annotations

import urllib.error
import urllib.request
import json
from datetime import datetime, timezone

from .config import MIGRATION_FLAG_KEY, require_redis_credentials
from .core import _now_iso, _upstash_request
from .jsonio import decode_payload, extract_value, parse_key_list
from .tiers import detect_tier


SYSTEM_KEY_PREFIXES = (
    "ron:reinforce:",
    "ron:archive:",
    "ron:health:",
    "ron:migration:",
    "ron:jobs:",  # jobs queue is a separate system
)


def _is_system_key(redis_key: str) -> bool:
    for prefix in SYSTEM_KEY_PREFIXES:
        if redis_key.startswith(prefix):
            return True
    return False


def fetch_all_keys() -> list[str]:
    """Return all non-system short keys from Redis."""
    try:
        raw = _upstash_request("GET", "/keys/ron:*")
    except RuntimeError:
        return []
    keys = parse_key_list(raw)
    short: list[str] = []
    for k in keys:
        if not k.startswith("ron:"):
            continue
        s = k[4:]
        if s.startswith("jeff:test") or s.startswith("test"):
            continue
        if _is_system_key(k):
            continue
        short.append(s)
    return short


def fetch_entry(short_key: str) -> dict | None:
    """Fetch a single entry's value + metadata from Redis.

    Handles three payload shapes seen in v3 data:
      1. Full dict: {"value": "...", "timestamp": "...", "tier": "...", ...}
      2. Bare value: "just a string"  (treated as value, tier inferred from key prefix)
      3. Empty / malformed: returns None
    """
    try:
        raw = _upstash_request("GET", f"/get/ron:{short_key}")
    except RuntimeError:
        return None
    payload = decode_payload(raw)
    if payload is None:
        # Try treating the raw response as a bare value
        try:
            import json as _json
            outer = _json.loads(raw)
            inner = outer.get("result")
            if isinstance(inner, str) and inner and inner != "null":
                # The value is stored as a plain string, not a dict
                tier = "anchored" if short_key.startswith(("anchored:", "family:", "user:", "contact:", "vehicle:", "book:", "career:")) else "semantic"
                return {
                    "key": short_key,
                    "value": inner,
                    "timestamp": _now_iso(),
                    "tier": tier,
                    "importance": 50,
                    "context": "",
                }
        except (ValueError, TypeError):
            pass
        return None
    if not isinstance(payload, dict):
        # Treat as bare value
        tier = "anchored" if short_key.startswith(("anchored:", "family:", "user:", "contact:", "vehicle:", "book:", "career:")) else "semantic"
        return {
            "key": short_key,
            "value": str(payload),
            "timestamp": _now_iso(),
            "tier": tier,
            "importance": 50,
            "context": "",
        }
    # Get tier from payload OR fall back to detection from key
    raw_tier = payload.get("tier")
    if raw_tier:
        tier = str(raw_tier)
    else:
        # Old v3 data lacks tier/importance fields. Detect from namespace.
        tier = detect_tier(short_key)
    return {
        "key": short_key,
        "value": str(payload.get("value", "")),
        "timestamp": str(payload.get("timestamp", _now_iso())),
        "tier": tier,
        "importance": int(payload.get("importance", 50)),
        "context": str(payload.get("context", "")),
    }


def sync_cache(cache_file) -> dict:
    """Sync Redis -> local cache file. Atomic write."""
    short_keys = fetch_all_keys()
    entries: list[dict] = []
    failed: list[str] = []
    for key in short_keys:
        entry = fetch_entry(key)
        if entry:
            entries.append(entry)
        else:
            failed.append(key)

    # Atomic write
    now = _now_iso()
    lines = [
        "# Ron Memory Cache",
        f"# Last synced: {now}",
        "",
        "| Key | Value | Updated | Meta |",
        "|-----|-------|---------|------|",
        "# (header row ends above; data follows)",
    ]
    for e in entries:
        safe_value = e["value"].replace("|", "\\|")
        meta = f"tier={e['tier']} importance={e['importance']}"
        if e.get("context"):
            meta += f" context={e['context']}"
        lines.append(f"| {e['key']} | {safe_value} | {e['timestamp']} | {meta} |")
    lines.append("")
    lines.append(f"# Synced {len(entries)} entries")

    tmp = cache_file.with_suffix(cache_file.suffix + ".tmp")
    tmp.write_text("\n".join(lines) + "\n")
    tmp.replace(cache_file)

    return {
        "synced": len(entries),
        "failed": len(failed),
        "failed_keys": failed,
        "timestamp": now,
    }


def set_migration_flag() -> bool:
    """Set the v2->v3 migration flag in Redis. Idempotent."""
    try:
        _upstash_request("POST", f"/set/{MIGRATION_FLAG_KEY}", {
            "value": "done",
            "timestamp": _now_iso(),
            "tier": "anchored",
            "importance": 100,
        })
        return True
    except RuntimeError:
        return False
