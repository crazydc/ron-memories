# Ron-Memory Installation Guide

## Prerequisites

- Bash shell
- curl
- Python 3 (for JSON parsing)
- Upstash Redis account (free tier works)

---

## Step 1: Get Upstash Redis

1. Sign up at https://upstash.com
2. Create a new Redis database
3. Copy your **REST URL** and **REST Token** from the Connect tab

You'll need these for the scripts.

---

## Step 2: Install Scripts

### Option A: Clone the Repo

```bash
git clone https://github.com/crazydc/ron-memories.git
cd ron-memories
git checkout v3
```

### Option B: Copy Manually

```bash
mkdir -p ~/.openclaw/skills/ron-memory/v3/scripts
# Copy scripts from the repo
chmod +x ~/.openclaw/skills/ron-memory/v3/scripts/*.sh
```

---

## Step 3: Configure Credentials

Edit the embedded credentials in each script:

```bash
TOKEN='your-upstash-token-here'
URL='https://your-db.upstash.io'
CACHE_FILE="/root/.openclaw/workspace/memory/ron-memory.md"
```

Or create a shared config file and source it.

---

## Step 4: Test It

```bash
# Save a test memory
./scripts/memory-set.sh user:test "hello world"

# Read it back
./scripts/memory-get.sh user:test
# → hello world

# Health check
./scripts/memory-healthcheck.sh
```

---

## Step 5: Set Up Reminders (Required for v3)

Reminders need their own cron job — this is what makes v3 different from earlier versions.

```bash
crontab -e
```

Add:
```cron
*/5 * * * * bash ~/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh >> /var/log/ron-reminders.log 2>&1
```

---

## Step 6: Set Up Heartbeat Sync (Recommended)

Memory sync runs via heartbeat every ~30 minutes:

```bash
# In your heartbeat config, add:
bash ~/.openclaw/skills/ron-memory/v3/scripts/memory-sync.sh
```

This keeps local cache fresh for fast lookups.

---

## Step 7: Install for OpenClaw

Tell your agent:
```
"Install Ron Memory v3 from https://github.com/crazydc/ron-memories/tree/v3"
```

The agent will:
1. Clone the repo
2. Checkout v3 branch
3. Configure credentials
4. Set up heartbeat syncing
5. Set up reminder cron

---

## Troubleshooting

### "Redis connection failed"
- Check your TOKEN and URL are correct
- Test: `curl -s <URL>/keys/ron:* -H "Authorization: Bearer <TOKEN>"`

### "Key not found"
- The key might not exist yet — use `memory-set.sh` first

### "Permission denied"
- Make scripts executable: `chmod +x scripts/*.sh`

### "Cron not firing reminders"
- Check cron installed: `crontab -l | grep ron`
- Check log: `cat /var/log/ron-reminders.log`
- Test manually: `bash scripts/check-reminders.sh`

---

## Upgrading from v2

```bash
cd ron-memories
git fetch origin
git checkout v3
# Scripts in v3/ subfolder now
```

v3 is backwards-compatible with v2 keys. No migration needed.
