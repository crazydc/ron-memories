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

Also copy to:
- `/root/.openclaw/.env.ron-memory` (for scripts to find)
- Subagent workspaces: `/root/.openclaw/workspace-dave/`, `/root/.openclaw/workspace-techsupport/`

### Step 4: Update Agent Workspace Files

For each agent workspace (main, dave, techsupport), add to:

**AGENTS.md** - Add to startup sequence:
```
6. Read SHARED_MEMORY.md (if exists) - contains shared memory info
```

**SOUL.md** - Add capabilities section:
```
## Shared Memory

You have access to shared memory via the ron-memory skill. 
Use memory-set.sh to save important info, memory-get.sh to retrieve.
This memory is shared across all agents.
```

**TOOLS.md** - Add memory section:
```
### Shared Memory

Uses Upstash Redis for cross-agent memory sharing.
- memory-set.sh <key> <value> - Save a memory
- memory-get.sh <key> - Get a memory
- memory-list.sh - List all memories
```

Also create `SHARED_MEMORY.md` in each workspace with current memories.

### Step 5: Test Connection

```bash
./scripts/memory-set.sh test "Hello"
./scripts/memory-get.sh test
```

If it works, installation is complete.

## Usage

When user says things like "remember that..." or "don't forget...", extract the key info and save it:
```bash
./scripts/memory-set.sh <key> "<value>"
```

When asked about shared info, check memory:
```bash
./scripts/memory-get.sh <key>
```

## Configuration

See [references/.env.example](./references/.env.example)

Environment variables:
- `UPSTASH_REDIS_URL` / `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_TOKEN` / `UPSTASH_REDIS_REST_TOKEN`