"""Search and rank — RRF (Reciprocal Rank Fusion) over keyword + tier + recency.

Single source of truth, replaces memory-rank.sh + memory-search.sh.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any

from .config import RANK_MAX_ENTRIES, RANK_TOKEN_BUDGET, TIER_BOOST


# Family/vehicle/etc keyword boosts (used by rank for "task" mode)
NAMESPACE_KEYWORDS = {
    "family": ["family", "wife", "husband", "kids", "children", "son", "daughter", "birthday"],
    "vehicle": ["car", "vehicle", "drive", "car", "tesla", "commute"],
    "project": ["project", "code", "feature", "build", "debug", "test", "deploy"],
    "career": ["work", "job", "career", "company"],
}


def _age_days(timestamp: str) -> int:
    """Return age in days, or 9999 if unparseable."""
    if not timestamp:
        return 9999
    try:
        ts = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        return max(0, (now - ts).days)
    except (ValueError, TypeError):
        return 9999


def _tokenize(text: str) -> set[str]:
    """Lowercase word tokens, 2+ chars.

    Splits on non-word characters AND on underscores, so that
    "sam_birthday" becomes {"sam", "birthday"}.
    """
    # Replace underscores with spaces, then split on non-word
    normalized = text.replace("_", " ").replace(":", " ").replace("-", " ")
    return {t for t in re.findall(r"\w+", normalized.lower()) if len(t) >= 2}


def search(
    entries: list[dict],
    query: str,
    limit: int = 10,
    namespace_filter: str | None = None,
) -> list[dict]:
    """Search entries by keyword match against key + value.

    Returns a list of (entry, score) dicts sorted by descending score.
    """
    query_tokens = _tokenize(query)
    if not query_tokens:
        return []

    scored: list[dict] = []
    for entry in entries:
        key = entry.get("key", "")
        if namespace_filter and not key.startswith(namespace_filter + ":"):
            continue
        # Tokenize key + value
        haystack = _tokenize(key + " " + entry.get("value", ""))
        if not haystack:
            continue
        # Match: count overlap
        overlap = query_tokens & haystack
        if not overlap:
            continue
        # Score: matches + tier boost + recency
        score = len(overlap) * 5
        tier = entry.get("tier", "semantic")
        score += TIER_BOOST.get(tier, 5)
        # Recency boost (last 30 days)
        age = _age_days(entry.get("timestamp", ""))
        if age < 7:
            score += 10
        elif age < 30:
            score += 5
        scored.append({**entry, "score": score})

    scored.sort(key=lambda e: e["score"], reverse=True)
    return scored[:limit]


def rank(
    entries: list[dict],
    task: str,
    limit: int = RANK_MAX_ENTRIES,
    budget: int = RANK_TOKEN_BUDGET,
    namespaces: list[str] | None = None,
) -> list[dict]:
    """Attention-based ranking for a task.

    Scoring = freshness (0-30) + tier boost + namespace keyword match.
    """
    task_lc = task.lower()
    matched_namespaces: set[str] = set()
    for ns, keywords in NAMESPACE_KEYWORDS.items():
        for kw in keywords:
            if kw in task_lc:
                matched_namespaces.add(ns)
                break

    # Namespace filter
    if namespaces:
        allowed_ns = set(namespaces)
    else:
        allowed_ns = None

    scored: list[dict] = []
    for entry in entries:
        key = entry.get("key", "")
        ns = key.split(":", 1)[0] if ":" in key else key
        if allowed_ns is not None and ns not in allowed_ns:
            continue

        score = 0
        # Freshness
        age = _age_days(entry.get("timestamp", ""))
        if age < 30:
            score += 30 - age
        # Tier boost
        tier = entry.get("tier", ns)  # legacy: ns is also the tier
        score += TIER_BOOST.get(tier, 5)
        # Namespace keyword match
        if ns in matched_namespaces:
            score += 15
        elif ns in ("anchored", "family", "user", "contact", "goal", "book", "agent"):
            score += 5

        if score > 0:
            scored.append({**entry, "score": score})

    scored.sort(key=lambda e: e["score"], reverse=True)
    return scored[:limit]
