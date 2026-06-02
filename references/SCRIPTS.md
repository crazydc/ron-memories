# Ron-Memory Script Reference

> **⚠️ This document is deprecated.** It describes the v3 bash scripts (`memory-set.sh`, `memory-get.sh`, etc.) which have been replaced by the v4 Python CLI.
>
> **For v4 script/command reference, see [`../SKILL.md`](../SKILL.md)** — it covers the full `python3 -m ron_memory.cli` command surface plus the `memory` bash wrapper.
>
> ---
>
> ### v3 → v4 command mapping (quick reference)
>
> | v3 (bash) | v4 (Python) |
> |-----------|-------------|
> | `./memory-set.sh <key> <value>` | `memory set <key> <value>` |
> | `./memory-get.sh <key>` | `memory get <key>` |
> | `./memory-list.sh` | `memory list` |
> | `./memory-rank.sh "<query>"` | `memory rank "<query>"` |
> | `./memory-search.sh "<query>"` | `memory search "<query>"` |
> | `./memory-sync.sh` | `memory sync` |
> | `./memory-prune.sh --dry-run` | `memory prune --dry-run` |
> | `./memory-healthcheck.sh` | `memory status` |
> | `./memory-migrate-v2-to-v3.sh` | No v4 equivalent (already done) |
> | `./check-reminders.sh` | No v4 equivalent (use OpenClaw cron) |
>
> v3 bash scripts are kept as backward-compat shims at `scripts_v4_shims/`, so old v3 commands still work — they just delegate to the Python CLI.
>
> **Full v3 reference is preserved in git history** (commit `bd2ece8` was the last v3 commit before the v4 rewrite). If you need to look up v3-specific behaviour, browse that commit.

---

_This file kept as a redirect stub so old links don't 404. New v4 docs live in `../SKILL.md`._
