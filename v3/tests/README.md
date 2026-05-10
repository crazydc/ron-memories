# Ron-Memory v3 Test Suite

Automated tests for Ron-Memory v3 scripts.

## Test Files

| Test | Description |
|------|-------------|
| `test-memory-set.sh` | Test save functionality |
| `test-memory-get.sh` | Test retrieval functionality |
| `test-memory-sync.sh` | Test Redis-to-cache sync |
| `test-memory-rank.sh` | Test attention-based ranking |
| `test-memory-list.sh` | Test listing and filtering |

## Running Tests

### Run All Tests

```bash
cd ~/.openclaw/skills/ron-memory/v3/tests
./test-runner.sh
```

### Run Specific Test

```bash
./test-runner.sh --test test-memory-set
```

### List Available Tests

```bash
./test-runner.sh --list
```

## Test Design

### Isolation
- Each test uses unique keys prefixed with `test:TEMP:` and a timestamp/PID suffix
- Tests clean up after themselves via `trap cleanup EXIT`

### Idempotency
- Tests are safe to run multiple times
- Each test sets up its own test data
- Cleanup ensures no side effects between runs

### Dependencies
- Tests require access to Upstash Redis (configured in parent scripts)
- Tests require `python3` for JSON parsing

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |

## Example Output

```
╔════════════════════════════════════════╗
║   Ron-Memory v3 Test Suite             ║
╚════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running: test-memory-set.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Testing basic memory save...
✅ PASS: Basic save works
...

Results: 5 passed, 0 failed (total: 5)

All tests passed! ✓
```