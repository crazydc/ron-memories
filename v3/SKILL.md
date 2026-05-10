---
name: ron-memory-v3
description: "Ron-Memory v3 — Second-brain memory for humans. Stories, reinforcement, reminders on cron."
---

# Ron-Memory v3

Cross-session memory that works like a human brain. Not just facts — stories, reinforcement, and time-critical reminders on dedicated cron.

## What's New in v3

- **Stories** — Life moments preserved alongside facts (`ron:story:*`)
- **Reinforcement** — Frequently accessed memories get boosted in relevance
- **Reminders on cron** — Not heartbeat. Dedicated 5-minute cron so reminders never miss
- **Archive namespace** — Dormant entries kept searchable, not deleted

## Quick Start

```bash
# Save a fact
./scripts/memory-set.sh user:name Dale

# Save a story (life moment)
./scripts/memory-set.sh story:holiday_2025:title "Summer Scotland road trip"
./scripts/memory-set.sh story:holiday_2025:description "Freddie loved the castles"

# Get a memory
./scripts/memory-get.sh user:name

# Find relevant memories for a task
./scripts/memory-rank.sh "working on heyron documentation"

# List all memories
./scripts/memory-list.sh --stats

# Check reminders
./scripts/memory-healthcheck.sh
```

## Core Scripts

| Script | What it does |
|--------|--------------|
| `memory-set.sh` | Save with staleness detection |
| `memory-get.sh` | Get, increments reinforce count |
| `memory-rank.sh` | Attention-based retrieval |
| `memory-sync.sh` | Sync Redis → local cache (heartbeat) |
| `memory-list.sh` | List with filters + stats |
| `memory-healthcheck.sh` | Verify Redis + cache |
| `check-reminders.sh` | Check due reminders (cron only) |

## Namespaces

| Namespace | Purpose | TTL |
|-----------|---------|-----|
| `user` | Dale's personal data | permanent |
| `family` | Family members | permanent |
| `story` | Life moments | permanent |
| `contact` | People Dale knows | permanent |
| `vehicle` | Vehicles | permanent |
| `project` | Projects | permanent |
| `goal` | Goals/milestones | permanent |
| `pref` | Preferences | 30 days |
| `service` | Accounts | 90 days |
| `reminder` | Time-critical tasks | 7 days |
| `reinforce` | Access tracking | 7 days |
| `health` | Fitness/health | permanent |
| `todo` | Action items | permanent |
| `archive` | Dormant entries | permanent |

**Story namespace** (`ron:story:*`) is new in v3 — stores life moments, not facts.

## Architecture

```
memory-set.sh → Redis + Cache
                      ↓
                 (touch reinforce:count:<key>)

memory-get.sh → Redis → Cache fallback
                      ↓
                 (increment reinforce:count:<key>)

memory-sync.sh → Redis → local cache (heartbeat, ~30min)
memory-rank.sh → Scored + filtered → Top N (token budget)

check-reminders.sh → Redis → Due reminders (cron, every 5min)
```

See `references/ARCHITECTURE.md` for full design.

## Installing v3

Tell your agent:
> "Install Ron Memory v3 from https://github.com/crazydc/ron-memories/tree/v3"

Or clone directly:
```bash
git clone https://github.com/crazydc/ron-memories.git
cd ron-memories && git checkout v3
```

## Setting Up Reminders

Reminders need their own cron (5 min interval):
```bash
crontab -e
# Add:
*/5 * * * * bash ~/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh >> /var/log/ron-reminders.log 2>&1
```

See `references/REMINDERS.md` for setup details.

## References (On Demand)

Load these when you need more detail:

| File | What it covers |
|------|----------------|
| `references/NAMESPACES.md` | All namespace schemas + examples |
| `references/SCRIPTS.md` | Full script documentation |
| `references/REMINDERS.md` | Cron setup + troubleshooting |
| `references/ARCHITECTURE.md` | v3 design decisions |

## v3 vs v2

| Feature | v2 | v3 |
|---------|----|----|
| Basic save/retrieve | ✅ | ✅ |
| Stories namespace | ❌ | ✅ |
| Reinforcement tracking | ❌ | ✅ |
| Reminders on cron | ❌ | ✅ |
| Archive namespace | cold storage | first-class |
| Local cache | ✅ | ✅ |
| Token budget retrieval | ✅ | ✅ |
