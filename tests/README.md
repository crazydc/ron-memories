# Ron-Memory v4 Test Suite

Automated tests for the v4 Python core (`ron_memory/` module). 51 unit tests, all green, no `pytest` required.

## Test Files

| Test File | Tests | Description |
|-----------|-------|-------------|
| `tests/test_tiers.py` | 12 | Tier detection, validation, TTL math, importance-aware TTLs |
| `tests/test_jsonio.py` | 13 | Safe JSON encode/decode (the v3 injection bug fix) |
| `tests/test_search.py` | 11 | Keyword search + attention-based rank |
| `tests/test_prune.py` | 8 | TTL enforcement (dry-run + execute) |
| `tests/test_consolidate.py` | 7 | Episodic → semantic merging |

## Running Tests

**Run all tests:**

```bash
cd ron-memories
for f in tests/test_*.py; do python3 "$f" 2>&1 | tail -2; done
```

**Run a single test file:**

```bash
python3 tests/test_tiers.py
```

**Run via Python module (if tests are organised as a package):**

```bash
cd tests && python3 -m unittest test_tiers
```

## Test Design

### No external dependencies
- Pure stdlib — no `pip install pytest` needed
- No network access (tests use mocks)
- No Redis connection required (pure unit tests on tier logic + JSON I/O)

### Isolation
- Each test uses unique keys with timestamps to avoid collisions
- Tests clean up after themselves

### Idempotency
- Tests are safe to run multiple times
- No shared state between tests

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| non-zero | One or more tests failed |

## Example Output

```
$ python3 tests/test_tiers.py
  ✅ test_high_importance_extends_ttl

Results: 12 passed, 0 failed
```

---

*Note: This is the v4 test suite. The v3 bash test files (`test-memory-set.sh`, etc.) and the `test-runner.sh` mentioned in old docs no longer exist — they were replaced by the Python tests during the v3→v4 rewrite.*