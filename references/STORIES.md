# Stories — Capturing Life Moments

> **⚠️ v3 feature documentation.** The `story:` namespace and example commands in this doc are v3 syntax. In v4, life moments are stored under `semantic:` or `episodic:` tier prefixes (e.g. `semantic:coast_2025:title`). The concept is the same — rich, emotional memories — but the keys and commands have changed.
>
> For v4, see `SKILL.md`. The `memory set "semantic:coast_2025:title" "..."` example below would now be `memory set semantic:coast_2025→title "..."` in v4 (using `→` for nesting, or just a flat key like `semantic:coast_2025_title`).

Stories are the soul of memory. They transform dry data into something worth reminiscing.

## What Makes a Story vs a Fact?

| Fact | Story |
|------|-------|
| "Sam's birthday is April 15" | "Sam tried to blow out 5 candles but could only manage 3 — kept trying anyway" |
| "We went to the coast" | "Sam called every castle a 'treasure castle' and made us say it back to him" |
| "Cooper is a Labrador" | "Cooper learned to catch a frisbee on his 5th birthday — we all cheered like idiots" |

**Facts** answer: *what is it?*
**Stories** answer: *what happened, and why does it matter?*

Facts are useful. Stories are *human*.

## The Difference in Practice

```
# FACT — clean, functional, searchable
ron:family:sam:birthday = "2020/04/15"
ron:fact:holiday_destination = "coast"

# STORY — rich, emotional, memorable
ron:story:holiday_2025:title = "coast road trip"
ron:story:holiday_2025:description = "Sam called every castle a 'treasure castle'. We played along for three weeks."
ron:story:holiday_2025:moment = "Stopped at a random loch. Cooper swam for an hour. Nobody wanted to leave."
```

## When to Use the `story:` Namespace

**Use `story:` when the memory has:**

- A specific moment or event (not just data)
- Emotional value or personal meaning
- Details you'd want to reminisce about later
- Something you'd tell someone at a dinner party

**Don't use `story:` when:**

- It's pure data (dates, numbers, credentials)
- It's a preference or setting
- You'd only look it up for functional reasons
- It's ephemeral (today's to-do list)

### Quick Decision Guide

| Question | Use |
|----------|-----|
| Do I want to *reminisce* about this? | `story:` |
| Would I tell this story at a dinner party? | `story:` |
| Do I need this data for a task? | `fact:`, `pref:`, `contact:`, etc. |
| Is it just a number or date? | `fact:` |
| Would I google this if I forgot it? | `fact:` |

## Story Key Naming Pattern

```
ron:story:<theme>:<instance>:<aspect>
```

| Level | Meaning | Example |
|-------|---------|---------|
| `ron:story:` | Stories namespace | `ron:story:` |
| `<theme>` | What the story is about | `holiday_2025`, `wedding`, `strategy-game` |
| `<instance>` | Which specific occurrence | `session_2026_05_02`, `trip_001` |
| `<aspect>` | What aspect of the story | `title`, `description`, `moment`, `players` |

### Theme Ideas

- `holiday_2025` — summer vacation
- `wedding` — someone's wedding (could add year: `wedding_2024`)
- `strategy-game` — board game nights with the a strategy board game group
- `work-milestone` — career achievements
- `family-moment` — everyday moments worth preserving
- `pet-moment` — things the dog/cat did
- `first-time` — first experiences

### Aspect Keys

Common aspects for any story:

| Key | What it stores |
|-----|----------------|
| `title` | Short name for the story (5-10 words) |
| `description` | What happened (full paragraph) |
| `moment` | The highlight — the thing you'd tell first |
| `date` | When it happened (YYYY-MM-DD) |
| `players` | Who was there (comma-separated) |
| `location` | Where it happened |
| `emotional_tags` | How it felt (happy, sad, hilarious, proud) |
| `photos` | URLs or references to photos |

## How memory-rank.sh Uses Stories

Stories get a **+20 bonus** in the ranking algorithm.

```bash
# From memory-rank.sh
if [[ "$key" == story:* ]]; then
  score=$((score + 20))
fi
```

This means when you search for something, stories bubble up — they're treated as more "important" than plain facts because they're more likely to be relevant when you're having a conversation.

### Why +20?

- Facts are easily re-learned
- Stories are irreplaceable — you can't Google "what did Sam call castles"
- Stories make conversations feel human, not robotic
- The bonus is high enough to matter, low enough not to dominate

## Example Workflow: "Alex played a strategy board game with two friends"

### Before the session

Nothing in memory yet.

### During the conversation

You might say: "remember Alex played a strategy board game with two friends on May 2nd, Cooper needed letting out mid-game"

### What gets stored

```bash
# The title — how you'd refer to this story later
memory-set.sh "story:strategy-game:session_2026_05_02:title" "a strategy board game game night"

# Who was there
memory-set.sh "story:strategy-game:session_2026_05_02:players" "Alex, two friends"

# The date
memory-set.sh "story:strategy-game:session_2026_05_02:date" "2026-05-02"

# The highlight — the memorable bit
memory-set.sh "story:strategy-game:session_2026_05_02:moment" "Cooper the dog needed letting out mid-game, Alex had to pause the entire railway empire to let him out"

# Optional: tags for emotional context
memory-set.sh "story:strategy-game:session_2026_05_02:emotional_tags" "funny,chaotic,family"

# Optional: description for more context
memory-set.sh "story:strategy-game:session_2026_05_02:description" "Regular board game night at Alex's. the friend brought his new new expansion. Game went on for 4 hours. Cooper kept interrupting."
```

### Later — when reminiscing

Someone asks: "remember any funny game nights?"

Memory retrieves `story:strategy-game:*` keys, sees the +20 bonus, and surfaces:

> **a strategy board game game night**
> "Cooper the dog needed letting out mid-game, Alex had to pause the entire railway empire to let him out"
> Alex, two friends — 2026-05-02

### Even Later — years from now

Sam's grown up, you ask: "what was that game night like?"

You pull up all `story:strategy-game:*` stories and have a conversation about the time Dad paused a railway empire for a dog.

## More Story Examples

### A Holiday

```bash
# Theme: holiday_2025
# Instance: trip_001
story:holiday_2025:trip_001:title = "Summer coast road trip"
story:holiday_2025:trip_001:description = "Two weeks driving up the east coast. Stopped everywhere. Sam had a phase of naming every castle a treasure castle."
story:holiday_2025:trip_001:moment = "Random loch at golden hour. Cooper swam for an hour straight. Nobody wanted to leave."
story:holiday_2025:trip_001:date = "2025-08-10"
story:holiday_2025:trip_001:players = "Alex, Pat, Sam, Riley, Cooper"
story:holiday_2025:trip_001:location = "coast, UK"
story:holiday_2025:trip_001:emotional_tags = "happy,adventure,family,warm"
```

### A Work Milestone

```bash
story:work-milestone:your-docs:title = "Heyron docs shipped"
story:work-milestone:your-docs:moment = "First time seeing docs.heylon.ai live. Proper proud — spent 3 weeks on that navigation redesign."
story:work-milestone:your-docs:date = "2026-05-08"
story:work-milestone:your-docs:emotional_tags = "proud,relief,achievement"
```

### A Pet Moment

```bash
story:pet:buddy:catch_2024:title = "Cooper learned to catch"
story:pet:buddy:catch_2024:moment = "Finally caught a frisbee on his 5th birthday. We all cheered like idiots in the garden."
story:pet:buddy:catch_2024:date = "2024-07-15"
story:pet:buddy:catch_2024:emotional_tags = "proud,funny,love"
```

### A Wedding

```bash
story:wedding:morgan_shaun:title = "Morgan and Drew's wedding"
story:wedding:morgan_shaun:moment = "Drew's speech — he kept going off script and improvising. Pat was crying laughing."
story:wedding:morgan_shaun:date = "TBD"
story:wedding:morgan_shaun:players = "Alex, Pat, Drew, Morgan, family"
story:wedding:morgan_shaun:emotional_tags = "joy,family,celebration"
```

## The Goal

Stories turn memory from a database into a *life*.

A fact tracker knows you went to the coast.
A story tracker knows you went to the coast, Sam called castles treasure castles, and you still laugh about it.

**Store the moments. Not just the data.**

---

See also: [NAMESPACES.md](./NAMESPACES.md) for the full namespace structure