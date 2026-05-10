# Ron-Memory v3 Architecture

## Philosophy

Memory should work like a human's brain — not just store facts, but curate them. Some things are hot (accessed often, recent), others are cold (dormant, historical). The system should surface what's relevant now while keeping the rest accessible.

## Key Design Principles

1. **Never lose information** — Archive instead of delete
2. **Reinforce hot memories** — Frequently accessed entries get boosted
3. **Stories matter as much as facts** — Life moments are preserved
4. **Reminders are time-critical** — Dedicated cron, not heartbeat
5. **Token budget aware** — Don't overflow context with irrelevant memories

## Namespace Updates (v3)

New v3 namespaces:

| Namespace | Purpose | TTL |
|-----------|---------|-----|
| `ron:story:*` | Life moments for reminiscing | permanent |
| `ron:reinforce:*` | Memory reinforcement triggers | 7 days |
| `ron:archive:*` | Dormant but still searchable | permanent |

Existing namespaces retained from v2.

## Script Architecture

```
memory-set.sh
    │
    ├─▶ Staleness check (warn on conflict)
    │
    ├─▶ Save to Redis + local cache
    │
    └─▶ Update reinforce: key (touch for freshness)

memory-get.sh
    │
    ├─▶ Redis first (freshest)
    │
    └─▶ Local cache fallback
    │
    └─▶ Increment reinforce count (reinforce:count:<key>)

memory-rank.sh
    │
    ├─▶ Score all entries:
    │     - base score = 100
    │     - reinforce bonus (+10 per access)
    │     - freshness decay (-1 per day since access)
    │     - story bonus (+20 for story: namespace)
    │
    ├─▶ Filter by context relevance
    │
    └─▶ Cap at token budget (default 2000 tokens)
```

## Reminder System (v3)

Reminders are NOT on heartbeat. They're on a dedicated cron:

```
# Check reminders every 5 minutes
*/5 * * * * bash ~/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh >> /var/log/ron-reminders.log 2>&1
```

This ensures:
- Reminders aren't missed during heartbeat gaps
- Time-critical items get checked frequently
- Separate from memory sync (which is heartbeat-based)

## Data Flow

```
Save:  User → memory-set.sh → Redis + Cache
                                       │
                                  ┌────┴────┐
                                  │Archive?│
                                  └────────┘
                                    (on TTL)

Get:   User → memory-get.sh → Redis → Cache fallback
                                   │
                              Update reinforce count

Sync:  Redis → memory-sync.sh → Local cache (heartbeat)
                                          │
                                   (ron:story: excluded from active,
                                    in cache for searchability)

Rank:  Query → memory-rank.sh → Scored + filtered → Top N
```

## Redis Key Structure

All keys stored as `ron:{namespace}:{rest}` where namespace is:

- `user` — Dale's personal data
- `contact` — People Dale knows
- `story` — Life moments
- `reinforce` — Access tracking
- `reminder` — Time-critical tasks
- `archive` — Dormant entries

Values stored as JSON: `{"value": "...", "timestamp": "..."}`

## Local Cache

Cache file: `/root/.openclaw/workspace/memory/ron-memory.md`

Format:
```
| Key | Value | Updated |
| user:birthday | 1990/06/04 | 2026-05-10T11:00:00Z |
```

- story: keys EXCLUDED from cache (too personal for file)
- archive: keys included but noted
- Synced via heartbeat every ~30min
