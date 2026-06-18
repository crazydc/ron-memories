# Ron-Memory v4 — Installation Guide

> **Friendly note:** This guide is for everyone. If you can use a terminal and follow steps, you can do this. Don't overthink it. 🚀

---

## What is this?

Ron-Memory gives your AI assistant a memory that doesn't disappear when it restarts. Normally, AI assistants "forget" everything when their session ends. Ron-Memory fixes that — it saves memories to a cloud database so your assistant remembers things across sessions.

Think of it like a notepad in the sky that your AI assistant can read from and write to whenever it needs to.

---

## Who is this for?

You, if you:
- Use OpenClaw or a similar AI assistant framework
- Want your assistant to remember facts, preferences, and important details about you
- Like automation and making things work better over time

---

## What You'll Need

| Requirement | Why | How |
|---|---|---|
| Python 3.8+ | Runs the v4 Python core | Pre-installed on macOS/Linux |
| Bash terminal | Runs setup + wrapper | Built into macOS/Linux |
| Upstash Redis | Cloud database for storing memories | Free at [upstash.com](https://upstash.com) |
| ~5 minutes | To run through setup | Takes longer if you multitask |

### How the pieces fit together

```
  You  ──►  AI Assistant  ──►  Upstash Redis (cloud)
                              │
                              └──► Memories saved here
                                   even after restart
```

**Upstash Redis** is your memory database — a cloud notepad your assistant reads from and writes to.

**No external Python packages.** v4 uses only the Python standard library — no `pip install` required.

---

## Step 1: Create Your Upstash Account

1. Go to **[upstash.com](https://upstash.com)** and sign up (GitHub login is easiest)
2. Click **Create Database**
3. Leave the region as default, choose **Free Tier**
4. Give it a name like `ron-memory` (doesn't matter what)
5. Click **Create**

That's it. You've got a database. 🎉

---

## Step 2: Get Your Credentials

In your new database, click the **Connect** tab. You'll see two things you need:

- **REST URL** — looks like `https://something.upstash.io`
- **REST Token** — a long string of letters and numbers

> ⚠️ **Copy both of these now.** You'll need them in Step 3. The token is shown only once — if you miss it, you can regenerate it from the Connect tab.

---

## Step 3: Install Ron-Memory v4

```bash
# Clone the v4 branch
git clone https://github.com/crazydc/ron-memories.git
cd ron-memories
git checkout main
```

No build step. No `pip install`. The Python core uses only the standard library.

---

## Step 4: Configure Your Credentials

Create `.env.ron-memory` in your workspace directory:

```bash
cat > ~/.openclaw/workspace/.env.ron-memory <<'EOF'
UPSTASH_REDIS_REST_URL=https://your-db.upstash.io
UPSTASH_REDIS_REST_TOKEN=your-token-here
EOF
```

(Replace the URL and token with what you copied from Upstash.)

---

## Step 5: (Optional) Install the `memory` Wrapper

For daily use, the `memory` wrapper is way nicer than typing `python3 -m ron_memory.cli` every time:

```bash
# Symlink the wrapper into your scripts dir
ln -s "$(pwd)/scripts_v4_shims/memory.sh" ~/.openclaw/workspace/scripts/memory

# Make sure your scripts dir is on PATH
export PATH="$HOME/.openclaw/workspace/scripts:$PATH"
```

You can now use `memory` from anywhere instead of `python3 -m ron_memory.cli`.

---

## Step 6: Verify It Works

```bash
memory status
```

You should see:

```
🔍 Ron-Memory v4 Status
========================================
Redis:           ✅ connected
Redis keys:      <N>
Cache file:      ✅
Migration done:  ✅
Write test:      ✅
```

If you see all green checkmarks — **it's working!** Your AI assistant now has persistent memory. 🧠

---

## Step 7: Try It Out

Save your first memory:

```bash
memory set anchored:first_test "hello world"
```

Read it back:

```bash
memory get anchored:first_test
# → hello world
```

If you see `hello world` — you're done. Welcome to persistent memory. 🎉

---

## Tips & Warnings

> 💡 **Tip:** Your Redis URL and Token are saved in `~/.openclaw/workspace/.env.ron-memory`. You only need to enter them once. The v4 core reads from this single file — no hardcoded credentials anywhere else.

> ⚠️ **No cron needed for v4.** v3 used a 5-minute cron for reminders; v4 is a pure read/write library. If you want cron-based reminders, you can set them up using OpenClaw's cron feature, but it's not required for the basic skill.

> 💡 **Upgrading from v3:** Just `git checkout main` — your existing data in Upstash works without changes. v3 bash scripts are kept as shims in `scripts_v4_shims/` for backward compat.

---

## Common Issues

| Problem | Fix |
|---------|-----|
| "Redis connection failed" | Double-check your URL and Token are correct in `.env.ron-memory` |
| "ModuleNotFoundError: No module named 'ron_memory'" | Make sure you're running from the repo root, or that `PYTHONPATH` includes the repo |
| `memory: not found` (after wrapper install) | Add `~/.openclaw/workspace/scripts` to your PATH |
| Old v3 scripts don't work | They should — they're shimmed in `scripts_v4_shims/`. If not, run them directly: `python3 -m ron_memory.cli <verb> <args>` |

---

## Questions?

- Full docs: `README.md`
- Agent instructions: `SKILL.md`
- Quick reference: `QUICKREF.md`
- Design doc (in your workspace): `docs/RON-MEMORY-V4-DESIGN.md`

Happy remembering! 🧠
