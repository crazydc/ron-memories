# Ron-Memory

**Cross-session memory for AI agents using Upstash Redis.**

Gives your AI agents persistent memory across sessions — they remember facts, preferences, and context just like humans do.

## What It Does

- **Saves memories** to Upstash Redis with timestamps
- **Reads memories** instantly from local cache
- **Syncs** Redis ↔ local file for reliability
- **Triggers automatically** on phrases like "remember that...", "don't forget...", "note that..."
- **Multi-agent hive brain** — shared memory across agents, RAG-style retrieval

## Installation

> ⭐ **Option A is the recommended way for Heyron.ai users** — no shell access needed

---

### ✅ Option A: Heyron.ai / Prompt-Based Install (No Shell Required)

For users without shell access to their Heyron.ai / OpenClaw installation, Ron Memory can be installed via a single prompt:

```
"Install the Ron Memory skill from https://github.com/crazydc/ron-memories"
```

OpenClaw agents can install skills by referencing a GitHub repo URL — no shell access required. Once installed, configure your credentials:

```
"Configure Ron Memory with my Upstash Redis credentials:
 UPSTASH_REDIS_URL=https://your-db.upstash.io
 UPSTASH_REDIS_TOKEN=your-token-here"
```

**Get your Upstash credentials:**
1. Sign up at https://upstash.com and create a free Redis database
2. Copy your **REST URL** and **REST Token** from the Connect section

---

### 🔧 Option B: Standard Install (Shell Access)

#### 1. Get Upstash Redis

1. Sign up at https://upstash.com and create a free Redis database
2. Copy your **REST URL** and **REST Token** from the Connect section

#### 2. Configure Credentials

Create `~/workspace/.env.ron-memory`:

```bash
UPSTASH_REDIS_URL=https://your-db.upstash.io
UPSTASH_REDIS_TOKEN=your-token-here
```

#### 3. Install Scripts

```bash
mkdir -p ~/.openclaw/skills/ron-memory/scripts
# Copy all scripts from the scripts/ folder to that location
chmod +x ~/.openclaw/skills/ron-memory/scripts/*.sh
```

#### 4. Test It

```bash
~/.openclaw/skills/ron-memory/scripts/memory-set.sh favorite_color blue
~/.openclaw/skills/ron-memory/scripts/memory-get.sh favorite_color
# → blue
```

## Usage

| Command | What it does |
|---------|--------------|
| `memory-set.sh <key> <value>` | Save a memory |
| `memory-get.sh <key>` | Get a memory |
| `memory-list.sh` | List all memories |
| `memory-delete.sh <key>` | Delete a memory |
| `memory-sync.sh` | Sync Redis → local file |
| `check-triggers.sh` | Check for memory triggers in text |

## Example

**Agent:** "I have a Tesla and its REG is XY51 ABC"

**Agent saves it:**
```bash
memory-set.sh tesla_reg "XY51 ABC"
# → OK: Saved 'tesla_reg' = 'XY51 ABC'
```

**Later session:**

**User:** "What car do I have?"
**Agent:** `memory-get.sh tesla_reg` → "XY51 ABC"

→ "You have a Tesla with registration XY51 ABC."

## Multi-Agent "Hive Brain" Mode

Ron Memory isn't just for one agent — it works as a **shared memory layer for multi-agent systems**.

### The Problem

- Every time you spawn a subagent, you have to pass context
- That context burns tokens and gets expensive
- Each agent re-learns basics repeatedly

### The Solution

Store once, retrieve on-demand:

```
[HUMAN] → Primary Agent
"Build Heyron Docs v2. Key features: markdown support, search, dark mode.
 Dave handles code, DevOps handles deployment."

Primary Agent saves:
  project:heyron-docs:context = "v2 with markdown, search, dark mode"
  project:heyron-docs:task:dave = "implement markdown + search + dark mode"
  project:heyron-docs:task:devops = "deploy to mini PC, configure nginx"

[HUMAN] → "Spawn Dave to work on Heyron Docs"

Spawn Agent Dave with: "Read project:heyron-docs tasks, complete the coding tasks"

Dave pulls memory → knows exactly what to build
No context stuffing needed — just targeted retrieval
```

### Why This Is RAG

**RAG** (Retrieval-Augmented Generation) = when an AI retrieves relevant info at query time instead of stuffing all info into the prompt.

- **Traditional:** Pass full history to every agent → expensive, degraded quality
- **Ron Memory:** Each agent retrieves only what it needs → fast, cheap, accurate

> Token cost drops per agent. Model quality improves. Agents feel "aware" because they remember.

## How It Works

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Agent     │────▶│  Redis API   │────▶│  Upstash    │
│  (memory-   │     │  (Upstash)   │     │  Redis      │
│   set.sh)   │     └──────────────┘     └─────────────┘
└─────────────┘            │
                           ▼
                    ┌─────────────┐
                    │  Local      │
                    │  ron-memory │
                    │  .md file   │
                    └─────────────┘
```

- **Write**: Saves to Redis AND local file
- **Read**: From local file (fast, no API call needed)
- **Fallback**: If Redis fails, still works from local cache

## File Structure

```
ron-memory/
├── scripts/
│   ├── config.sh          # Configuration loader
│   ├── memory-set.sh      # Save a memory
│   ├── memory-get.sh      # Get a memory
│   ├── memory-list.sh     # List all memories
│   ├── memory-delete.sh    # Delete a memory
│   ├── memory-sync.sh     # Sync Redis → local file
│   ├── memory-read.sh     # Read local cache only
│   └── check-triggers.sh  # Detect "remember that..." triggers
├── references/
│   └── .env.example      # Example credentials file
├── SKILL.md               # OpenClaw skill definition
└── README.md              # This file
```

## Demo Transcript

Here's a conversation transcript showing Ron-Memory in action:

```
User: I have a Tesla and its REG is XY51 ABC
Agent: *saves to memory*
  $ memory-set.sh tesla_reg "XY51 ABC"
  → OK: Saved 'tesla_reg' = 'XY51 ABC'

[... later session ...]

User: What car do I have?
Agent: $ memory-get.sh tesla_reg
  → "XY51 ABC"
"You have a Tesla with registration XY51 ABC."
```

The agent remembered the Tesla registration across sessions — without Ron-Memory it would have no memory of this.

## License

MIT License - See [LICENSE](LICENSE) for details.
