# Ron-Memory v4 — Python Source Checksums

Generated: 2026-06-02 (post v4 doc audit, no Python changes)

These MD5 hashes verify the v4 Python core and tests are byte-identical
to the post-rewrite state. Use this to detect any unintended modifications
to the core code.

```bash
# To re-verify:
md5sum ron_memory/*.py tests/*.py
# Compare against the values below.
```

## Core modules (`ron_memory/`)

| File | MD5 |
|------|-----|
| `ron_memory/__init__.py` | `4bd6179ffc30429fc78dc46fefcc8f10` |
| `ron_memory/cli.py` | `4846ae5462d66c399e4d362e7111ef97` |
| `ron_memory/config.py` | `9a7ee8194470e7aac2d8142a92786f3d` |
| `ron_memory/consolidate.py` | `017ae924709ffc2c5da4a650b87435ce` |
| `ron_memory/core.py` | `2a2958a7bc292c306f1bbaaa66f938e6` |
| `ron_memory/jsonio.py` | `c94c57bbe669fdd53a72ad90fc115f16` |
| `ron_memory/prune.py` | `ce649b30f07575dd0a5c6cf8490666cf` |
| `ron_memory/search.py` | `6be26aa77ca549316f1c1a76d465a455` |
| `ron_memory/sync.py` | `cca60202bdaea4112252ddf07099be20` |
| `ron_memory/tiers.py` | `52fc099b7c6b11f42c1aa9d1d4b2c566` |

## Test files (`tests/`)

| File | MD5 | Tests |
|------|-----|-------|
| `tests/test_consolidate.py` | `648612a4b64dbeda3ced5fbc32a980c7` | 7 |
| `tests/test_jsonio.py` | `75c9dc0437e6dfb0664b461f98bfb08f` | 13 |
| `tests/test_prune.py` | `cdd0ca738ab8cd23fc32db8a86286457` | 8 |
| `tests/test_search.py` | `b70e8c6023a7724b35d8b4db08cc513d` | 11 |
| `tests/test_tiers.py` | `b4d692dc81b70a223ba75d6ebd51706b` | 12 |
| **Total** | | **51 (all passing)** |

## Verification commands

```bash
# Confirm all 51 tests pass:
for f in tests/test_*.py; do python3 "$f" 2>&1 | tail -2; done

# Confirm CLI works end-to-end:
python3 -m ron_memory.cli status
# Expected: Redis ✅, write test ✅, migration done ✅

# Confirm wrapper works:
memory status
# (with scripts_v4_shims on PATH)
```

## What this file guarantees

This is **not** a substitute for git history (which is canonical). It's a
quick-verify snapshot for sanity-checking that the v4 Python core is intact
and matches what we built. If any of these hashes change unexpectedly, it
means someone (or a bot) modified the core — and that change should be
reviewed before committing.
