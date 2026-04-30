# Ron-Memory

**Cross-session memory for AI agents using Upstash Redis.**

Gives your AI agents persistent memory across sessions — they remember facts, preferences, and context just like humans do.

## What It Does

- **Saves memories** to Upstash Redis with timestamps
- **Reads memories** instantly from local cache
- **Syncs** Redis ↔ local file for reliability
- **Triggers automatically** on phrases like "remember that...", "don't forget...", "note that..."

## Installation

### 1. Get Upstash Redis

1. Sign up at https://upstash.com and create a free Redis database
2. Copy your **REST URL** and **REST Token** from the Connect section

### 2. Configure Credentials

Create `~/workspace/.env.ron-memory`:

```bash
UPSTASH_REDIS_URL=https://your-db.upstash.io
UPSTASH_REDIS_TOKEN=your-token-here
```

### 3. Install Scripts

```bash
mkdir -p ~/.openclaw/skills/ron-memory/scripts
# Copy all scripts from the scripts/ folder to that location
chmod +x ~/.openclaw/skills/ron-memory/scripts/*.sh
```

### 4. Test It

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

**Agent:** "I have a BMW and its REG is KT17 KWU"

**Agent saves it:**
```bash
memory-set.sh bmw_reg "KT17 KWU"
# → OK: Saved 'bmw_reg' = 'KT17 KWU'
```

**Later session:**

**User:** "What car do I have?"
**Agent:** `memory-get.sh bmw_reg` → "KT17 KWU"

→ "You have a BMW with registration KT17 KWU."

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

## License

MIT License - See [LICENSE](LICENSE) for details.
