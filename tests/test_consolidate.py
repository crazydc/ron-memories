"""Tests for consolidation (episodic -> semantic). No network."""

import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ron_memory.consolidate import (  # noqa: E402
    find_consolidation_candidates,
    build_summary,
)


def _episodic(key: str, value: str, days_old: int) -> dict:
    ts = (datetime.now(timezone.utc) - timedelta(days=days_old)).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {"key": key, "value": value, "tier": "episodic", "importance": 50, "timestamp": ts}


def test_finds_old_episodic():
    entries = [
        _episodic("episodic:2026_05_24_lakes_trip", "lakes trip day 1", 20),
        _episodic("episodic:2026_05_25_lakes_trip", "lakes trip day 2", 19),
    ]
    candidates = find_consolidation_candidates(entries, min_age_days=14)
    assert len(candidates) == 1
    assert candidates[0]["topic"] == "lakes"
    assert len(candidates[0]["entries"]) == 2


def test_skips_young_episodic():
    entries = [_episodic("episodic:2026_05_30_recent", "fresh", 2)]
    candidates = find_consolidation_candidates(entries, min_age_days=14)
    assert candidates == []


def test_skips_non_episodic():
    entries = [
        {"key": "anchored:sam", "value": "x", "tier": "anchored", "importance": 80, "timestamp": "2020-01-01T00:00:00Z"},
        {"key": "semantic:fact", "value": "y", "tier": "semantic", "importance": 50, "timestamp": "2020-01-01T00:00:00Z"},
    ]
    candidates = find_consolidation_candidates(entries, min_age_days=1)
    assert candidates == []


def test_groups_by_topic():
    entries = [
        _episodic("episodic:2026_05_24_lakes_trip", "lakes 1", 20),
        _episodic("episodic:2026_05_24_zoo_visit", "zoo 1", 20),
        _episodic("episodic:2026_05_25_lakes_trip", "lakes 2", 19),
    ]
    candidates = find_consolidation_candidates(entries, min_age_days=14)
    topics = sorted(c["topic"] for c in candidates)
    assert topics == ["lakes", "zoo"]


def test_build_summary_singular():
    summary = build_summary("lakes", [{"value": "single entry"}])
    # The function prefixes with "Consolidated from N episodic entries"
    assert "single entry" in summary["value"]
    assert "1 episodic" in summary["value"]
    assert summary["key"] == "semantic:summary:lakes"
    assert summary["tier"] == "semantic"
    assert summary["source_count"] == 1


def test_build_summary_plural():
    summary = build_summary("lakes", [
        {"value": "first"},
        {"value": "second"},
    ])
    assert "first" in summary["value"]
    assert "second" in summary["value"]
    assert "Consolidated from 2 episodic entries" in summary["value"]


def test_build_summary_empty_values():
    summary = build_summary("topic", [])
    assert "no values" in summary["value"]


TESTS = [
    test_finds_old_episodic,
    test_skips_young_episodic,
    test_skips_non_episodic,
    test_groups_by_topic,
    test_build_summary_singular,
    test_build_summary_plural,
    test_build_summary_empty_values,
]


def main():
    passed = 0
    failed = 0
    for test in TESTS:
        try:
            test()
            print(f"  ✅ {test.__name__}")
            passed += 1
        except AssertionError as e:
            print(f"  ❌ {test.__name__}: {e}")
            failed += 1
    print()
    print(f"Results: {passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
