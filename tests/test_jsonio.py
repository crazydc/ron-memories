"""Tests for safe JSON I/O — the v3 bash bug was here.

Pure unit tests, no network.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ron_memory.jsonio import (  # noqa: E402
    encode_payload,
    decode_payload,
    extract_value,
    parse_key_list,
)


def test_encode_basic():
    out = encode_payload("hello", "2026-06-01T00:00:00Z", "anchored", 50)
    assert '"value": "hello"' in out
    assert '"tier": "anchored"' in out
    assert '"importance": 50' in out
    assert '"timestamp": "2026-06-01T00:00:00Z"' in out


def test_encode_with_context():
    out = encode_payload("x", "t", "semantic", 70, context="holiday,lakes")
    assert '"context": "holiday,lakes"' in out


def test_encode_escapes_quotes():
    """The v3 bug: shell-injection via unescaped quotes."""
    out = encode_payload('said "hello" loudly', "t", "semantic", 50)
    # Properly escaped: \" not bare "
    assert 'said \\"hello\\" loudly' in out or 'said \\\\"hello\\\\" loudly' in out or r'\"hello\"' in out
    # And the result is valid JSON
    import json
    parsed = json.loads(out)
    assert parsed["value"] == 'said "hello" loudly'


def test_encode_escapes_pipes_and_newlines():
    """Cache-breaking value: pipes and newlines."""
    out = encode_payload("a | b | c\nline2", "t", "semantic", 50)
    import json
    parsed = json.loads(out)
    assert parsed["value"] == "a | b | c\nline2"


def test_encode_escapes_unicode():
    out = encode_payload("café 🎉 日本", "t", "semantic", 50)
    import json
    parsed = json.loads(out)
    assert parsed["value"] == "café 🎉 日本"


def test_decode_payload_basic():
    raw = '{"result": "{\\"value\\": \\"hi\\", \\"timestamp\\": \\"t\\", \\"tier\\": \\"semantic\\", \\"importance\\": 50}"}'
    result = decode_payload(raw)
    assert result is not None
    assert result["value"] == "hi"
    assert result["tier"] == "semantic"


def test_decode_payload_already_parsed():
    """Upstash sometimes returns the inner as a dict, not a string."""
    raw = '{"result": {"value": "hi", "timestamp": "t", "tier": "semantic", "importance": 50}}'
    result = decode_payload(raw)
    assert result is not None
    assert result["value"] == "hi"


def test_decode_payload_null():
    assert decode_payload(None) is None
    assert decode_payload("") is None
    assert decode_payload("null") is None
    assert decode_payload('{"result": null}') is None


def test_decode_payload_garbage():
    assert decode_payload("not json") is None
    assert decode_payload('{"result": "also not json"}') is None


def test_extract_value():
    raw = '{"result": "{\\"value\\": \\"hello\\", \\"timestamp\\": \\"t\\"}"}'
    assert extract_value(raw) == "hello"
    assert extract_value(None) == ""
    assert extract_value("garbage") == ""


def test_parse_key_list():
    raw = '{"result": ["ron:a", "ron:b", "ron:c"]}'
    assert parse_key_list(raw) == ["ron:a", "ron:b", "ron:c"]


def test_parse_key_list_null():
    assert parse_key_list(None) == []
    assert parse_key_list("") == []
    assert parse_key_list("null") == []


def test_parse_key_list_garbage():
    assert parse_key_list("not json") == []


# ─── runner ──────────────────────────────────────────────────────────────

TESTS = [
    test_encode_basic,
    test_encode_with_context,
    test_encode_escapes_quotes,
    test_encode_escapes_pipes_and_newlines,
    test_encode_escapes_unicode,
    test_decode_payload_basic,
    test_decode_payload_already_parsed,
    test_decode_payload_null,
    test_decode_payload_garbage,
    test_extract_value,
    test_parse_key_list,
    test_parse_key_list_null,
    test_parse_key_list_garbage,
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
