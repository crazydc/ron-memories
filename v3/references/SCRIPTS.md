# Ron-Memory Script Reference

All scripts live in `scripts/` and require no arguments for basic use.

## Core Scripts

### memory-set.sh

Save a memory to Redis + local cache.

```bash
memory-set.sh <key> <value> [--force]
```

| Option | Description |
|--------|-------------|
| `<key>` | Memory key (e.g., `user:birthday`, `project:heyron:status`) |
| `<value>` | Value to store |
| `--force` | Overwrite without staleness warning |

**Examples:**
```bash
./memory-set.sh user:name Alex
./memory-set.sh project:heyron:status active
./memory-set.sh vehicle:car:reg "XY51 ABC" --force
```

**Staleness detection:** Warns if key exists with different value. Use `--force` to override.

---

### memory-get.sh

Retrieve a memory from Redis (with local cache fallback).

```bash
memory-get.sh <key>
```

| Option | Description |
|--------|-------------|
| `<key>` | Memory key to retrieve |

**Examples:**
```bash
./memory-get.sh user:name
./memory-get.sh project:heyron:status
```

**Behavior:** Redis first, falls back to local cache if Redis unavailable.

---

### memory-sync.sh

Pull all memories from Redis, update local cache.

```bash
memory-sync.sh
```

**Notes:**
- Filters out `ron:jeff:test:*` and `ron:archive:*` keys
- Includes `ron:story:*` keys in output
- Writes to `/root/.openclaw/workspace/memory/ron-memory.md`
- Run via heartbeat or manually

---

### memory-list.sh

List all memories with optional filters.

```bash
memory-list.sh [--stats] [--namespace <ns>] [--summarize]
```

| Option | Description |
|--------|-------------|
| `--stats` | Show memory counts per namespace |
| `--namespace <ns>` | Filter to specific namespace (e.g., `user`, `project`) |
| `--summarize` | Show story: keys (human moments) |

**Examples:**
```bash
./memory-list.sh --stats
./memory-list.sh --namespace user
./memory-list.sh --summarize
```

---

### memory-rank.sh

Attention-based retrieval — returns most relevant memories for a context.

```bash
memory-rank.sh "<query or task description>" [--budget <tokens>]
```

| Option | Description |
|--------|-------------|
| `<query>` | Natural language describing what you're working on |
| `--budget` | Token budget (default: 2000) |

**Scoring algorithm:**
- Base score: 100
- Reinforce bonus: +10 per access (tracked via `ron:reinforce:count:<key>`)
- Freshness decay: -1 per day since last access
- Story bonus: +20 for `ron:story:*` namespace

**Example:**
```bash
./memory-rank.sh "working on heyron documentation"
./memory-rank.sh "planning family holiday" --budget 3000
```

---

## Curation Scripts

### memory-prune.sh

Enforce TTLs — move expired entries to archive.

```bash
memory-prune.sh [--dry-run] [--execute]
```

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be archived (default) |
| `--execute` | Actually move expired entries |

**Namespace TTLs:**
| Namespace | TTL |
|-----------|-----|
| user | permanent |
| family | permanent |
| story | permanent |
| contact | permanent |
| vehicle | permanent |
| project | permanent |
| goal | permanent |
| pref | 30 days |
| service | 90 days |
| reminder | 7 days |
| reinforce | 7 days |
| working | 24h |
| archive | permanent |

---

### memory-cleanup.sh

Bulk cleanup of old test/system entries. Designed to remove test data cluttering the cache.

```bash
memory-cleanup.sh [--dry-run] [--force] [--keep-days N]
```

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview what would be deleted (default) |
| `--force` | Actually delete matching entries |
| `--keep-days N` | Also delete entries older than N days |

**Patterns deleted in --force mode:**
- `ron:health:1777*` — timestamp entries from 2026-05-02 healthcheck testing
- `ron:test:*` — ron namespace test keys
- `ron:jeff:test:*` — jeff-specific test keys
- `ron:health:test:*` — health test entries
- `testkey` — legacy test key

**Protected namespaces (never deleted):**
`user`, `family`, `story`, `contact`, `vehicle`, `project`, `goal`, `pref`, `reminder`, `reinforce`, `archive`

**Examples:**
```bash
# Preview what would be deleted
./memory-cleanup.sh

# Actually delete the test entries
./memory-cleanup.sh --force

# Delete entries older than 30 days (except protected namespaces)
./memory-cleanup.sh --keep-days 30 --force
```

**Notes:**
- Requires `--force` to actually delete — dry-run is the default
- All protected namespaces are always skipped, even with `--keep-days`
- Safe to run multiple times — idempotent operation

---

### memory-audit.sh

Audit for stale entries, conflicts, never-accessed keys.

```bash
memory-audit.sh [--all] [--conflicts] [--stale] [--never-accessed]
```

| Option | Description |
|--------|-------------|
| `--all` | Run all audits |
| `--conflicts` | Keys that changed since last read |
| `--stale` | Entries past their TTL but not archived |
| `--never-accessed` | Keys with reinforce count = 0 |

---

### memory-learn.sh

Instruct the agent to learn from recent conversations. Triggers on "remember that..." phrases.

```bash
memory-learn.sh "<extracted fact>"
```

Called automatically by `check-triggers.sh`. Users can also invoke directly.

---

## Utility Scripts

### check-triggers.sh

Scan message for memory trigger phrases.

```bash
check-triggers.sh "<message text>"
```

**Trigger phrases:**
- "remember that..."
- "don't forget..."
- "note that..."
- "I should..."
- "tell the agent about..."
- "save this..."

If triggers found, extracts facts and calls `memory-learn.sh`.

---

### memory-healthcheck.sh

Verify Ron-Memory is fully operational.

```bash
memory-healthcheck.sh
```

**Checks:**
1. Redis connectivity (keys endpoint)
2. Redis read (known test key)
3. Redis write + read-back
4. Local cache exists

**Exit codes:** 0 = all pass, 1 = one or more failures

---

### morning-briefing-memories.sh

Get memories from the last 24 hours for daily briefing.

```bash
morning-briefing-memories.sh
```

**Output:** List of entries updated in last 24h (filtered to exclude test/system keys).

---

### memory-export.sh

Export all Redis memories to a JSON backup file.

```bash
memory-export.sh [--output <path>] [--stdout] [--all]
```

| Option | Description |
|--------|-------------|
| `--output <path>` | Output file path (default: `exports/ron-memory-YYYY-MM-DD.json`) |
| `--stdout` | Write JSON to stdout instead of a file (for piping) |
| `--all` | Include reinforce:* keys (default: excludes them) |

**Export format:** JSON array of `{key, value, timestamp}` objects

**Examples:**
```bash
# Export to dated file in exports/
memory-export.sh

# Pipe to another command or tool
memory-export.sh --stdout | jq '.[] | select(.key | startswith("user:"))'

# Custom output path
memory-export.sh --output ~/my-backup.json

# Include reinforce keys
memory-export.sh --all
```

**Notes:**
- Excludes `ron:test:*` and `ron:jeff:*` keys by default
- Output file is gitignored in exports/

---

### memory-import.sh

Import memories from a JSON backup file.

```bash
memory-import.sh <backup-file> [--dry-run] [--merge|--replace]
```

| Option | Description |
|--------|-------------|
| `<backup-file>` | Path to the JSON backup file (required) |
| `--dry-run` | Preview what would be imported without making changes |
| `--merge` | Add to existing memories (default behavior) |
| `--replace` | Clear all ron:* keys first, then import |

**Examples:**
```bash
# Import from backup (merge mode)
memory-import.sh exports/ron-memory-2025-01-15.json

# Preview what would be imported
memory-import.sh backup.json --dry-run

# Replace all existing memories with the backup
memory-import.sh backup.json --replace
```

**JSON validation:** Validates the backup file before importing. Exits with error if invalid JSON.

**Exit codes:** 0 = success, 1 = file not found or invalid JSON

---


### memory-delete.sh

Delete a memory key.

```bash
memory-delete.sh <key>
```

**Example:**
```bash
./memory-delete.sh test:temp_key
```

---

## v3-Only Scripts

### check-reminders.sh

Dedicated reminder checker — designed for cron (every 5 min).

```bash
check-reminders.sh
```

Scans `ron:reminder:*` namespace for due items, outputs reminders that are due.

**Crontab entry:**
```
*/5 * * * * bash ~/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh >> /var/log/ron-reminders.log 2>&1
```

---

### memory-reinforce.sh

Track memory access for reinforcement scoring.

```bash
memory-reinforce.sh <key>
```

Called by `memory-get.sh` on each access. Increments `ron:reinforce:count:<key>`.

---


## Migration Scripts

### memory-migrate-v2-to-v3.sh

Migrate from v2 key format to v3 namespaced format.

```bash
memory-migrate-v2-to-v3.sh [--dry-run] [--force]
```

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview what would be migrated (default) |
| `--force` | Actually perform the migration |

**What it migrates:**

| v2 Key | v3 Key |
|--------|--------|
| `user_name` | `user:acasey:name` |
| `user:preference:*` | `pref:*` |
| `user:pref:*` | `pref:*` |

**What it skips (already v3 format):**
- `family:*`, `story:*`, `contact:*`, `project:*`, `vehicle:*`, `pref:*`, `reminder:*`, etc.

**Example:**
```bash
# Preview migration
./memory-migrate-v2-to-v3.sh --dry-run

# Execute migration
./memory-migrate-v2-to-v3.sh --force
```
