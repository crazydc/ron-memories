"""Configuration: load Upstash credentials + paths from .env.ron-memory.

Single source of truth. No credentials in any other file.
"""

from __future__ import annotations

import os
from pathlib import Path

# Tier -> TTL in days. 0 = permanent.
TIER_TTL = {
    "anchored": 0,
    "semantic": 90,
    "episodic": 30,
    "reminder": 7,
    "working": 1,
}

# Legacy namespace -> tier (kept for backwards compat with v2/v3 callers)
LEGACY_NAMESPACE_TIER = {
    "user": "anchored",
    "family": "anchored",
    "contact": "anchored",
    "vehicle": "anchored",
    "book": "anchored",
    "career": "anchored",
    "pref": "semantic",
    "project": "semantic",
    "goal": "semantic",
    "service": "semantic",
    "agent": "semantic",
    "reminder": "reminder",  # legacy "reminder:" prefix is now reminder tier
    "story": "episodic",      # legacy "story:" prefix
}

# Summarization threshold for cache entries (chars before compressing)
SUMMARIZE_THRESHOLD = 500

# Default rank parameters
RANK_MAX_ENTRIES = 20
RANK_TOKEN_BUDGET = 2000  # 1 token ~= 4 chars

# Search/retrieval boosts
TIER_BOOST = {
    "anchored": 20,
    "semantic": 10,
    "episodic": 5,
    "reminder": 3,
    "working": 2,
}

# Tier importance -> TTL floor (memories with high importance get a longer leash)
IMPORTANCE_TTL_FLOOR = {
    # importance: min_ttl_days
    80: 365,  # critical: at least a year
    50: 90,   # normal
    20: 30,   # low
    0: 7,     # transient
}

# Migration flag key — set this in Redis once v2→v3 migration is verified done.
MIGRATION_FLAG_KEY = "ron:migration:v2to:v3:done"


def _candidate_env_paths() -> list[Path]:
    """Order: most specific first."""
    home = Path.home()
    return [
        home / ".openclaw" / ".env.ron-memory",
        home / ".openclaw" / "workspace" / ".env.ron-memory",
        home / "workspace" / ".env.ron-memory",
    ]


def _load_env_file() -> None:
    """Load .env.ron-memory into os.environ. Does not overwrite existing env vars."""
    for path in _candidate_env_paths():
        if not path.is_file():
            continue
        for raw_line in path.read_text().splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value
        break  # only first match wins


def _workspace_dir() -> Path:
    """Best-effort: figure out the workspace root."""
    for candidate in (
        Path.home() / ".openclaw" / "workspace",
        Path("/root/.openclaw/workspace"),
    ):
        if candidate.is_dir():
            return candidate
    # Fall back to env or default
    return Path(os.environ.get("RON_WORKSPACE", str(Path.home() / ".openclaw" / "workspace")))


# Module-level cache (loaded once on first import)
_LOADED = False


def get_config() -> dict:
    """Return a dict of resolved config values.

    Returns a fresh dict each time (callers can mutate freely).
    """
    global _LOADED
    if not _LOADED:
        _load_env_file()
        _LOADED = True

    workspace = _workspace_dir()
    cache_file = workspace / "memory" / "ron-memory.md"
    archive_dir = workspace / "memory" / "archive"

    return {
        "redis_url": os.environ.get("UPSTASH_REDIS_URL", "").rstrip("/"),
        "redis_token": os.environ.get("UPSTASH_REDIS_TOKEN", ""),
        "cache_file": cache_file,
        "archive_dir": archive_dir,
        "workspace": workspace,
    }


def require_redis_credentials() -> tuple[str, str]:
    """Return (url, token) or raise a clear error if missing."""
    cfg = get_config()
    url = cfg["redis_url"]
    token = cfg["redis_token"]
    if not url or not token:
        raise RuntimeError(
            "Upstash credentials not found. Set UPSTASH_REDIS_URL and "
            "UPSTASH_REDIS_TOKEN in ~/.openclaw/workspace/.env.ron-memory"
        )
    return url, token
