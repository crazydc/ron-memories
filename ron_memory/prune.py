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
    apply_fn=None,
) -> dict:
    """Prune expired entries based on tier TTL + importance floor.

    Returns a dict describing what happened. Entries are not mutated;
    caller is responsible for writing the survivors back.

    Archive entries (key starts with "archive:") are never pruned.

    If `apply_fn` is provided AND `dry_run` is False, it is called once
    per expired entry with (key, entry_dict) — typically `memory.delete`.
    This makes the prune actually do something. If `apply_fn` is None and
    dry_run is False, expired entries are still marked in `pruned`/`archived`
    but nothing is written (legacy behaviour, deprecated).
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
            if not dry_run and apply_fn is not None:
                try:
                    apply_fn(key, entry)
                    archived.append(entry)
                except Exception as exc:
                    # Don't include in pruned if apply failed
                    survivors.append(entry)
                    continue
            elif not dry_run:
                # Legacy path: dry_run=False but no apply_fn
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
