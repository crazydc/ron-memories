# Ron-Memory v3 — Installation Guide

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
| Bash terminal | Runs the setup scripts | Built into macOS/Linux |
| Upstash Redis | Cloud database for storing memories | Free at [upstash.com](https://upstash.com) |
| ~10 minutes | To run through setup | Takes longer if you multitask |

---

### How the pieces fit together

```
  You  ──►  AI Assistant  ──►  Upstash Redis (cloud)
                              │
                              └──► Memories saved here
                                   even after restart
```

**Upstash Redis** is your memory database — a cloud notepad your assistant reads from and writes to.

**Cron** is the reminder clock — checks every 5 minutes, even when no one's chatting.

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

## Step 3: Run the Automated Setup

Run the interactive setup script — it handles everything:

```bash
cd ~/.openclaw/skills/ron-memory/v3
bash scripts/memory-setup.sh
```

The script will:

```
  1/5 — Ask for your Redis URL and Token
  2/5 — Set up the reminder cron job
  3/5 — Create the local cache folders
  4/5 — Verify everything works
  5/5 — Tell you it's ready
```

When it asks for your Redis URL and Token — paste what you copied from Upstash.

---

## Step 4: Try It! 🎯

Save your first memory:

```bash
bash ~/.openclaw/skills/ron-memory/v3/scripts/memory-set.sh user:first-test "hello world"
```

Read it back:

```bash
bash ~/.openclaw/skills/ron-memory/v3/scripts/memory-get.sh user:first-test
```

You should see `hello world`. 

If you do — **it's working!** Your AI assistant now has persistent memory. 🧠

---

## Tips & Warnings

> 💡 **Tip:** Your Redis URL and Token are saved in `~/.openclaw/.env.ron-memory`. You only need to enter them once.

> ⚠️ **Reminder cron:** The setup script will ask if you want to enable the reminder cron. Say **yes** — this is what lets your assistant ping you about things at the right time.

> 💡 **Upgrading from v2:** If you had v2, just re-run `memory-setup.sh`. Your existing memories are automatically detected and kept.

---

## Common Issues

| Problem | Fix |
|---|---|
| "Redis connection failed" | Double-check your URL and Token are correct |
| "Permission denied" | Run `chmod +x scripts/*.sh` in the ron-memory folder |
| Reminders not firing | Check cron: `crontab -l | grep ron` |

---

## Questions?

- Full docs: `README.md`
- Script reference: `references/SCRIPTS.md`
- Architecture notes: `references/ARCHITECTURE.md`

Happy remembering! 🧠