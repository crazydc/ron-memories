---
name: ron-memory
description: "Shared memory system for OpenClaw agents using Upstash Redis. Use when: user wants to remember things across sessions, store notes, preferences, or any persistent data that multiple agents need access to."
---

# Ron-Memory

Cross-session memory using Upstash Redis with local file caching.

## Quick Start

```bash
# Save a memory
./scripts/memory-set.sh favorite_color blue

# Read it
./scripts/memory-get.sh favorite_color
```

## Scripts

| Script | Usage |
|--------|-------|
| [scripts/memory-set.sh](./scripts/memory-set.sh) | Save a memory |
| [scripts/memory-get.sh](./scripts/memory-get.sh) | Get a memory |
| [scripts/memory-list.sh](./scripts/memory-list.sh) | List all memories |
| [scripts/memory-delete.sh](./scripts/memory-delete.sh) | Delete a memory |
| [scripts/memory-sync.sh](./scripts/memory-sync.sh) | Sync Redis → local file |
| [scripts/memory-learn.sh](./scripts/memory-learn.sh) | Auto-learn new namespaces |

## Auto-Learning

Ron-Memory can learn new namespace types automatically:

```bash
# Audit - see all namespaces in use
./scripts/memory-learn.sh --audit

# Suggest - show new namespaces not yet documented
./scripts/memory-learn.sh --suggest

# Update - interactive learning (adds new namespaces to NAMESPACE.md)
./scripts/memory-learn.sh --update
```

### Agent Trigger Learning

When saving a key with a **new prefix** (not in NAMESPACE.md), the agent should:

1. **Notice** the prefix is unknown
2. **Ask** the user: "Should I add 'book' as a new namespace type?"
3. **If yes**, suggest a description and call `memory-learn.sh --update`

Example conversation:
```
User: Remember I read the book "Atomic Habits"
Agent: 
  ./scripts/memory-set.sh book:atomic_habits:title "Atomic Habits"
  ./scripts/memory-set.sh book:atomic_habits:author "James Clear"
  
  "Saved! Should I add 'book' as a new namespace category for tracking books?"
User: Yes, it's for books I own or want to read
Agent:
  ./scripts/memory-learn.sh --update
  ✓ Added 'book' to NAMESPACE.md

## Key Namespace Structure

See [NAMESPACE.md](./NAMESPACE.md) for a comprehensive guide to organizing memory keys. Key prefixes include:

- `user:*` — Your personal data
- `contact:{name}:*` — People you know
- `family:{name}:*` — Family members
- `vehicle:{name}:*` — Vehicles
- `project:{name}:*` — Projects
- `goal:{id}:*` — Goals and milestones
- `pref:{category}:*` — Preferences
- `service:{name}:*` — Online accounts
- `agent:{name}:*` — AI agent configuration

## How It Works

1. **Write**: Saves to both Redis AND local `memory/ron-memory.md`
2. **Read**: From local file (fast)
3. **Delete**: Removes from both

## Full Installation

When user asks to install/enable ron-memory, do the following:

### Step 1: Enable Skill in OpenClaw

Add to `openclaw.json`:

```json
{
  "skills": {
    "entries": {
      "ron-memory": {
        "enabled": true
      }
    }
  }
}
```

### Step 2: Ask User for Upstash Credentials

If user doesn't have an Upstash account:
1. Tell them to go to https://upstash.com and create a free database
2. Ask them to copy the REST URL and REST Token from the Connect section

If user provides credentials, proceed to Step 3.

### Step 3: Create Configuration

Create `.env.ron-memory` in the workspace root:

```bash
UPSTASH_REDIS_URL=https://your-db.upstash.io
UPSTASH_REDIS_TOKEN=your-token
```

Also copy to `/root/.openclaw/.env.ron-memory` (scripts check here first).

### Step 4: Update Agent Workspace Files

This is required so agents are aware of the memory system and read it on startup.

For each agent workspace, update:

1. **AGENTS.md** - Add to startup sequence (early - before responding to user):
   ```
   4. Read ron-memory shared data — run `memory-read.sh` or read `memory/ron-memory.md` for cross-session facts (birthdays, preferences, family info, etc.)
   ```

2. **SOUL.md** - Add capability note:
   ```
   ## Shared Memory
   You have access to shared memory via ron-memory skill.
   Use memory-set.sh to save, memory-get.sh to retrieve.
   ```

3. **TOOLS.md** - Add memory section:
   ```
   ### Shared Memory
   Uses Upstash Redis for cross-agent memory sharing.
   - memory-set.sh <key> <value> - Save
   - memory-get.sh <key> - Get
   - memory-list.sh - List all
   ```

4. Create **SHARED_MEMORY.md** with current memories (can be empty to start)

### Step 5: Test Connection

```bash
./scripts/memory-set.sh test "Hello"
./scripts/memory-get.sh test
```

If it works, installation is complete.

---

## Optional: Multi-Agent Setup

If running multiple agents that need to share memory:

Copy or symlink `.env.ron-memory` to each agent's workspace so they can all access the same Redis instance.

## Usage

When user says "remember that..." or "don't forget...", save it:
```bash
./scripts/memory-set.sh <key> "<value>"
```

When asked about shared info, retrieve it:
```bash
./scripts/memory-get.sh <key>
```

## Configuration

See [references/.env.example](./references/.env.example)

Environment variables:
- `UPSTASH_REDIS_URL` / `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_TOKEN` / `UPSTASH_REDIS_REST_TOKEN`