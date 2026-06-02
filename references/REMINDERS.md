# Reminder System Setup

> **⚠️ v3 feature documentation.** The `check-reminders.sh` cron script described here was a v3 feature. v4 is a library, not a service — it doesn't ship a built-in reminder cron. To set up reminders in v4, use OpenClaw's cron feature, a system cron entry that calls `memory list --namespace reminder`, or your own scheduler. The v4 way to store a reminder is:
>
> ```bash
> memory set "reminder:dentist:appointment" "Call dentist to confirm" --context '{"due": "2026-05-15T14:00:00Z"}'
> ```
>
> You then build your own cron to check for due reminders. v4 just gives you the storage; the scheduling is up to you.

Reminders are time-critical in Ron-Memory v3. Unlike other memories (synced via heartbeat), reminders need their own dedicated cron to ensure they're never missed.

## Why Dedicated Cron?

Heartbeat-based checks have gaps. If the agent heartbeats every 30 minutes, a reminder due at 9:00 AM might not be noticed until 9:28 AM — 28 minutes late.

Reminders are for things that matter **right now**:
- "Call the dentist at 2pm"
- "Pick up Sam from school at 3:30pm"
- "Meeting starts in 5 minutes"

A 5-minute cron ensures max ~5 minute delay on reminder delivery.

## Setup

### 1. Install the cron job

```bash
# Edit crontab
crontab -e
```

### 2. Add reminder cron (every 5 minutes)

```cron
*/5 * * * * bash /root/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh >> /var/log/ron-reminders.log 2>&1
```

### 3. Verify it's installed

```bash
crontab -l | grep ron
# → */5 * * * * bash /root/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh ...
```

### 4. Test the script manually

```bash
bash /root/.openclaw/skills/ron-memory/v3/scripts/check-reminders.sh
# Should output any due reminders, or nothing if none are due
```

## How Reminders Work

### Creating a reminder

```bash
memory-set.sh reminder:dentist:appointment "Call dentist to confirm appointment" --due "2026-05-15T14:00:00Z"
```

Or via natural language to the agent:
> "Remind me to call the dentist tomorrow at 2pm"

### Reminder format

Reminders use the `ron:reminder:*` namespace:

```
ron:reminder:<id>:message = "What to do"
ron:reminder:<id>:due = "2026-05-15T14:00:00Z"
ron:reminder:<id>:created = "2026-05-10T11:00:00Z"
ron:reminder:<id>:status = pending|done|dismissed
```

### check-reminders.sh behavior

1. Scans `ron:reminder:*` keys where `due <= now`
2. Outputs reminder message to stdout (captured by logging)
3. Optionally marks as delivered (configurable)
4. Does NOT auto-dismiss — agent/user must mark done

## Reminder vs Todo

| | Reminder | Todo |
|--|----------|------|
| **Time-critical** | Yes — has a specific due time | No — just needs doing |
| **Proximity** | Checked every 5 min via cron | Synced via heartbeat |
| **Use for** | Appointments, meetings, calls | Tasks, projects, goals |
| **Namespace** | `ron:reminder:*` | `ron:todo:*` |

## Log Rotation

The reminder log can grow indefinitely. Set up log rotation:

```bash
# /etc/logrotate.d/ron-reminders
/var/log/ron-reminders.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

Or simply truncate periodically:

```bash
# In crontab — truncate if over 1MB
0 0 * * * [ -f /var/log/ron-reminders.log ] && [ $(stat -c%s /var/log/ron-reminders.log) -gt 1048576 ] && > /var/log/ron-reminders.log
```

## Troubleshooting

**Reminders not firing:**
1. Check cron is installed: `crontab -l | grep ron`
2. Check script is executable: `ls -la v3/scripts/check-reminders.sh`
3. Test manually: `bash v3/scripts/check-reminders.sh`
4. Check log: `cat /var/log/ron-reminders.log`

**Wrong time showing:**
- System timezone matters. Ensure system TZ matches user's expected TZ.
- Cron runs in system TZ, not user TZ.
- Reminder timestamps should be UTC in storage.
