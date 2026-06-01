---
name: ron-memory-v4
description: "Ron-Memory v4 — second-brain memory store. Python core, no third-party deps, safe against JSON injection, supports --json output for agents."
---

# Ron-Memory v4

Second-brain memory for agents. Cross-session, tiered, Upstash-backed, with local cache for fast reads.

**v4 is a Python rewrite of the v3 bash skill.** Same tier system, same data format, but with a clean Python core instead of 6,000 lines of bash.

## What's new in v4

- **Python core** (`ron_memory/`) — stdlib only, no `pip install` needed
- **Safe JSON I/O** — fixes the v3 bash shell-injection bug where values with `"`, `|`, or newlines could corrupt Redis writes
- **`--json` flag on every verb** — for agents and scripts that want machine-readable output
- **Single source of truth for credentials** — `config.py` reads `.env.ron-memory` once; no more hardcoded tokens in 15 files
- **Real tests** — 51 unit tests covering tiers, JSON, search, rank, prune, consolidate
- **Bash shims for backward compat** — old `memory-set.sh` etc. call into Python if you want them to

## Quick Start

```bash
# Show system status
python3 -m ron_memory.cli status

# Save a memory (auto-detects tier from prefix)
python3 -m ron_memory.cli set anchored:sam_birthday "2020-04-15"
python3 -m ron_memory.cli set semantic:acasey_preferences "concise communication"

# Get a memory
python3 -m ron_memory.cli get anchored:sam_birthday

# Search by keyword
python3 -m ron_memory.cli search "Sam birthday" --limit 5

# Rank memories for a task
python3 -m ron_memory.cli rank "working on heyron project" --limit 5

# List all memories
python3 -m ron_memory.cli list

# Or with stats
python3 -m ron_memory.cli list --stats

# JSON output for any verb
python3 -m ron_memory.cli status --json
python3 -m ron_memory.cli list --json

# Sync Redis -> local cache
python3 -m ron_memory.cli sync

# Prune (dry-run by default)
python3 -m ron_memory.cli prune --dry-run
python3 -m ron_memory.cli prune --force

# Consolidate old episodic -> semantic summaries
python3 -m ron_memory.cli consolidate --days 14
```

## Memory Tiers

| Tier | TTL | Default importance | Examples |
|------|-----|--------------------|----------|
| `anchored` | permanent | 80 | Family birthdays, core identity |
| `semantic` | 90 days | 50 | Preferences, relationships, important facts |
| `episodic` | 30 days | 50 | Specific events, conversations, decisions |
| `reminder` | 7 days | 50 | Time-critical tasks |
| `working` | 1 day | 50 | What's happening now |

**Key prefix determines tier automatically.** `anchored:sam_birthday` is anchored. `episodic:trip_lakes` is episodic. Legacy namespaces (`family:`, `user:`, `project:`, etc.) still work and map to the right tier.

## CLI Reference

| Verb | Purpose |
|------|---------|
| `set <key> <value>` | Save a memory (with `--tier`, `--importance`, `--context`, `--force`, `--stale-ok`) |
| `get <key>` | Retrieve a memory (bumps access counter) |
| `delete <key>` | Remove a memory |
| `list` | List memories (`--namespace`, `--stats`, `--json`) |
| `search "<query>"` | Fuzzy search (`--limit`, `--namespace`, `--json`) |
| `rank "<task>"` | Attention-based ranking (`--limit`, `--budget`, `--namespaces`, `--json`) |
| `prune` | TTL enforcement (dry-run by default; `--force` to apply) |
| `sync` | Pull all keys from Redis into local cache |
| `consolidate` | Find old episodic entries to merge into semantic summaries |
| `status` | System health snapshot |
| `migrate-flag` | Set the v2→v3 migration flag in Redis (idempotent) |

Every verb supports `--json` for machine-readable output.

## Architecture

```
ron_memory/
├── config.py       # Loads .env.ron-memory (single source of truth)
├── tiers.py        # Tier detection, validation, TTL math
├── jsonio.py       # Safe JSON encode/decode (fixes v3 injection bug)
├── core.py         # Memory class — Redis + cache I/O
├── search.py       # Keyword search + attention-based rank
├── prune.py        # TTL enforcement
├── sync.py         # Redis -> cache
├── consolidate.py  # Episodic -> semantic grouping
└── cli.py          # argparse-based subcommands

scripts_v4_shims/   # Thin bash wrappers for backward compat
├── memory-set.sh   # exec python3 -m ron_memory.cli set "$@"
├── memory-get.sh   # exec python3 -m ron_memory.cli get "$@"
├── ... one per verb
└── memory.sh       # exec python3 -m ron_memory.cli "$@"

tests/
├── test_tiers.py        # 12 tests
├── test_jsonio.py       # 13 tests
├── test_search.py       # 11 tests
├── test_prune.py        # 8 tests
└── test_consolidate.py  # 7 tests
```

## Migration from v3

v4 is wire-compatible with v3. Existing data in Upstash works without changes. The v2-detection code in v3 was warning forever; the migration flag is now set automatically by `python3 -m ron_memory.cli migrate-flag`.

To switch a v3 cron to v4: replace the bash script with the matching shim from `scripts_v4_shims/`. The shims are 3-line wrappers that call Python with the same args.

To go fully native: skip the shims and call `python3 -m ron_memory.cli <verb> [args]` directly.

## What v4 deliberately doesn't do

- **No new features.** v4 is a faithful port of v3 minus the bugs. Embeddings, dream, synthesis, and links were moved to `archive/` for v5.
- **No `pip install` dependencies.** Stdlib only.
- **No token rotation.** The exposed TOKEN in the v3 bash files is a separate problem; the v4 core never reads the old bash files.
- **`jobs-queue.sh` is untouched.** It's a separate refactor (inter-agent task routing) and probably should be replaced with `sessions_send` calls. Out of scope for v4.

## Files

- `SKILL.md` — this file
- `ron_memory/` — the Python core
- `scripts_v4_shims/` — bash wrappers for backward compat
- `tests/` — 51 unit tests, all green
- `archive/` — old bash scripts kept for reference
- `docs/RON-MEMORY-V4-DESIGN.md` — design doc (in workspace)
