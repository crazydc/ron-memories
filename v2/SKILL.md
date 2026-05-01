---
name: ron-memory-v2
description: "Ron-Memory v2 — Cross-session memory with curation, summarization, staleness detection, and attention-based retrieval."
---

# Ron-Memory v2

Cross-session memory with intelligent curation. Builds on v1 with TTL enforcement, summarization, staleness detection, and attention-based retrieval.

## New in v2

- **Summarization** — long entries are compressed before archival
- **Staleness detection** — warns on conflicting updates before overwriting
- **TTL enforcement** — per-namespace TTLs via `memory-prune.sh`
- **Attention-based retrieval** — `memory-rank.sh` returns the most relevant memories within a token budget
- **Cold storage** — stale entries moved to `archive:` prefix instead of deleted
- **Access tracking** — foundation for "never accessed" detection (future)

## Quick Start

```bash
# Save (with staleness check)
./scripts/memory-set.sh user_name "Dale"

# Get
./scripts/memory-get.sh user_name

# Rank memories for a task
./scripts/memory-rank.sh "working on heyron documentation"

# Audit for stale/conflicting entries
./scripts/memory-audit.sh --all

# Prune expired entries (dry-run first)
./scripts/memory-prune.sh --dry-run
```

## Core Scripts

| Script | What it does |
|--------|--------------|
| `memory-set.sh` | Save with staleness detection + optional compression |
| `memory-get.sh` | Get, with --full to retrieve archived summaries |
| `memory-rank.sh` | Attention-based retrieval — returns relevant memories within budget |
| `memory-audit.sh` | Audit for stale entries, conflicts, never-accessed keys |
| `memory-prune.sh` | Enforce TTLs — moves expired entries to archive |
| `memory-list.sh` | List all with --stats, --summarize, --namespace filters |

## Namespace TTL Defaults

| Namespace | TTL | Rationale |
|-----------|-----|----------|
| `user` | permanent | Core identity |
| `family` | permanent | Rarely changes |
| `contact` | permanent | Stable relationships |
| `vehicle` | permanent | Long-term assets |
| `project` | permanent | Ongoing work |
| `goal` | permanent | Milestones |
| `pref` | 30 days | Preferences change |
| `service` | 90 days | Accounts evolve |
| `reminder` | 7 days | Short-term tasks |
| `working` | 24h | Temporary context |
| `archive` | permanent | Historical data |

## How v2 Handles the Curation Problem

Roby's article "Stuck in the Middle with You" argues that memory is about **selection, not storage** — agents need to curate what's hot vs cold. Ron-Memory v2 addresses this:

### Signal vs Noise
- `memory-rank.sh` uses freshness + relevance scoring instead of dumping all memories into context
- Token budget prevents context overflow

### Staleness
- `memory-set.sh` warns on conflicting updates
- `memory-audit.sh --conflicts` surfaces what changed
- `archive:` prefix preserves history without cluttering active memory

### Compression
- Entries over threshold (500 chars) get compressed before archival
- Full version preserved; active context gets the summary

### Pruning
- `memory-prune.sh` enforces TTLs automatically
- Moves to archive instead of deleting — nothing is ever truly lost

## Architecture

```
memory-set.sh ──▶ Staleness check ──▶ Redis + Cache
                                    │
                              ┌─────┴─────┐
                              │ Compress? │
                              └───────────┘
                                    │
                              ┌─────▼─────┐
                              │  Archive  │
                              │ (if TTL)  │
                              └───────────┘

memory-rank.sh ──▶ Score all entries ──▶ Filter by context ──▶ Token budget cap ──▶ Top N
```

## File Structure

```
ron-memory/v2/
├── scripts/
│   ├── config.sh          # TTL defaults, thresholds, storage paths
│   ├── memory-set.sh      # Save with staleness + compression
│   ├── memory-get.sh      # Get with --full for summaries
│   ├── memory-rank.sh     # Attention-based retrieval
│   ├── memory-audit.sh     # Stale/conflict/never-accessed checks
│   ├── memory-prune.sh     # TTL enforcement (dry-run default)
│   └── memory-list.sh     # List with stats/summarize/filters
├── references/
│   └── .env.example      # Credentials template
├── archive/              # (created at runtime) archived entries
├── SKILL.md              # This file
└── README.md             # User-facing documentation
```

## v1 vs v2

| Feature | v1 | v2 |
|---------|----|----|
| Basic save/retrieve | ✅ | ✅ |
| Redis + local cache | ✅ | ✅ |
| Namespace structure | ✅ | ✅ |
| Trigger phrases | ✅ | ✅ |
| Staleness detection | ❌ | ✅ |
| Summarization | ❌ | ✅ |
| Attention-based retrieval | ❌ | ✅ |
| TTL enforcement | ❌ | ✅ |
| Archive vs delete | ❌ | ✅ |
| Token budget retrieval | ❌ | ✅ |

## Installation

Same as v1 — tell your agent:

> "Install the Ron Memory v2 skill from https://github.com/crazydc/ron-memories/tree/v2"

Or clone directly:

```bash
git clone https://github.com/crazydc/ron-memories.git
cd ron-memories && git checkout v2
```
