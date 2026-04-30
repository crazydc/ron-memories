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
- Subagent workspaces: `/root/.openclaw/workspace-dave/.env.ron-memory`, `/root/.openclaw/workspace-techsupport/.env.ron-memory`

### Step 4: Test Connection

```bash
./scripts/memory-set.sh test "Hello"
./scripts/memory-get.sh test
```

If it works, installation is complete.

## Configuration

See [references/.env.example](./references/.env.example)

Environment variables:
- `UPSTASH_REDIS_URL` / `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_TOKEN` / `UPSTASH_REDIS_REST_TOKEN`