# Agent Queue System

A shared task queue system using Ron-Memory as the backbone. Tasks are queued by Jeff (orchestrator), picked up by sub-agents on their heartbeat, executed, and reported back to Alex via Telegram.

## Quick Start

**Add a task:**
```bash
# Write task to Dave's queue
memory set "agent-dev-queue" '[{"id":"task-001","task":"Your task description","created":"2026-05-26T21:00:00Z","priority":"normal"}]' --stale-ok
```

**Check a queue:**
```bash
memory get "agent-dev-queue"
```

**Clear a queue:**
```bash
memory set "agent-dev-queue" "[]" --stale-ok
```

---

## Queue Keys

| Agent | Queue Key | Telegram Bot |
|-------|-----------|--------------|
| Jeff (main) | `agent-main-queue` | @main_bot |
| Dave | `agent-dev-queue` | @dev_bot |
| TechSupport | `agent-support-queue` | @support_bot |
| Perforce | `agent-work-queue` | @work_bot |

---

## Task Format

Tasks are JSON arrays with one task object per item:

```json
[
  {
    "id": "unique-id-001",
    "task": "Task description here",
    "created": "2026-05-26T21:00:00Z",
    "priority": "normal"
  }
]
```

Multiple tasks are supported - agents process FIFO (first in, first out).

---

## How It Works

```
Jeff (orchestrator)
    ↓ writes task
Ron-Memory queue
    ↓ heartbeat triggers (every 5 min)
Agent (dave/techsupport/etc)
    ↓ picks up task
    ↓ sends Telegram to Alex: "🔧 Taking task: X"
    ↓ executes task
    ↓ sends Telegram: "✅ Finished: X - result"
    ↓ logs to logs/agent-X-results.md
    ↓ clears queue
```

---

## Agent Behaviour

Each agent checks their queue on every heartbeat cycle (5 min). When a task exists:

1. **Pickup** - Takes first task (FIFO by created timestamp)
2. **Notify** - Sends Telegram: "🔧 Taking task: [task]"
3. **Execute** - Works on the task
4. **Complete** - Sends Telegram: "✅ Finished: [task]\n📝 [result]"
5. **Log** - Writes result to `logs/agent-X-results.md`
6. **Clear** - Removes task from Ron-Memory queue

**Empty queue:** Agent replies HEARTBEAT_OK only, no messages sent.

---

## Results Log

Each agent logs completed tasks to:
- `logs/agent-dave-results.md`
- `logs/agent-techsupport-results.md`
- `logs/agent-perforce-results.md`
- `logs/agent-main-results.md`

Format:
```markdown
## [timestamp] - Task Completed

**Task:** [description]
**Context:** [what was done]
```

---

## Alex's Prompt to Add an Agent

When setting up a new agent or updating an existing one:

```
[Agent Name] - sort your heartbeat out.

Every 5 minutes on your heartbeat cycle:
1. Read Ron-Memory key "[agent-queue-key]"
2. If empty → reply HEARTBEAT_OK only
3. If tasks exist:
   a. Take first task (FIFO by created timestamp)
   b. Send Telegram to Alex via your bot: "🔧 Taking task: [task]"
   c. Execute the task
   d. Send Telegram: "✅ Finished: [task description]\n📝 [what you did]"
   e. Log result to /root/.openclaw/workspace/logs/[agent-results].md with timestamp
   f. Clear task from Ron-Memory (set [agent-queue-key] to empty)
   g. Reply HEARTBEAT_OK

Use message tool with channel="telegram", accountId="[accountId]".
Keep messages short, no markdown tables. Report back when done.
```

---

## Example: Adding a Task

**Task:** "Check weather for Greenfield Park tomorrow"
**Agent:** TechSupport

```bash
memory set "agent-support-queue" '[{"id":"weather-001","task":"Check weather for Greenfield Family Park tomorrow (Wed May 27)","created":"2026-05-26T21:30:00Z","priority":"normal"}]' --stale-ok
```

TechSupport picks it up on next heartbeat, sends you the weather, logs it, clears queue.

---

## Notes

- Tasks persist in Redis until cleared - safe across restarts
- Agents only read their own queue (read-only for others)
- Queues are simple JSON arrays - easy to inspect manually
- All agents share the same Ron-Memory backend

---

_Last updated: 2026-05-26 (v4 update: 2026-06-02)_