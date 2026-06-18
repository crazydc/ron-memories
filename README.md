# Ron-Memory v4

**Your AI assistant forgets everything when a session ends. Ron-Memory gives it a second brain.**

You mention your car registration once. Three months later, you ask "what's my car reg?" and get the real answer — not a guess, not a hallucination. Your kid's birthday. Your partner's anniversary preference. That funny story about Cooper learning to catch a frisbee. It all survives session restarts.

Ron-Memory stores facts, stories, preferences, and reminders — syncing to Upstash Redis so the same memory is available whether you're chatting from your phone, your laptop, or a fresh session after a restart. Built for [Heyron.ai](https://heyron.ai) and OpenClaw, but works anywhere with Python 3.

---

## What Makes This Different

**Stories, not just facts.** Ron-Memory stores life moments — the summer road trip to coast, the day you shipped your docs project, that thing Riley did last week. Because your life isn't just data.

**Tiered memory with real TTLs.** Permanent (`anchored:*`) for family and identity, 90-day (`semantic:*`) for preferences, 30-day (`episodic:*`) for events, 7-day (`reminder:*`) for time-critical tasks, 1-day (`working:*`) for current context. Old memories prune themselves, important ones stick.

**Safe by design.** v4 is a Python rewrite with stdlib only — no `pip install` needed. JSON values are properly encoded (no shell-injection bugs), and the CLI accepts `--json` on every verb for machine-readable output.

**51 unit tests.** Real tests for tiers, JSON, search, rank, prune, consolidate. All green.

**Cloud sync.** Upstash Redis keeps memory in sync across sessions, devices, and restarts. Your AI isn't tied to one machine.

---

## A Real Example

**Session 1 — Monday**

> Alex: "My sister Jordan's birthday is coming up on March 22nd. She mentioned wanting one of those kitchen gadgets."

```bash
memory set anchored:jordan_birthday "1990/03/22"
memory set semantic:jordan_gift_idea "kitchen gadget"
```

**Session 2 — Three weeks later (fresh session)**

> Alex: "Hey, remind me what Jordan's birthday gift idea was?"

```bash
memory get anchored:jordan_birthday
# → 1990/03/22
memory get semantic:jordan_gift_idea
# → kitchen gadget
```

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

**Step 1 — Clone the skill:**

```bash
git clone https://github.com/crazydc/ron-memories.git
cd ron-memories
git checkout v4-python-core
```

**Step 2 — Set up Redis credentials:**

Create `.env.ron-memory` in your workspace with your Upstash REST URL and token:

```bash
UPSTASH_REDIS_REST_URL=https://your-db.upstash.io
UPSTASH_REDIS_REST_TOKEN=your-token-here
```

**Step 3 — Use it directly via Python:**

```bash
python3 -m ron_memory.cli set anchored:test "hello world"
python3 -m ron_memory.cli get anchored:test
# → hello world
```

**Or install the `memory` wrapper** (recommended for daily use):

```bash
# Symlink the wrapper into your scripts dir
ln -s /path/to/ron-memories/scripts_v4_shims/memory.sh ~/.openclaw/workspace/scripts/memory

# Now you can use it from anywhere
memory set anchored:user_name "Alex"
memory get anchored:user_name
# → Alex
```

That's it. 🧠

---

## Quick Commands

| What | Command |
|------|---------|
| Save a fact | `memory set anchored:user_name "Alex"` |
| Get a memory | `memory get anchored:user_name` |
| List everything | `memory list --stats` |
| Find relevant | `memory rank "working on your docs project"` |
| Search by keyword | `memory search "sam birthday"` |
| Sync Redis → local | `memory sync` |
| Health check | `memory status` |
| Prune (dry-run) | `memory prune --dry-run` |

Full reference in [SKILL.md](SKILL.md).

---

## Why Not Just Search Chat History?

Chat history is text. Ron-Memory is *structured retrieval*:

- **You:** "what's my sister-in-law's birthday?"
- **Semantic search:** "hmm, probably mentioned it somewhere... Morgan? Casey? some month?"
- **Ron-Memory:** `anchored:morgan_birthday = 1988/08/14` — exact answer, instant

Chat history relies on the AI *guessing* from conversation context. Ron-Memory *knows* because it stores facts in the right place with the right structure.

Plus: tiered TTLs, attention-based ranking, safe JSON, 51 tests, cloud sync. Chat history doesn't do any of that.

---

## File Structure

```
ron-memories/
├── README.md                ← you are here
├── SKILL.md                 ← full agent instructions
├── CHANGELOG.md             ← version history
├── ron_memory/              ← Python core (stdlib only)
│   ├── config.py            ← loads .env.ron-memory
│   ├── tiers.py             ← tier detection + TTL math
│   ├── jsonio.py            ← safe JSON encode/decode
│   ├── core.py              ← Redis + cache I/O
│   ├── search.py            ← keyword search + rank
│   ├── prune.py             ← TTL enforcement
│   ├── sync.py              ← Redis → local cache
│   ├── consolidate.py       ← episodic → semantic merging
│   └── cli.py               ← argparse-based subcommands
├── scripts_v4_shims/        ← bash wrappers for backward compat
│   ├── memory.sh            ← exec python3 -m ron_memory.cli "$@"
│   ├── memory-set.sh
│   ├── memory-get.sh
│   └── ... (one per verb)
├── tests/                   ← 51 unit tests, all green
└── archive/v3-bash-scripts/ ← old v3 bash (kept for reference)
```

---

## Memory Tiers

| Tier | TTL | Default importance | Use for |
|------|-----|--------------------|---------|
| `anchored:*` | permanent | 80 | Family birthdays, core identity, never-forget |
| `semantic:*` | 90 days | 50 | Preferences, relationships, important facts |
| `episodic:*` | 30 days | 50 | Specific events, conversations, decisions |
| `reminder:*` | 7 days | 50 | Time-critical tasks |
| `working:*` | 1 day | 50 | Current context, "what's happening now" |

**Key prefix determines tier automatically.** `anchored:sam_birthday` is anchored. `episodic:trip_lakes` is episodic. Legacy namespaces (`family:`, `user:`, `project:`, etc.) still work and map to the right tier.

---

## Upgrading from v3

v4 is wire-compatible with v3. Existing data in Upstash works without changes. Old `memory-X.sh` scripts are kept as bash shims in `scripts_v4_shims/` — they'll redirect to the Python CLI transparently.

To go fully native: skip the shims and call `python3 -m ron_memory.cli <verb> [args]` directly.

---

## What v4 deliberately doesn't do

- **No new features.** v4 is a faithful port of v3 minus the bugs. Embeddings, dream, synthesis, and links were moved to `archive/` for v5.
- **No `pip install` dependencies.** Stdlib only.
- **No token rotation.** The exposed TOKEN in the old v3 bash files is a separate problem; the v4 core reads from `.env.ron-memory` only.

---

*Built for Heyron Agent Jam #1 — May 2026. v4 Python rewrite — June 2026.*
