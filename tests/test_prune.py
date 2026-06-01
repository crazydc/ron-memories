"""Tests for prune (TTL enforcement). No network."""

import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ron_memory.prune import prune  # noqa: E402


def _entry(key: str, value: str, tier: str, days_old: int, importance: int = 50) -> dict:
    ts = (datetime.now(timezone.utc) - timedelta(days=days_old)).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {"key": key, "value": value, "tier": tier, "importance": importance, "timestamp": ts}


def test_anchored_never_pruned():
    entries = [_entry("anchored:sam_birthday", "2020-04-15", "anchored", 3650, importance=80)]
    result = prune(entries, dry_run=True)
    assert result["pruned_count"] == 0
    assert result["survivor_count"] == 1


def test_working_old_is_pruned():
    # working tier ttl 1d, importance 10 -> floor 7d, effective 7d
    entries = [_entry("working:current_focus", "something", "working", 10, importance=10)]
    result = prune(entries, dry_run=True)
    assert result["pruned_count"] == 1
    assert result["survivor_count"] == 0


def test_working_fresh_survives():
    entries = [_entry("working:current_focus", "something", "working", 0, importance=10)]
    result = prune(entries, dry_run=True)
    assert result["pruned_count"] == 0
    assert result["survivor_count"] == 1


def test_semantic_at_ttl_boundary():
    # semantic = 90 days, importance 50 -> ttl 90
    entries = [_entry("semantic:fact", "x", "semantic", 89)]
    result = prune(entries, dry_run=True)
    assert result["survivor_count"] == 1
    entries = [_entry("semantic:fact", "x", "semantic", 91)]
    result = prune(entries, dry_run=True)
    assert result["pruned_count"] == 1


def test_high_importance_extends_ttl():
    # semantic + importance 80 = 365 days ttl
    entries = [_entry("semantic:critical_fact", "x", "semantic", 200, importance=80)]
    result = prune(entries, dry_run=True)
    assert result["survivor_count"] == 1
    entries = [_entry("semantic:critical_fact", "x", "semantic", 400, importance=80)]
    result = prune(entries, dry_run=True)
    assert result["pruned_count"] == 1


def test_archive_never_pruned():
    entries = [
        _entry("archive:old_stuff", "x", "semantic", 9999, importance=50),
        _entry("archive:another", "y", "episodic", 9999, importance=50),
    ]
    result = prune(entries, dry_run=True)
    assert result["pruned_count"] == 0
    assert result["survivor_count"] == 2


def test_namespace_filter():
    entries = [
        _entry("working:a", "x", "working", 10, importance=10),
        _entry("working:b", "y", "working", 0, importance=10),
        _entry("semantic:c", "z", "semantic", 5),
    ]
    result = prune(entries, dry_run=True, namespace_filter="working")
    # working:a pruned, working:b survives, semantic:c untouched (filtered out)
    assert result["pruned_count"] == 1
    assert result["survivor_count"] == 2


def test_dry_run_doesnt_mutate():
    entries = [
        _entry("working:a", "x", "working", 10, importance=10),
    ]
    prune(entries, dry_run=True)
    # Caller's list unchanged
    assert len(entries) == 1


TESTS = [
    test_anchored_never_pruned,
    test_working_old_is_pruned,
    test_working_fresh_survives,
    test_semantic_at_ttl_boundary,
    test_high_importance_extends_ttl,
    test_archive_never_pruned,
    test_namespace_filter,
    test_dry_run_doesnt_mutate,
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
