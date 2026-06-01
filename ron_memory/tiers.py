"""Tier + namespace logic. Single source of truth.

A memory's *tier* determines its TTL and retrieval priority. The tier is
either:
  1. Explicit via a tier prefix in the key (e.g. "anchored:sam_birthday")
  2. Inferred from a legacy namespace prefix (e.g. "family:sam_birthday" -> anchored)
  3. Defaulted to "semantic" if neither applies
"""

from __future__ import annotations

from .config import LEGACY_NAMESPACE_TIER, TIER_TTL, TIER_BOOST

VALID_TIERS = set(TIER_TTL.keys())


def detect_tier(key: str) -> str:
    """Detect the tier from a key.

    Order:
      1. Tier prefix wins (anchored:, semantic:, episodic:, reminder:, working:)
      2. Legacy namespace prefix maps to a tier
      3. Default to semantic
    """
    if not key:
        return "semantic"

    # Tier prefix
    if ":" in key:
        prefix = key.split(":", 1)[0]
        if prefix in VALID_TIERS:
            return prefix

    # Legacy namespace
    if ":" in key:
        prefix = key.split(":", 1)[0]
        if prefix in LEGACY_NAMESPACE_TIER:
            return LEGACY_NAMESPACE_TIER[prefix]

    # Default
    return "semantic"


def namespace_of(key: str) -> str:
    """Return the namespace (the part before the first colon).

    For "anchored:family:sam" this returns "anchored".
    For "anchored:sam" this returns "anchored".
    For unprefixed keys this returns the whole key.
    """
    if ":" not in key:
        return key
    return key.split(":", 1)[0]


def is_valid_tier(tier: str) -> bool:
    return tier in VALID_TIERS


def validate_tier(tier: str) -> None:
    if not is_valid_tier(tier):
        raise ValueError(
            f"Invalid tier: {tier!r}. "
            f"Valid tiers: {', '.join(sorted(VALID_TIERS))}"
        )


def validate_importance(importance: int) -> None:
    if not isinstance(importance, int) or importance < 1 or importance > 100:
        raise ValueError(f"Invalid importance: {importance!r} (must be int 1-100)")


def ttl_days(tier: str, importance: int = 50) -> int:
    """Effective TTL: max of tier default and importance floor.

    anchored always returns 0 (permanent) regardless of importance.
    """
    if tier == "anchored":
        return 0
    tier_default = TIER_TTL.get(tier, 90)
    # Find the highest importance floor that applies.
    # Thresholds: 80->365d, 50->90d, 20->30d, 0->7d
    importance_floors = {80: 365, 50: 90, 20: 30, 0: 7}
    floor = 0
    for threshold in sorted(importance_floors.keys(), reverse=True):
        if importance >= threshold:
            floor = importance_floors[threshold]
            break
    return max(tier_default, floor) if tier_default > 0 else floor
