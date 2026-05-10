# Ron-Memory v3 — Quick Reference Card

> One-page cheat sheet for the essentials. Print it, pin it, use it.

---

## 📖 Glossary

- **Cron** = a clock that runs tasks automatically at set times
- **Redis** = cloud database that stores your memories

---

## 🚀 First-Time Setup

**Easiest way:** run `./memory-setup.sh` and answer the questions. It handles steps 2–4 automatically.

Manual steps if you prefer:

```bash
# 1. Clone the repo (if not already installed)
git clone https://github.com/crazydc/ron-memories.git
cd ron-memories && git checkout v3

# 2. Set up Redis credentials (if Upstash)
cp .env.example .env.ron-memory
# Edit .env.ron-memory with your UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN

# 3. Set up reminder cron (critical!)
crontab -e
# Add this line:
*/5 * * * * bash ~/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh >> /var/log/ron-reminders.log 2>&1

# 4. Verify everything works
./scripts/memory-healthcheck.sh
```

---

## ⚡ Top 10 Commands

| Command | What it does |
|---------|--------------|
| `./memory-set.sh user:name "Alex"` | Save a fact |
| `./memory-get.sh user:name` | Get a fact |
| `./memory-set.sh story:holiday:title "Summer road trip"` | Save a life story |
| `./memory-rank.sh "working on your docs project"` | Find relevant memories for a task |
| `./memory-list.sh --stats` | See all memories + counts |
| `./memory-sync.sh` | Sync Redis → local cache |
| `./memory-healthcheck.sh` | Check everything is working |
| `./check-reminders.sh` | Check due reminders (cron script) |
| `./memory-prune.sh --dry-run` | Preview what would be archived |
| `./memory-get.sh reminder:dentist:due` | Get a reminder's due time |

---

## 🏷️ Namespace Quick Guide

| Namespace | Use it for... | TTL |
|-----------|---------------|-----|
| `user:*` | Your personal data (name, birthday, prefs) | permanent |
| `family:*` | Family members (Sam, Riley, Cooper) | permanent |
| `contact:*` | People you know (colleagues, friends) | permanent |
| `story:*` | Life moments (holidays, milestones) | permanent |
| `project:*` | Projects (Heyron, fitness-app) | permanent |
| `goal:*` | Goals and milestones | permanent |
| `vehicle:*` | Cars, bikes | permanent |
| `health:*` | Fitness, weight | permanent |
| `todo:*` | Action items | permanent |
| `reminder:*` | Time-critical tasks with due dates | 7 days |
| `pref:*` | Preferences | 30 days |
| `service:*` | Subscriptions, accounts | 90 days |
| `reinforce:*` | Access tracking (auto-managed) | 7 days |
| `archive:*` | Dormant entries (don't delete, archive!) | permanent |

**Key pattern:** `ron:<namespace>:<subject>:<attribute>`
Example: `ron:family:sam:birthday` → `2020/04/15`

---

## ✍️ Key Naming Patterns

```
Good:
  ron:user:name
  ron:project:heyron:status
  ron:family:sam:birthday
  ron:story:coast_2025:title

Bad:
  ron:userName (camelCase — inconsistent)
  ron:my_project (missing subject)
  ron:facts_about_stuff (too vague)
```

**Rules:**
- Lowercase only
- Use `:separator` for nesting (max 3 levels)
- Single values per key (not arrays)
- Dates: `YYYY/MM/DD` or `YYYY-MM-DD`

---

## 🔧 Troubleshooting

### Glossary
- **Cron** = a clock that runs tasks automatically at set times
- **Redis** = cloud database that stores your memories

### 1. "Redis connection refused"
```bash
# Check Redis is running
redis-cli ping
# Or check Upstash credentials in .env.ron-memory
cat ~/.openclaw/workspace/.env.ron-memory | grep UPSTASH
```

### 2. "memory-get returns nothing / wrong value"
```bash
# Sync from Redis to local cache
./memory-sync.sh
# Then try get again
./memory-get.sh <key>
```

### 3. "Reminders not firing"
```bash
# Check cron is installed
crontab -l | grep ron
# Should show: */5 * * * * ...check-reminders.sh

# Test script manually
bash /root/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh
# Should output due reminders or nothing

# Check the log
cat /var/log/ron-reminders.log
```

### 4. "Wrong times / timezone issues"
- Reminders stored in UTC
- System timezone affects cron execution
- Check: `date` (shows system time)
- Fix: `timedatectl` or set TZ env var

### 5. "Stale data / old values"
```bash
# Force overwrite with --force
./memory-set.sh <key> <new_value> --force

# Run prune to archive old entries
./memory-prune.sh --dry-run  # Preview first
./memory-prune.sh --execute  # Then execute
```

---

## 📋 Story Example (v3 feature)

Stories capture life moments — not facts, moments:

```bash
# Save a story
./memory-set.sh story:coast_2025:title "Summer road trip with the family"
./memory-set.sh story:coast_2025:description "Drove up to coast, saw castles, Sam loved it"
./memory-set.sh story:coast_2025:date "2025-08-10"
./memory-set.sh story:coast_2025:tags "holiday,family,adventure"

# List stories
./memory-list.sh --summarize
```

---

## 📁 File Locations

| What | Where |
|------|-------|
| Scripts | `~/.openclaw/skills/ron-memory/v3/scripts/` |
| Config | `~/.openclaw/workspace/.env.ron-memory` |
| Local cache | `~/.openclaw/workspace/memory/ron-memory.md` |
| Reminder log | `/var/log/ron-reminders.log` |

---

_Built for humans who forget things. That's the point._