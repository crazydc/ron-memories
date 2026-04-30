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

## Setup

### Step 1: Create Upstash Database

1. Go to https://upstash.com
2. Sign up (email + password)
3. Click **Create Database**
4. Enter a name (e.g., "JeffMemory")
5. Select region closest to you
6. Choose **Free** tier (or upgrade if needed)
7. Click **Create**

### Step 2: Get Credentials

1. Click on your new database
2. Scroll to **Connect** section
3. Copy the **REST URL** (looks like `https://xxx.upstash.io`)
4. Copy the **REST Token** (long string starting with `gQ...`)

**Important:** Make sure "Read-Only Token" is NOT checked — use the default token.

### Step 3: Configure

Create `.env.ron-memory` in your workspace:

```bash
UPSTASH_REDIS_URL=https://your-db.upstash.io
UPSTASH_REDIS_TOKEN=your-token
```

Or export as environment variables:

```bash
export UPSTASH_REDIS_URL=https://your-db.upstash.io
export UPSTASH_REDIS_TOKEN=your-token
```

### Step 4: Enable in OpenClaw

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

### Step 5: Test

```bash
./scripts/memory-set.sh test "Hello World"
./scripts/memory-get.sh test
```

## Configuration

See [references/.env.example](./references/.env.example)

Environment variables:
- `UPSTASH_REDIS_URL` / `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_TOKEN` / `UPSTASH_REDIS_REST_TOKEN`