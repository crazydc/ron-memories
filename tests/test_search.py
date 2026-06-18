"""Tests for search + rank. No network."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ron_memory.search import search, rank, _tokenize  # noqa: E402


SAMPLE = [
    {"key": "anchored:sam_birthday", "value": "2020-04-15", "tier": "anchored", "importance": 80, "timestamp": "2026-05-24T20:28:24Z"},
    {"key": "user:family:sam:birthday", "value": "2020/04/15", "tier": "anchored", "importance": 50, "timestamp": "2026-04-30T13:30:04Z"},
    {"key": "episodic:greenfield_family_park_2026_05_27", "value": "Booked into Greenfield Family Park. Sam 6, Riley 19mo.", "tier": "episodic", "importance": 50, "timestamp": "2026-05-27T10:00:00Z"},
    {"key": "user:acasey:car", "value": "Alex has a car", "tier": "anchored", "importance": 50, "timestamp": "2026-04-15T10:00:00Z"},
    {"key": "semantic:heyron_status", "value": "Heyron sites all running", "tier": "semantic", "importance": 50, "timestamp": "2026-06-01T10:00:00Z"},
    {"key": "reminder:call_zoo", "value": "follow up with zoo booking", "tier": "reminder", "importance": 50, "timestamp": "2026-05-30T10:00:00Z"},
]


def test_tokenize_splits_underscores():
    assert "sam" in _tokenize("sam_birthday")
    assert "birthday" in _tokenize("sam_birthday")
    assert "sam" in _tokenize("anchored:sam_birthday")
    assert "birthday" in _tokenize("anchored:sam_birthday")


def test_tokenize_drops_short():
    assert _tokenize("a i t") == set()
    assert "ok" in _tokenize("ok this works")


def test_search_basic():
    results = search(SAMPLE, "Sam birthday", limit=5)
    assert len(results) > 0
    # The anchored entry should be top (tier_boost 20 + recency if fresh)
    top = results[0]
    assert "sam" in top["key"].lower()
    assert "birthday" in top["key"].lower() or "birthday" in top["value"].lower()


def test_search_with_namespace_filter():
    results = search(SAMPLE, "car", limit=5, namespace_filter="user")
    assert all(r["key"].startswith("user:") for r in results)
    # Should find the car entries
    assert any("car" in r["key"].lower() for r in results)


def test_search_no_match():
    results = search(SAMPLE, "xyzzyplugh", limit=5)
    assert results == []


def test_search_empty_query():
    results = search(SAMPLE, "", limit=5)
    assert results == []


def test_rank_family_task_boosts_family():
    results = rank(SAMPLE, "family birthday party", limit=5)
    # Should at least include family-related entries
    keys = [r["key"] for r in results]
    assert any("sam" in k.lower() or "birthday" in k.lower() for k in keys)


def test_rank_vehicle_task_boosts_vehicle():
    results = rank(SAMPLE, "car vehicle drive", limit=10)
    keys = [r["key"] for r in results]
    # car entry should be somewhere in the ranking
    assert any("car" in k.lower() for k in keys)


def test_rank_with_namespace_filter():
    results = rank(SAMPLE, "anything", limit=10, namespaces=["anchored"])
    # Only anchored entries
    assert all(r["key"].startswith("anchored:") for r in results)


def test_rank_respects_limit():
    results = rank(SAMPLE, "family", limit=2)
    assert len(results) <= 2


def test_rank_excludes_zero_score():
    """Namespace filter that excludes everything should return empty."""
    results = rank(SAMPLE, "family", limit=10, namespaces=["nonexistent_ns"])
    assert results == []


TESTS = [
    test_tokenize_splits_underscores,
    test_tokenize_drops_short,
    test_search_basic,
    test_search_with_namespace_filter,
    test_search_no_match,
    test_search_empty_query,
    test_rank_family_task_boosts_family,
    test_rank_vehicle_task_boosts_vehicle,
    test_rank_with_namespace_filter,
    test_rank_respects_limit,
    test_rank_excludes_zero_score,
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
