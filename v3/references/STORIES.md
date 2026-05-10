# Stories — Capturing Life Moments

Stories are the soul of memory. They transform dry data into something worth reminiscing.

## What Makes a Story vs a Fact?

| Fact | Story |
|------|-------|
| "Freddie's birthday is November 8" | "Freddie tried to blow out 5 candles but could only manage 3 — kept trying anyway" |
| "We went to Scotland" | "Freddie called every castle a 'dragon house' and made us say it back to him" |
| "Rupert is a Labrador" | "Rupert learned to catch a frisbee on his 6th birthday — we all cheered like idiots" |

**Facts** answer: *what is it?*
**Stories** answer: *what happened, and why does it matter?*

Facts are useful. Stories are *human*.

## The Difference in Practice

```
# FACT — clean, functional, searchable
ron:family:freddie:birthday = "2019/11/08"
ron:fact:holiday_destination = "Scotland"

# STORY — rich, emotional, memorable
ron:story:holiday_2025:title = "Scotland road trip"
ron:story:holiday_2025:description = "Freddie called every castle a 'dragon house'. We played along for three weeks."
ron:story:holiday_2025:moment = "Stopped at a random loch. Rupert swam for an hour. Nobody wanted to leave."
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
| `<theme>` | What the story is about | `holiday_2025`, `wedding`, `1822-mrs` |
| `<instance>` | Which specific occurrence | `session_2026_05_02`, `trip_001` |
| `<aspect>` | What aspect of the story | `title`, `description`, `moment`, `players` |

### Theme Ideas

- `holiday_2025` — summer vacation
- `wedding` — someone's wedding (could add year: `wedding_2024`)
- `1822-mrs` — board game nights with the 1822 MRS group
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
- Stories are irreplaceable — you can't Google "what did Freddie call castles"
- Stories make conversations feel human, not robotic
- The bonus is high enough to matter, low enough not to dominate

## Example Workflow: "Dale played 1822 MRS with Sven and Karl"

### Before the session

Nothing in memory yet.

### During the conversation

You might say: "remember Dale played 1822 MRS with Sven and Karl on May 2nd, Rupert needed letting out mid-game"

### What gets stored

```bash
# The title — how you'd refer to this story later
memory-set.sh "story:1822-mrs:session_2026_05_02:title" "1822 MRS game night"

# Who was there
memory-set.sh "story:1822-mrs:session_2026_05_02:players" "Dale, Sven, Karl"

# The date
memory-set.sh "story:1822-mrs:session_2026_05_02:date" "2026-05-02"

# The highlight — the memorable bit
memory-set.sh "story:1822-mrs:session_2026_05_02:moment" "Rupert the dog needed letting out mid-game, Dale had to pause the entire railway empire to let him out"

# Optional: tags for emotional context
memory-set.sh "story:1822-mrs:session_2026_05_02:emotional_tags" "funny,chaotic,family"

# Optional: description for more context
memory-set.sh "story:1822-mrs:session_2026_05_02:description" "Regular board game night at Dale's. Sven brought his new 1822 expansion. Game went on for 4 hours. Rupert kept interrupting."
```

### Later — when reminiscing

Someone asks: "remember any funny game nights?"

Memory retrieves `story:1822-mrs:*` keys, sees the +20 bonus, and surfaces:

> **1822 MRS game night**
> "Rupert the dog needed letting out mid-game, Dale had to pause the entire railway empire to let him out"
> Dale, Sven, Karl — 2026-05-02

### Even Later — years from now

Freddie's grown up, you ask: "what was that game night like?"

You pull up all `story:1822-mrs:*` stories and have a conversation about the time Dad paused a railway empire for a dog.

## More Story Examples

### A Holiday

```bash
# Theme: holiday_2025
# Instance: trip_001
story:holiday_2025:trip_001:title = "Summer Scotland road trip"
story:holiday_2025:trip_001:description = "Two weeks driving up the east coast. Stopped everywhere. Freddie had a phase of naming every castle a dragon house."
story:holiday_2025:trip_001:moment = "Random loch at golden hour. Rupert swam for an hour straight. Nobody wanted to leave."
story:holiday_2025:trip_001:date = "2025-08-10"
story:holiday_2025:trip_001:players = "Dale, Louise, Freddie, Magnus, Rupert"
story:holiday_2025:trip_001:location = "Scotland, UK"
story:holiday_2025:trip_001:emotional_tags = "happy,adventure,family,warm"
```

### A Work Milestone

```bash
story:work-milestone:heyron-docs:title = "Heyron docs shipped"
story:work-milestone:heyron-docs:moment = "First time seeing docs.heylon.ai live. Proper proud — spent 3 weeks on that navigation redesign."
story:work-milestone:heyron-docs:date = "2026-05-08"
story:work-milestone:heyron-docs:emotional_tags = "proud,relief,achievement"
```

### A Pet Moment

```bash
story:pet:rupert:catch_2024:title = "Rupert learned to catch"
story:pet:rupert:catch_2024:moment = "Finally caught a frisbee on his 6th birthday. We all cheered like idiots in the garden."
story:pet:rupert:catch_2024:date = "2024-07-15"
story:pet:rupert:catch_2024:emotional_tags = "proud,funny,love"
```

### A Wedding

```bash
story:wedding:laura_shaun:title = "Laura and Shaun's wedding"
story:wedding:laura_shaun:moment = "Shaun's speech — he kept going off script and improvising. Louise was crying laughing."
story:wedding:laura_shaun:date = "TBD"
story:wedding:laura_shaun:players = "Dale, Louise, Shaun, Laura, family"
story:wedding:laura_shaun:emotional_tags = "joy,family,celebration"
```

## The Goal

Stories turn memory from a database into a *life*.

A fact tracker knows you went to Scotland.
A story tracker knows you went to Scotland, Freddie called castles dragon houses, and you still laugh about it.

**Store the moments. Not just the data.**

---

See also: [NAMESPACES.md](./NAMESPACES.md) for the full namespace structure