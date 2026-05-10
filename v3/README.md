# Ron-Memory

**Cross-session memory for AI agents — like a human brain, but better.**

Ron-Memory gives your AI assistants persistent memory that survives session restarts. It stores facts, stories, preferences, and more using Upstash Redis + local file caching.

Built for [Heyron.ai](https://heyron.ai) and OpenClaw, but works anywhere with bash + curl.

---

## What It Does

- **Saves memories** to Upstash Redis with timestamps
- **Reads instantly** from local cache (Redis fallback)
- **Syncs automatically** via heartbeat or cron
- **Triggers on voice** — "remember that...", "don't forget..."
- **Never loses data** — archive instead of delete
- **Stories** — life moments alongside facts
- **Reinforcement** — frequently accessed memories rank higher

---

## Quick Start

```bash
# Save a memory
./scripts/memory-set.sh user:name Alex

# Get a memory
./scripts/memory-get.sh user:name
# → Alex

# Rank memories for a task
./scripts/memory-rank.sh "working on heyron documentation"

# List all memories
./scripts/memory-list.sh --stats
```

---

## Namespaces

Organize memories by type:

| Namespace | Example |
|-----------|---------|
| `user` | `user:name`, `user:birthday` |
| `story` | `story:holiday_2025:title` |
| `family` | `family:sam:birthday` |
| `contact` | `contact:dave:role` |
| `project` | `project:heyron:status` |
| `vehicle` | `vehicle:car:reg` |
| `reminder` | `reminder:dentist:message` |

See [references/NAMESPACES.md](references/NAMESPACES.md) for full list.

---

## Versions

| Version | What it does |
|---------|--------------|
| **v3** (latest) | Stories, reinforcement, reminders on cron |
| **v2** | Curation, TTL, staleness detection |
| **v1** | Basic save/retrieve, Redis + cache |

**Recommended:** v3 — the most human-like memory system.

---

## Upgrading from v2

If you're migrating from v2, run the migration script:

```bash
cd ~/.openclaw/skills/ron-memory/v3

# Preview what will be migrated
./scripts/memory-migrate-v2-to-v3.sh --dry-run

# Actually migrate (when ready)
./scripts/memory-migrate-v2-to-v3.sh --force
```

The script converts v2 keys to v3 format:
- `user_name` → `user:acasey:name`
- `user:preference:*` → `pref:*`
- `user:pref:*` → `pref:*`

Entries already in v3 format (`family:*`, `story:*`, `vehicle:*`, etc.) are skipped automatically.

**Note:** The script operates on the local cache file. Your Redis is updated with the new v3 keys.

---

## Installation

See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) for detailed setup.

**One-liner for Heyron.ai / OpenClaw:**
```
"Install Ron Memory v3 from https://github.com/crazydc/ron-memories"
```

---

## Documentation

| File | What it's for |
|------|---------------|
| [SKILL.md](SKILL.md) | Entry point for agents |
| [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) | Step-by-step install |
| [references/NAMESPACES.md](references/NAMESPACES.md) | All namespaces + schemas |
| [references/SCRIPTS.md](references/SCRIPTS.md) | Full script docs |
| [references/REMINDERS.md](references/REMINDERS.md) | Cron setup for reminders |
| [references/ARCHITECTURE.md](references/ARCHITECTURE.md) | Design decisions |

---

## License

MIT — use it, break it, improve it.
