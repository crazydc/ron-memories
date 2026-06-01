"""Safe JSON I/O — replaces the dangerous string-interpolated JSON in v3 bash.

All Redis payloads go through here. No exceptions. No shell interpolation.
"""

from __future__ import annotations

import json
from typing import Any


def encode_payload(
    value: str,
    timestamp: str,
    tier: str,
    importance: int,
    context: str = "",
    extra: dict[str, Any] | None = None,
) -> str:
    """Build a JSON payload for a memory. Returns a string ready for HTTP POST.

    Uses json.dumps which properly escapes quotes, newlines, and control chars.
    This is the fix for the v3 JSON-injection bug.
    """
    payload: dict[str, Any] = {
        "value": value,
        "timestamp": timestamp,
        "tier": tier,
        "importance": importance,
    }
    if context:
        payload["context"] = context
    if extra:
        payload.update(extra)
    return json.dumps(payload, ensure_ascii=False)


def decode_payload(raw: str | None) -> dict[str, Any] | None:
    """Decode an Upstash response.

    Upstash nests the actual payload as a JSON string inside result:
      {"result": "{\"value\": \"...\", \"timestamp\": \"...\"}"}

    Returns None if raw is empty/null/None, or if parsing fails.
    """
    if not raw or raw == "null":
        return None
    try:
        outer = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return None
    inner_str = outer.get("result")
    if not inner_str or inner_str == "null":
        return None
    # result may be already-parsed dict, or a JSON string of a dict
    if isinstance(inner_str, dict):
        return inner_str
    try:
        return json.loads(inner_str)
    except (json.JSONDecodeError, TypeError):
        return None


def extract_value(raw: str | None) -> str:
    """Convenience: just the value string from a payload."""
    payload = decode_payload(raw)
    if payload is None:
        return ""
    return str(payload.get("value", ""))


def parse_key_list(raw: str | None) -> list[str]:
    """Parse Upstash keys response into a list."""
    if not raw or raw == "null":
        return []
    try:
        outer = json.loads(raw)
        result = outer.get("result", [])
        if isinstance(result, list):
            return [str(k) for k in result]
    except (json.JSONDecodeError, TypeError):
        pass
    return []
