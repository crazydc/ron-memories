"""Tests for tier detection + validation.

No network. No Redis. Pure unit tests.
"""

import sys
from pathlib import Path

# Make the package importable
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ron_memory.tiers import (  # noqa: E402
    detect_tier,
    namespace_of,
    is_valid_tier,
    validate_tier,
    validate_importance,
    ttl_days,
)


# ─── detect_tier ─────────────────────────────────────────────────────────

def test_tier_prefix_wins():
    assert detect_tier("anchored:sam") == "anchored"
    assert detect_tier("semantic:acasey_pref") == "semantic"
    assert detect_tier("episodic:trip_lakes") == "episodic"
    assert detect_tier("reminder:call_zoo") == "reminder"
    assert detect_tier("working:current_focus") == "working"


def test_legacy_namespace_maps_to_tier():
    assert detect_tier("family:sam") == "anchored"
    assert detect_tier("user:user_name") == "anchored"
    assert detect_tier("contact:john") == "anchored"
    assert detect_tier("vehicle:car") == "anchored"
    assert detect_tier("project:heyron") == "semantic"
    assert detect_tier("pref:diet") == "semantic"
    assert detect_tier("story:2026_05_24") == "episodic"


def test_unprefixed_defaults_to_semantic():
    assert detect_tier("random_key") == "semantic"
    assert detect_tier("") == "semantic"


def test_tier_prefix_even_with_legacy_after():
    """anchored:family:sam should be anchored, not legacy-mapped."""
    assert detect_tier("anchored:family:sam") == "anchored"


# ─── namespace_of ────────────────────────────────────────────────────────

def test_namespace_of():
    assert namespace_of("anchored:sam") == "anchored"
    assert namespace_of("anchored:family:sam") == "anchored"
    assert namespace_of("family:sam") == "family"
    assert namespace_of("unprefixed") == "unprefixed"


# ─── validation ──────────────────────────────────────────────────────────

def test_validate_tier():
    validate_tier("anchored")
    validate_tier("semantic")
    validate_tier("episodic")
    validate_tier("reminder")
    validate_tier("working")


def test_validate_tier_rejects_bad():
    for bad in ["", "unknown", "ANCHORED", "permanent"]:
        try:
            validate_tier(bad)
        except ValueError:
            continue
        else:
            raise AssertionError(f"validate_tier should have rejected {bad!r}")


def test_validate_importance():
    validate_importance(1)
    validate_importance(50)
    validate_importance(100)


def test_validate_importance_rejects_bad():
    for bad in [0, 101, 150, -1, "fifty", 50.5]:
        try:
            validate_importance(bad)
        except ValueError:
            continue
        else:
            raise AssertionError(f"validate_importance should have rejected {bad!r}")


# ─── ttl_days ────────────────────────────────────────────────────────────

def test_anchored_is_permanent():
    assert ttl_days("anchored", importance=50) == 0
    assert ttl_days("anchored", importance=99) == 0


def test_tier_default_ttl():
    # Low importance (10) gets floor 7d; tier max(7, tier_default) wins
    assert ttl_days("semantic", importance=10) == 90   # tier default wins
    assert ttl_days("episodic", importance=10) == 30   # tier default
    assert ttl_days("reminder", importance=10) == 7    # floor matches tier
    assert ttl_days("working", importance=10) == 7     # floor exceeds tier default of 1


def test_high_importance_extends_ttl():
    # importance 80+ means at least 365 days
    assert ttl_days("semantic", importance=80) == 365
    assert ttl_days("episodic", importance=80) == 365
    # 50-79 means at least 90 days
    assert ttl_days("episodic", importance=50) == 90
    # 20-49 means at least 30 days
    assert ttl_days("working", importance=30) == 30  # but capped by tier max? no, it's max()


# ─── runner ──────────────────────────────────────────────────────────────

TESTS = [
    test_tier_prefix_wins,
    test_legacy_namespace_maps_to_tier,
    test_unprefixed_defaults_to_semantic,
    test_tier_prefix_even_with_legacy_after,
    test_namespace_of,
    test_validate_tier,
    test_validate_tier_rejects_bad,
    test_validate_importance,
    test_validate_importance_rejects_bad,
    test_anchored_is_permanent,
    test_tier_default_ttl,
    test_high_importance_extends_ttl,
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
