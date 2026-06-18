"""Tests for touch + importance-weighted search/rank. No network."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ron_memory.search import search, rank  # noqa: E402


# Sample where two entries match the query with identical content but
# different importance. High-importance should rank first.
SAMPLE = [
    {"key": "user:kids:sam:park", "value": "Took Sam to the park on Sunday", "tier": "semantic", "importance": 10, "timestamp": "2026-05-27T10:00:00Z"},
    {"key": "anchored:acasey:work", "value": "Currently working on the work agent Code Review and fitness-app", "tier": "anchored", "importance": 90, "timestamp": "2026-05-27T10:00:00Z"},
    {"key": "episodic:park_2026", "value": "Took Sam to the park on Sunday. It rained.", "tier": "episodic", "importance": 30, "timestamp": "2026-05-27T10:00:00Z"},
]


def test_search_high_importance_ranks_first():
    """Two entries with same text overlap, different importance.
    High importance should win."""
    results = search(SAMPLE, "park", limit=10)
    assert len(results) >= 1
    # The two "park" entries: importance=10 and importance=30
    park_results = [r for r in results if "park" in r["key"].lower()]
    assert len(park_results) == 2
    # Higher importance should be first
    assert park_results[0]["importance"] > park_results[1]["importance"], \
        f"Expected high importance first, got {park_results[0]['importance']} before {park_results[1]['importance']}"


def test_search_anchored_tier_with_low_importance_loses_to_high_importance_semantic():
    """Even with anchored tier boost (20), a low-importance anchored entry
    should lose to a high-importance semantic entry when the query matches
    the high-importance one better."""
    sample = [
        # Low importance anchored (tier boost 20, importance boost 3)
        {"key": "anchored:random", "value": "A note about dogs", "tier": "anchored", "importance": 10, "timestamp": "2026-05-27T10:00:00Z"},
        # High importance semantic (tier boost 10, importance boost 27)
        {"key": "semantic:acasey:work", "value": "Working on dogs project at work", "tier": "semantic", "importance": 90, "timestamp": "2026-05-27T10:00:00Z"},
    ]
    results = search(sample, "dogs", limit=10)
    # Both match, but the high-importance one should rank first
    # because importance dominates
    assert results[0]["key"] == "semantic:acasey:work"
    assert results[0]["importance"] == 90


def test_rank_uses_importance():
    """rank() should also weight by importance, not just tier."""
    sample = [
        {"key": "anchored:low", "value": "Board games on Tuesday", "tier": "anchored", "importance": 10, "timestamp": "2026-05-27T10:00:00Z"},
        {"key": "semantic:high", "value": "Board games critical for team", "tier": "semantic", "importance": 95, "timestamp": "2026-05-27T10:00:00Z"},
    ]
    results = rank(sample, "board games", limit=10)
    assert results[0]["importance"] == 95
    assert results[1]["importance"] == 10


def test_search_zero_importance_still_matches_but_low_score():
    """An entry with importance=1 should still be searchable, just at the bottom."""
    sample = [
        {"key": "user:test", "value": "Critical info about acasey", "tier": "semantic", "importance": 1, "timestamp": "2026-05-27T10:00:00Z"},
    ]
    results = search(sample, "acasey", limit=10)
    assert len(results) == 1
    # Just verify it's reachable, score should be low
    assert results[0]["score"] < 30


def test_search_score_importance_component():
    """Verify the importance component is added to the score as expected.

    score = overlap*5 + tier_boost + importance*0.3 + recency
    For importance=100, that's +30. For importance=1, that's ~+0.
    """
    base = {"key": "x", "value": "match", "tier": "semantic", "timestamp": "2026-05-27T10:00:00Z"}
    low = search([{**base, "importance": 1}], "match")[0]["score"]
    high = search([{**base, "importance": 100}], "match")[0]["score"]
    # High should be ~30 points higher (30 - 0.3 ~= 29.7)
    assert high - low >= 28, f"Expected ~30 score diff, got {high - low}"


if __name__ == "__main__":
    test_search_high_importance_ranks_first()
    test_search_anchored_tier_with_low_importance_loses_to_high_importance_semantic()
    test_rank_uses_importance()
    test_search_zero_importance_still_matches_but_low_score()
    test_search_score_importance_component()
    print("Results: 5 passed, 0 failed")
