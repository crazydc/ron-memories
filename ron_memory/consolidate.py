"""Episodic -> semantic consolidation. Replaces memory-consolidate.sh.

Groups old episodic entries by topic, suggests a semantic summary.
For now, the summary is a deterministic concat (no LLM call) — humans/agents
can review and edit the proposed semantic entries before they're saved.
"""

from __future__ import annotations

import re
from collections import defaultdict
from datetime import datetime, timezone


def _age_days(timestamp: str) -> int:
    if not timestamp:
        return 9999
    try:
        ts = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        return max(0, (now - ts).days)
    except (ValueError, TypeError):
        return 9999


def find_consolidation_candidates(
    entries: list[dict],
    min_age_days: int = 14,
) -> list[dict]:
    """Find episodic entries older than min_age_days, grouped by topic."""
    old = []
    for entry in entries:
        tier = entry.get("tier", "semantic")
        if tier != "episodic":
            continue
        age = _age_days(entry.get("timestamp", ""))
        if age >= min_age_days:
            old.append(entry)

    # Group by topic (key prefix after the tier prefix)
    groups: dict[str, list[dict]] = defaultdict(list)
    for entry in old:
        key = entry.get("key", "")
        # Strip "episodic:" if present
        if key.startswith("episodic:"):
            key = key[len("episodic:"):]
        # Strip leading date patterns (2026_05_24_)
        key = re.sub(r"^\d{4}[_-]\d{2}[_-]\d{2}[_-]?", "", key)
        # Use first word as topic
        topic = key.split("_")[0] if "_" in key else key.split(" ")[0] if " " in key else key
        if not topic:
            topic = "misc"
        groups[topic].append(entry)

    return [
        {"topic": topic, "entries": entries}
        for topic, entries in groups.items()
    ]


def build_summary(topic: str, entries: list[dict]) -> dict:
    """Build a proposed semantic:summary:<topic> entry from grouped episodic entries."""
    values = [e.get("value", "") for e in entries if e.get("value")]
    if not values:
        body = f"(no values to consolidate from {len(entries)} entries)"
    elif len(values) == 1:
        body = values[0]
    else:
        body = " | ".join(values)

    summary_value = f"Consolidated from {len(entries)} episodic entries: {body[:500]}"
    return {
        "key": f"semantic:summary:{topic}",
        "value": summary_value,
        "tier": "semantic",
        "importance": 30,
        "context": "consolidated",
        "source_count": len(entries),
    }
