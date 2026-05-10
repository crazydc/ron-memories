# Ron-Memory v3

**Your AI assistant forgets everything when a session ends. Ron-Memory gives it a second brain.**

You mention your car registration once. Three months later, you ask "what's my car reg?" and get the real answer — not a guess, not a hallucination. Your daughter's birthday. Your wife's anniversary preference. That funny story about Buddy learning to catch a frisbee. It all survives session restarts.

Ron-Memory stores facts, stories, preferences, and reminders — syncing to Upstash Redis so the same memory is available whether you're chatting from your phone, your laptop, or a fresh session after a restart. Built for [Heyron.ai](https://heyron.ai) and OpenClaw, but works anywhere with bash + curl.

---

## What Makes This Different

**Stories, not just facts.** Most memory systems store structured data points. Ron-Memory v3 also stores *life moments* — the summer road trip to coast, the day you shipped your docs project, that thing Charlie did last week. Because your life isn't just data.

**Reminders that actually fire.** Most systems rely on heartbeat intervals (every 30–60 min). Ron-Memory v3 uses a dedicated 5-minute cron that checks for due reminders *regardless* of whether you're actively chatting. Your assistant won't miss that birthday reminder just because nobody asked.

**Reinforcement that learns.** Frequently accessed memories rank higher in retrieval. The things you actually care about float to the top.

**Cloud sync.** Upstash Redis keeps memory in sync across sessions, devices, and restarts. Your AI isn't tied to one machine.

---

## A Real Example

**Session 1 — Monday**

> Alex: "My sister Jordan's birthday is coming up on March 22nd. She mentioned wanting one of those kitchen gadgets."
>
> Jeff: *(saves to Ron-Memory)*
> `ron:family:nicola:birthday = 1990/03/22`
> `ron:story:sister_birthday_2026:title = Jordan wants a kitchen gadget`
> `ron:story:sister_birthday_2026:date = 2026-01-10`

**Session 2 — Three weeks later (fresh session)**

> Alex: "Hey, remind me what Jordan's birthday gift idea was?"
>
> Jeff: *(retrieves from Ron-Memory)* "She mentioned wanting a kitchen gadget — something you can send photos to remotely. March 22nd, so about three weeks away."

No re-explaining. No "I don't know." It just remembered.

---

## Just Talk Normally

Say "remember that..." and it gets saved. Chat naturally and your AI picks up context without being asked. Things worth remembering:

- **Family stuff** — birthdays, preferences, who likes what
- **Life moments** — holidays, milestones, funny stories
- **Preferences** — how you like to be updated, communication style
- **Facts** — car reg, subscription logins, device IPs
- **Reminders** — "remind me in 3 days to..." or "remind me on the 15th to..."

You don't need to format it specially. Just talk.

---

## Install

**Step 1 — Run the setup script:**

```bash
cd ~/.openclaw/skills/ron-memory
./scripts/memory-setup.sh
```

Answer the questions (Redis URL + token). The script handles everything else.

**Step 2 — Save your first memory:**

```bash
./scripts/memory-set.sh user:name Alex
```

**Step 3 — Read it back:**

```bash
./scripts/memory-get.sh user:name
# → Alex
```

That's it. 🧠

---

## Quick Commands

| What | Command |
|------|---------|
| Save a fact | `./scripts/memory-set.sh user:name Alex` |
| Save a story | `./scripts/memory-set.sh story:holiday_2025:title "Summer coast trip"` |
| Get a memory | `./scripts/memory-get.sh user:name` |
| List everything | `./scripts/memory-list.sh --stats` |
| Find relevant | `./scripts/memory-rank.sh "working on your docs project"` |
| Check reminders | `./scripts/memory-healthcheck.sh` |

Full reference in [QUICKREF.md](QUICKREF.md).

---

## Why Not Just Search Chat History?

Chat history is text. Ron-Memory is *structured retrieval*:

- **You:** "what's my sister-in-law's birthday?"
- **Semantic search:** "hmm, probably mentioned it somewhere... Morgan? Casey? some month?"
- **Ron-Memory:** `ron:family:laura:birthday = 1988/08/14` — exact answer, instant

Chat history relies on the AI *guessing* from conversation context. Ron-Memory *knows* because it stores facts in the right place with the right structure.

Plus: stories, reinforcement, reminders on cron, cloud sync. Chat history doesn't do any of that.

---

## File Structure

```
~/.openclaw/skills/ron-memory/
├── README.md                ← you are here
├── SKILL.md                 ← agent instructions
├── QUICKREF.md              ← command reference
├── INSTALLATION_GUIDE.md    ← detailed setup
├── references/
│   ├── NAMESPACES.md        ← all namespaces + schemas
│   ├── SCRIPTS.md           ← full script docs
│   ├── REMINDERS.md         ← cron setup
│   └── ARCHITECTURE.md      ← design decisions
└── scripts/
    ├── memory-set.sh        ← save (with staleness detection)
    ├── memory-get.sh        ← get (increments reinforce)
    ├── memory-sync.sh      ← Redis → local cache
    ├── memory-rank.sh       ← scored retrieval
    ├── memory-list.sh       ← list with filters
    ├── memory-healthcheck.sh
    └── check-reminders.sh   ← cron-only reminder checker
```

Memory lives in Redis (cloud) + local cache (fast). Stories and reinforce data live in `ron:story:*` and `ron:reinforce:*` namespaces.

---

## Namespaces

| Namespace | What it stores | TTL |
|-----------|---------------|-----|
| `user` | Your personal data | permanent |
| `family` | Family members | permanent |
| `story` | Life moments ✨ | permanent |
| `contact` | People you know | permanent |
| `vehicle` | Cars, bikes | permanent |
| `project` | Projects | permanent |
| `pref` | Preferences | 30 days |
| `reminder` | Time-critical tasks | 7 days |
| `reinforce` | Access tracking | 7 days |
| `archive` | Dormant entries | permanent |

The `story:*` namespace is what sets v3 apart — it's not just facts, it's the moments that make someone *them*.

---

## Upgrading from v2

```bash
cd ~/.openclaw/skills/ron-memory
./scripts/memory-migrate-v2-to-v3.sh --dry-run   # preview first
./scripts/memory-migrate-v2-to-v3.sh --force     # then migrate
```

---

*Built for Heyron Agent Jam #1 — May 2026*
