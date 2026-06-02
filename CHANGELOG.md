# Ron-Memory Changelog

All notable changes are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/).

---

## [3.0.0] - 2026-05-10

### Added

- **Story namespace** (`ron:story:*`) — Life moments for reminiscing, not functionally useful, just human
- **Reinforce namespace** (`ron:reinforce:*`) — Memory access tracking for reinforcement scoring
- **Archive namespace** (`ron:archive:*`) — Dormant entries kept searchable instead of deleted
- **check-reminders.sh** — Dedicated reminder checker designed for cron (every 5 min)
- **Reminders on cron** — Time-critical reminders NOT on heartbeat, on dedicated 5-min cron
- **Story bonus in ranking** — `+20` score boost for `ron:story:*` keys during relevance ranking

### Changed

- **memory-get.sh** — Now tracks access count (`reinforce:count:<key>`) and last access time (`reinforce:last:<key>`)
- **memory-set.sh** — Now touches `reinforce:last:<key>` on save for freshness
- **SKILL.md** — Progressive disclosure: main file < 500 lines, detailed docs in `references/`
- **File structure** — Moved to `v3/` subfolder with `references/` for on-demand docs

### Removed

- `--compress` flag from memory-set.sh (simplified)
- `--archive` flag from memory-get.sh (simplified)
- `archive:` prefix — replaced by `ron:archive:*` namespace

### Fixed

- Embedded credentials (was relying on external config.sh which caused issues)

---

## [2.0.0] - 2026-04-30

### Added

- **Summarization** — Long entries compressed before archival (500 char threshold)
- **Staleness detection** — Warns on conflicting updates before overwriting
- **TTL enforcement** — Per-namespace TTLs via `memory-prune.sh`
- **Attention-based retrieval** — `memory-rank.sh` returns relevant memories within token budget
- **Cold storage** — Stale entries moved to `archive:` prefix instead of deleted
- **memory-audit.sh** — Audit for stale entries, conflicts, never-accessed keys
- **memory-prune.sh** — TTL enforcement (dry-run default)
- **memory-rank.sh** — Reinforcement learning-inspired scoring

### Changed

- Namespace structure became more hierarchical
- Added namespace TTL defaults (user=permanent, pref=30d, reminder=7d, etc.)

---

## [1.0.0] - 2026-04-01

### Added

- Basic save/retrieve (`memory-set.sh`, `memory-get.sh`)
- Redis + local cache dual storage
- Namespace structure (`ron:user:*`, `ron:contact:*`, etc.)
- Trigger phrase detection (`check-triggers.sh`)
- `memory-sync.sh` for Redis → cache sync
- `memory-list.sh` for browsing entries
- `memory-learn.sh` for instruction-based learning

---

## [4.0.0] - 2026-06-02

### Changed (docs)

- **README.md** — Rewrote install steps and command examples to use v4 `memory` wrapper and Python CLI. Removed v3-only setup script (`memory-setup.sh`) references.
- **QUICKREF.md** — Rewrote as v4 one-page cheat sheet (tiers, key patterns, troubleshooting).
- **INSTALLATION_GUIDE.md** — Rewrote end-to-end install for v4: `git clone` + `git checkout v4-python-core` + `.env.ron-memory` + optional wrapper symlink.
- **AGENT-QUEUE-SYSTEM.md** — Updated command examples from v3 `memory-X.sh` paths to v4 `memory` wrapper.

### Deprecated (docs)

- **references/ARCHITECTURE.md** — v3 architecture doc, kept for historical reference. v4 architecture is in `SKILL.md`.
- **references/STORIES.md** — v3 stories feature. v4 stores life moments under `semantic:` / `episodic:` tiers.
- **references/REMINDERS.md** — v3 reminder cron. v4 is a library, not a service — use OpenClaw cron for scheduling.
- **references/SCRIPTS.md** — v3 script reference, replaced by redirect stub pointing to `SKILL.md`.
- **tests/README.md** — v3 bash test suite. Replaced with v4 Python test documentation.

---

## Prior Art

Ron-Memory was inspired by:
- "Stuck in the Middle with You" (Roby) — Memory is about selection, not storage
- spaced repetition systems — Frequent access = higher retention
- human autobiographical memory — Stories are as important as facts
