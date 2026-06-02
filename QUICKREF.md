# Ron-Memory v4 — Quick Reference Card

> One-page cheat sheet for the essentials. Print it, pin it, use it.

---

## 📖 Glossary

- **Tier** = how long a memory lasts (anchored/semantic/episodic/reminder/working)
- **Redis** = cloud database that stores your memories
- **TTL** = time-to-live in days; how long before a memory is eligible for pruning

---

## 🚀 First-Time Setup

**Easiest way:** create `.env.ron-memory` with your Upstash credentials, then start using it.

```bash
# 1. Clone the repo
git clone https://github.com/crazydc/ron-memories.git
cd ron-memories && git checkout v4-python-core

# 2. Set up Redis credentials
cat > .env.ron-memory <<'EOF'
UPSTASH_REDIS_REST_URL=https://your-db.upstash.io
UPSTASH_REDIS_REST_TOKEN=your-token-here
EOF

# 3. (Optional) install the `memory` wrapper
ln -s "$(pwd)/scripts_v4_shims/memory.sh" ~/.openclaw/workspace/scripts/memory

# 4. Verify everything works
memory status
```

---

## ⚡ Top 10 Commands

| Command | What it does |
|---------|--------------|
| `memory set anchored:user_name "Alex"` | Save a fact |
| `memory get anchored:user_name` | Get a fact |
| `memory set semantic:jordan_gift_idea "kitchen gadget"` | Save a life detail |
| `memory rank "working on your docs project"` | Find relevant memories for a task |
| `memory list --stats` | See all memories + counts |
| `memory sync` | Sync Redis → local cache |
| `memory status` | Check everything is working |
| `memory search "sam birthday"` | Keyword search |
| `memory prune --dry-run` | Preview what would be archived |
| `memory get reminder:call_dentist` | Get a reminder's value |

---

## 🏷️ Tier Quick Guide

| Tier | Use it for... | TTL |
|------|---------------|-----|
| `anchored:*` | Family, identity, car reg, things you never want to forget | permanent |
| `semantic:*` | Preferences, project info, important facts | 90 days |
| `episodic:*` | Specific events, conversations, decisions | 30 days |
| `reminder:*` | Time-critical tasks with due dates | 7 days |
| `working:*` | Current context, "what's happening now" | 1 day |

**Key pattern:** `<tier>:<subject>:<attribute>` (or just `<tier>:<key>` for simple keys)
Example: `anchored:sam_birthday` → `2020/04/15`

Legacy namespaces (`family:`, `user:`, `project:`, etc.) still work and map to the right tier automatically.

---

## ✍️ Key Naming Patterns

```
Good:
  anchored:sam_birthday
  semantic:acasey_preferences
  episodic:2026_06_01_v4_rewrite
  reminder:book_sc2_rhyl
  working:current_focus

Bad:
  anchored:samBirthday (camelCase — inconsistent)
  semantic:my_project (missing subject)
  episodic:facts_about_stuff (too vague)
```

**Rules:**
- Lowercase only
- Use `_` or `:` for nesting (max 3 levels)
- Single values per key (not arrays)
- Dates: `YYYY/MM/DD` or `YYYY-MM-DD`

---

## 🔧 Troubleshooting

### 1. "Redis connection refused"
```bash
# Check Upstash credentials
cat ~/.openclaw/workspace/.env.ron-memory | grep UPSTASH
# Or run status
memory status
```

### 2. "memory get returns nothing / wrong value"
```bash
# Sync from Redis to local cache
memory sync
# Then try get again
memory get <key>
```

### 3. "Stale data / old values"
```bash
# Force overwrite with --force
memory set <key> <new_value> --force

# Run prune to archive old entries
memory prune --dry-run    # Preview first
memory prune --force      # Then execute
```

### 4. "Wrong tier assigned"
```bash
# Tier is set by key prefix, not the value
# If you want anchored, use anchored: prefix
memory set anchored:user_name "Alex"     # anchored (permanent)
memory set semantic:user_name "Alex"     # semantic (90d)
```

### 5. "Tests failing"
```bash
cd ron-memories
# Run all 51 tests (no pytest needed)
for f in tests/test_*.py; do python3 "$f" 2>&1 | tail -2; done
```

---

## 📁 File Locations

| What | Where |
|------|-------|
| Skill (Python core) | `~/.openclaw/skills/ron-memory/ron_memory/` |
| Wrapper | `~/.openclaw/workspace/scripts/memory` (symlink) |
| Config | `~/.openclaw/workspace/.env.ron-memory` |
| Local cache | `~/.openclaw/workspace/memory/ron-memory.md` |
| Tests | `tests/test_*.py` (51 tests) |

---

_Built for humans who forget things. That's the point._
