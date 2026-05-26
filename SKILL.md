---
name: ron-memory-v3
description: "Ron-Memory v3 — Second-brain memory for humans with memory tiers and importance scoring."
---

# Ron-Memory v3

Cross-session memory that works like a human brain. Not just facts — stories, reinforcement, time-critical reminders, and now **memory tiers** for smarter retrieval.

## What's New in v3.1

- **Memory Tiers** — anchored, semantic, episodic, reminder, working
- **Importance Scoring** — 1-100 importance affects persistence
- **Tier-Aware Retrieval** — anchored memories always score higher
- **Consolidation Script** — Like human sleep: condense episodic → semantic

## Memory Tiers

| Tier | TTL | Examples |
|------|-----|----------|
| `anchored` | permanent | Family birthdays, core identity, never-forget |
| `semantic` | 90 days | Preferences, relationships, important facts |
| `episodic` | 30 days | Specific events, conversations, decisions |
| `reminder` | 7 days | Time-critical tasks |
| `working` | 1 day | What's happening now |

**Key prefixes:** `anchored:`, `semantic:`, `episodic:`, `reminder:`, `working:`

## Quick Start

```bash
# Save a fact (auto-detects tier from prefix)
./scripts/memory-set.sh anchored:sam_birthday "2020-04-15"
./scripts/memory-set.sh semantic:acasey_preferences "concise communication"

# Save with explicit tier + importance
./scripts/memory-set.sh "trip_lakes" "lakes holiday" --tier episodic --importance 70

# Get a memory
./scripts/memory-get.sh anchored:sam_birthday

# Find relevant memories for a task (tier-aware)
./scripts/memory-rank.sh "family birthday"

# List all memories
./scripts/memory-list.sh --stats

# Consolidate old episodic → semantic (run weekly)
./scripts/memory-consolidate.sh

# Check reminders
./scripts/memory-healthcheck.sh
```

## Core Scripts

| Script | What it does |
|--------|--------------|
| `memory-set.sh` | Save with tier + importance support |
| `memory-get.sh` | Get, increments reinforce count |
| `memory-rank.sh` | Attention-based retrieval (tier-aware) |
| `memory-sync.sh` | Sync Redis → local cache (heartbeat) |
| `memory-list.sh` | List with filters + stats |
| `memory-healthcheck.sh` | Verify Redis + cache |
| `memory-consolidate.sh` | Summarize episodic → semantic (like sleep) |
| `check-reminders.sh` | Check due reminders (cron only) |

## Importance Scoring

When saving, you can set importance 1-100:

- **80-100:** Critical (birthdays, health, core preferences)
- **50-79:** Normal (day-to-day facts)
- **20-49:** Low (misc notes, temporary info)
- **1-19:** Transient (working memory, ephemeral)

Higher importance = memory persists longer even in same tier.

## Retrieval Scoring

When `memory-rank.sh` runs, memories score by:
1. **Freshness** — newer = higher (30 day window)
2. **Tier boost** — anchored +20, semantic +10, episodic +5, reminder +3, working +2
3. **Keyword match** — family keywords for family namespace, etc.

## Consolidation (Like Human Sleep)

Run `memory-consolidate.sh` weekly to:
1. Find episodic memories older than 14 days
2. Group by topic
3. Summarize into semantic memories
4. Archive originals

This keeps episodic pool fresh while preserving essence in semantic.

## Namespace Mapping (Legacy → Tier)

| Old Namespace | Tier | TTL |
|---------------|------|-----|
| `user`, `family`, `contact`, `vehicle` | anchored | permanent |
| `pref`, `project`, `goal`, `service`, `agent` | semantic | 90 days |
| `reminder` | reminder | 7 days |
| (new) | episodic | 30 days |
| (new) | working | 1 day |

**Note:** Old namespaces still work — they auto-map to tiers in memory-set.sh.

## Architecture

```
memory-set.sh → Redis (tier + importance stored)
                      ↓
                 (touch reinforce:count:<key>)

memory-get.sh → Redis → Cache fallback
                      ↓
                 (increment reinforce:count:<key>)

memory-sync.sh → Redis → local cache (heartbeat, ~30min)
memory-rank.sh → Scored by freshness + tier + keywords → Top N
memory-consolidate.sh → episodic → semantic (weekly cron)

check-reminders.sh → Redis → Due reminders (cron, every 5min)
```

## Setting Up Reminders

Reminders need their own cron (5 min interval):
```bash
crontab -e
# Add:
*/5 * * * * bash ~/.openclaw/skills/ron-memory/scripts/check-reminders.sh >> /var/log/ron-reminders.log 2>&1
```

## Files

- `/root/.openclaw/workspace/docs/AI-MEMORY-SYSTEMS.md` — Full research on memory tiers
- `/root/.openclaw/workspace/TOOLS.md` — Updated commands reference

---

## Migrating from v2

If upgrading from v2:
1. Update `config.sh` — new TTL settings
2. Update `memory-set.sh` — new flags
3. Update `memory-rank.sh` — tier boosts
4. Run `memory-list.sh --stats` to see namespace distribution

## v3.1 vs v3.0

| Feature | v3.0 | v3.1 |
|---------|------|------|
| Basic save/retrieve | ✅ | ✅ |
| Memory tiers | ❌ | ✅ |
| Importance scoring | ❌ | ✅ |
| Tier-aware retrieval | ❌ | ✅ |
| Consolidation script | ❌ | ✅ |
| Stories namespace | ✅ | ✅ |
| Reinforcement tracking | ✅ | ✅ |
| Reminders on cron | ✅ | ✅ |