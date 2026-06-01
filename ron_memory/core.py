"""Core Memory class — all Redis + cache I/O.

One place. No string-interpolated JSON. No shell heredocs. One way to talk
to Upstash (urllib).
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .config import MIGRATION_FLAG_KEY, get_config, require_redis_credentials
from .jsonio import decode_payload, encode_payload, extract_value, parse_key_list
from .tiers import detect_tier, validate_importance, validate_tier


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _upstash_request(method: str, path: str, body: dict | None = None) -> str:
    """Make an Upstash REST call. Returns raw response body as string.

    Raises on network errors. Callers should catch and decide what to do.
    """
    url, token = require_redis_credentials()
    full_url = f"{url}{path}"
    headers = {"Authorization": f"Bearer {token}"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(full_url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.read().decode("utf-8")
    except (urllib.error.URLError, urllib.error.HTTPError) as exc:
        raise RuntimeError(f"Upstash {method} {path} failed: {exc}") from exc


class Memory:
    """High-level memory operations.

    All write operations go to Redis AND update the local cache file
    (matching v3 behavior — the cache is a local mirror for fast reads).
    """

    # The "short" form of a key (used in cache and in Tier/namespacing).
    # In v3, keys were stored in Redis as "ron:<short>" and the cache used
    # just "<short>". v4 keeps that contract.

    @staticmethod
    def _redis_key(short_key: str) -> str:
        return f"ron:{short_key}"

    def __init__(self, cache_file: Path | None = None, archive_dir: Path | None = None):
        cfg = get_config()
        self.cache_file = cache_file or cfg["cache_file"]
        self.archive_dir = archive_dir or cfg["archive_dir"]
        self.cache_file.parent.mkdir(parents=True, exist_ok=True)
        self.archive_dir.mkdir(parents=True, exist_ok=True)

    # ─── Read ────────────────────────────────────────────────────────────

    def get(self, key: str) -> str | None:
        """Get the value of a memory. Returns None if not found.

        Updates the reinforce:count:<key> counter in Redis (matching v3).
        """
        redis_key = self._redis_key(key)
        try:
            raw = _upstash_request("GET", f"/get/{redis_key}")
        except RuntimeError:
            raw = ""
        value = extract_value(raw)
        if value:
            self._increment_reinforce(key)
            return value
        # Fallback to cache
        return self._cache_get(key)

    def exists(self, key: str) -> bool:
        return self.get(key) is not None

    def _cache_get(self, key: str) -> str | None:
        if not self.cache_file.is_file():
            return None
        for line in self.cache_file.read_text().splitlines():
            if not line.startswith("|"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 3 and parts[1] == key:
                return parts[2]
        return None

    def _increment_reinforce(self, key: str) -> None:
        """Bump the access counter for this key. Best-effort, never raises."""
        try:
            current_raw = _upstash_request("GET", f"/get/ron:reinforce:count:{key}")
            current = extract_value(current_raw) or "0"
            new_count = int(current) + 1
            _upstash_request("POST", f"/set/ron:reinforce:count:{key}", {
                "value": str(new_count),
                "timestamp": _now_iso(),
            })
            _upstash_request("POST", f"/set/ron:reinforce:last:{key}", {
                "value": _now_iso(),
                "timestamp": _now_iso(),
            })
        except (RuntimeError, ValueError):
            pass  # Best-effort

    # ─── Write ───────────────────────────────────────────────────────────

    def set(
        self,
        key: str,
        value: str,
        tier: str | None = None,
        importance: int = 50,
        context: str = "",
        force: bool = False,
        stale_ok: bool = False,
    ) -> dict:
        """Save a memory.

        Returns a dict describing what happened:
          {"status": "saved", "key": ..., "tier": ..., "archived_old": bool}

        On staleness conflict, returns {"status": "rejected", "reason": "..."}
        unless force=True or stale_ok=True.
        """
        if not key or not value:
            return {"status": "error", "reason": "key and value required"}

        # Detect tier
        resolved_tier = tier or detect_tier(key)
        validate_tier(resolved_tier)
        validate_importance(importance)

        # Staleness check
        old = self._cache_get(key)
        if old is not None and old != value:
            if force:
                # Force: just overwrite, no archive
                pass
            elif stale_ok:
                # Stale-ok: archive old value first
                self._archive_value(key, old, timestamp=_now_iso())
            else:
                return {
                    "status": "rejected",
                    "reason": "stale",
                    "old_value": old,
                    "new_value": value,
                    "hint": "use --force to overwrite or --stale-ok to archive old value",
                }

        # Write to Redis
        timestamp = _now_iso()
        payload_json = encode_payload(
            value=value,
            timestamp=timestamp,
            tier=resolved_tier,
            importance=importance,
            context=context,
        )
        body = json.loads(payload_json)  # round-trip to ensure valid JSON
        _upstash_request("POST", f"/set/{self._redis_key(key)}", body)

        # Update local cache (atomic: tmp + rename)
        self._cache_upsert(key, value, timestamp, resolved_tier, importance, context)

        return {
            "status": "saved",
            "key": key,
            "tier": resolved_tier,
            "importance": importance,
            "context": context,
            "archived_old": old is not None and old != value and stale_ok,
        }

    def _archive_value(self, key: str, old_value: str, timestamp: str) -> None:
        """Write an archived value to a monthly file + Redis."""
        now = _now_iso()
        safe_value = old_value.replace("|", "\\|")[:500]
        archive_key = f"{key}.archived.{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}"
        archive_file = self.archive_dir / f"{datetime.now(timezone.utc).strftime('%Y-%m')}.md"
        with archive_file.open("a") as f:
            f.write(f"| {archive_key} | {safe_value} | {timestamp} | archived={now} |\n")
        try:
            _upstash_request("POST", f"/set/ron:archive:{archive_key}", {
                "value": old_value,
                "timestamp": timestamp,
                "archived": now,
                "original_key": key,
            })
        except RuntimeError:
            pass  # Cache-only archive is fine

    def _cache_upsert(
        self,
        key: str,
        value: str,
        timestamp: str,
        tier: str,
        importance: int,
        context: str,
    ) -> None:
        """Insert or replace a row in the cache file."""
        if not self.cache_file.is_file():
            self.cache_file.touch()
        safe_value = value.replace("|", "\\|")
        new_line = f"| {key} | {safe_value} | {timestamp} | tier={tier} importance={importance}"
        if context:
            new_line += f" context={context}"
        new_line += " |"

        lines: list[str] = []
        replaced = False
        for line in self.cache_file.read_text().splitlines():
            if line.startswith(f"| {key} |"):
                lines.append(new_line)
                replaced = True
            else:
                lines.append(line)
        if not replaced:
            lines.append(new_line)

        tmp = self.cache_file.with_suffix(self.cache_file.suffix + ".tmp")
        tmp.write_text("\n".join(lines) + "\n")
        tmp.replace(self.cache_file)

    # ─── Delete ──────────────────────────────────────────────────────────

    def delete(self, key: str) -> bool:
        """Delete a key from Redis and cache. Returns True if it existed."""
        existed = self.exists(key)
        try:
            _upstash_request("POST", f"/del/{self._redis_key(key)}", {})
        except RuntimeError:
            pass
        # Remove from cache
        if self.cache_file.is_file():
            lines = []
            for line in self.cache_file.read_text().splitlines():
                if line.startswith(f"| {key} |"):
                    continue
                lines.append(line)
            tmp = self.cache_file.with_suffix(self.cache_file.suffix + ".tmp")
            tmp.write_text("\n".join(lines) + "\n")
            tmp.replace(self.cache_file)
        return existed

    # ─── List / enumerate ────────────────────────────────────────────────

    def list_keys(self) -> list[str]:
        """Return all short keys in Redis (filtered to non-system)."""
        try:
            raw = _upstash_request("GET", "/keys/ron:*")
        except RuntimeError:
            return []
        keys = parse_key_list(raw)
        # Filter to short keys (strip "ron:" prefix and exclude system keys)
        short = []
        for k in keys:
            if not k.startswith("ron:"):
                continue
            s = k[4:]
            # Skip system keys
            if s.startswith("reinforce:") or s.startswith("archive:") or s.startswith("health:") or s.startswith("migration:"):
                continue
            short.append(s)
        return short

    def cache_entries(self) -> list[dict]:
        """Return all entries from the local cache as parsed dicts."""
        if not self.cache_file.is_file():
            return []
        entries = []
        for line in self.cache_file.read_text().splitlines():
            if not line.startswith("|"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) < 4:
                continue
            key, value, timestamp, meta = parts[1], parts[2], parts[3], parts[4] if len(parts) > 4 else ""
            # Parse tier/importance from meta
            tier = "semantic"
            importance = 50
            context = ""
            for token in meta.split():
                if "=" in token:
                    k, _, v = token.partition("=")
                    if k == "tier":
                        tier = v
                    elif k == "importance":
                        try:
                            importance = int(v)
                        except ValueError:
                            pass
                    elif k == "context":
                        context = v
            entries.append({
                "key": key,
                "value": value,
                "timestamp": timestamp,
                "tier": tier,
                "importance": importance,
                "context": context,
            })
        return entries

    # ─── Health ──────────────────────────────────────────────────────────

    def healthcheck(self) -> dict:
        """Return a dict describing the system state."""
        result: dict[str, Any] = {
            "redis": False,
            "redis_key_count": 0,
            "cache_file_exists": False,
            "cache_entries": 0,
            "migration_done": False,
            "errors": [],
        }
        try:
            raw = _upstash_request("GET", "/keys/ron:*")
            keys = parse_key_list(raw)
            result["redis"] = True
            result["redis_key_count"] = len(keys)
        except RuntimeError as exc:
            result["errors"].append(f"redis: {exc}")

        # Test read
        try:
            raw = _upstash_request("GET", "/get/ron:user:user_name")
            value = extract_value(raw)
            if value:
                result["sample_read"] = value
        except RuntimeError as exc:
            result["errors"].append(f"sample_read: {exc}")

        # Test write
        try:
            test_key = f"health:test:{datetime.now(timezone.utc).timestamp()}"
            _upstash_request("POST", f"/set/{test_key}", {
                "value": "ping",
                "timestamp": _now_iso(),
            })
            result["write_ok"] = True
            # Cleanup
            try:
                _upstash_request("POST", f"/del/{test_key}", {})
            except RuntimeError:
                pass
        except RuntimeError as exc:
            result["errors"].append(f"write: {exc}")

        # Cache
        result["cache_file_exists"] = self.cache_file.is_file()
        result["cache_entries"] = len(self.cache_entries())

        # Migration flag
        try:
            raw = _upstash_request("GET", f"/get/{MIGRATION_FLAG_KEY}")
            value = extract_value(raw)
            result["migration_done"] = bool(value)
        except RuntimeError:
            pass

        return result
