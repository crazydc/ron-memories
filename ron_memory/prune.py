"""TTL enforcement + cold storage. Replaces memory-prune.sh."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from .config import TIER_TTL
from .tiers import ttl_days


def _age_days(timestamp: str) -> int:
    if not timestamp:
        return 9999
    try:
        ts = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        return max(0, (now - ts).days)
    except (ValueError, TypeError):
        return 9999


def prune(
    entries: list[dict],
    namespace_filter: str | None = None,
    dry_run: bool = True,
) -> dict:
    """Prune expired entries based on tier TTL + importance floor.

    Returns a dict describing what happened. Entries are not mutated;
    caller is responsible for writing the survivors back.

    Archive entries (key starts with "archive:") are never pruned.
    """
    now = datetime.now(timezone.utc)
    survivors: list[dict] = []
    pruned: list[dict] = []
    archived: list[dict] = []

    for entry in entries:
        key = entry.get("key", "")
        ns = key.split(":", 1)[0] if ":" in key else key

        # Filter
        if namespace_filter and ns != namespace_filter:
            survivors.append(entry)
            continue

        # Never prune archives
        if key.startswith("archive:") or ns == "archive":
            survivors.append(entry)
            continue

        tier = entry.get("tier", "semantic")
        importance = entry.get("importance", 50)
        effective_ttl = ttl_days(tier, importance)

        # anchored = permanent, skip
        if effective_ttl == 0:
            survivors.append(entry)
            continue

        age = _age_days(entry.get("timestamp", ""))
        if age > effective_ttl:
            if not dry_run:
                # In real use we'd call Memory.set to archive. For now we mark.
                archived.append(entry)
            pruned.append(entry)
        else:
            survivors.append(entry)

    return {
        "survivors": survivors,
        "pruned": pruned,
        "archived": archived,
        "dry_run": dry_run,
        "pruned_count": len(pruned),
        "survivor_count": len(survivors),
    }
