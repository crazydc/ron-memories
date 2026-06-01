"""CLI entrypoint for Ron-Memory v4.

Run with: python3 -m ron_memory.cli <verb> [args]
Or via:   memory <verb> [args]    (shell script wrapper)
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

from .core import Memory
from .tiers import detect_tier, validate_importance, validate_tier
from . import search as search_mod
from . import prune as prune_mod
from . import sync as sync_mod
from . import consolidate as consolidate_mod


# ─── Verbs ───────────────────────────────────────────────────────────────

def cmd_set(args: argparse.Namespace) -> int:
    m = Memory()
    result = m.set(
        key=args.key,
        value=args.value,
        tier=args.tier,
        importance=args.importance,
        context=args.context or "",
        force=args.force,
        stale_ok=args.stale_ok,
    )
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        if result["status"] == "rejected":
            print(f"⚠️  Staleness detected: '{args.key}' already exists")
            print(f"   Old: {result['old_value']!r}")
            print(f"   New: {result['new_value']!r}")
            print()
            print("Options:")
            print("  --force    Overwrite without archiving")
            print("  --stale-ok Archive old value, then save new")
            return 1
        elif result["status"] == "error":
            print(f"❌ {result['reason']}")
            return 1
        else:
            ctx_info = f" context={result['context']}" if result.get("context") else ""
            print(f"✅ Saved '{result['key']}' (tier={result['tier']}, importance={result['importance']}{ctx_info})")
    return 0


def cmd_get(args: argparse.Namespace) -> int:
    m = Memory()
    value = m.get(args.key)
    if value is None:
        if args.json:
            print(json.dumps({"status": "not_found", "key": args.key}))
        else:
            print(f"Key not found: {args.key}")
        return 1
    if args.json:
        print(json.dumps({"status": "ok", "key": args.key, "value": value}))
    else:
        print(value)
    return 0


def cmd_delete(args: argparse.Namespace) -> int:
    m = Memory()
    existed = m.delete(args.key)
    if args.json:
        print(json.dumps({"key": args.key, "existed": existed}))
    else:
        if existed:
            print(f"✅ Deleted '{args.key}'")
        else:
            print(f"Key not found: {args.key}")
    return 0 if existed else 1


def cmd_list(args: argparse.Namespace) -> int:
    m = Memory()
    entries = m.cache_entries()
    if args.namespace:
        entries = [e for e in entries if e["key"].split(":", 1)[0] == args.namespace]
    if args.stats:
        from collections import Counter
        ns_counter = Counter(e["key"].split(":", 1)[0] for e in entries)
        result = {
            "total": len(entries),
            "by_namespace": dict(ns_counter.most_common()),
        }
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"Total entries: {result['total']}")
            print("By namespace:")
            for ns, count in result["by_namespace"].items():
                print(f"  {ns}: {count}")
        return 0
    if args.json:
        print(json.dumps(entries, indent=2))
    else:
        for e in entries:
            print(f"{e['key']} = {e['value']}")
            print(f"   tier={e['tier']} importance={e['importance']} updated={e['timestamp']}")
            print()
        print(f"({len(entries)} entries shown)")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    m = Memory()
    result = m.healthcheck()
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print("🔍 Ron-Memory v4 Status")
        print("=" * 40)
        print(f"Redis:           {'✅ connected' if result['redis'] else '❌ down'}")
        print(f"Redis keys:      {result['redis_key_count']}")
        print(f"Cache file:      {'✅' if result['cache_file_exists'] else '❌ missing'}")
        print(f"Cache entries:   {result['cache_entries']}")
        print(f"Migration done:  {'✅' if result['migration_done'] else '⚠️  not flagged'}")
        if result.get("write_ok"):
            print(f"Write test:      ✅")
        if result.get("sample_read"):
            print(f"Sample read:     {result['sample_read']!r}")
        if result["errors"]:
            print()
            print("Errors:")
            for e in result["errors"]:
                print(f"  - {e}")
    return 0 if result["redis"] else 1


def cmd_search(args: argparse.Namespace) -> int:
    m = Memory()
    entries = m.cache_entries()
    results = search_mod.search(
        entries,
        args.query,
        limit=args.limit,
        namespace_filter=args.namespace,
    )
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        if not results:
            print(f"No matches for: {args.query!r}")
            return 1
        for r in results:
            print(f"[{r['score']}] {r['key']} = {r['value'][:120]}")
            print(f"     tier={r['tier']} importance={r.get('importance', 50)}")
        print()
        print(f"({len(results)} results)")
    return 0


def cmd_rank(args: argparse.Namespace) -> int:
    m = Memory()
    entries = m.cache_entries()
    namespaces = args.namespaces.split(",") if args.namespaces else None
    results = search_mod.rank(
        entries,
        args.task,
        limit=args.limit,
        budget=args.budget,
        namespaces=namespaces,
    )
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        if not results:
            print(f"No relevant memories for task: {args.task!r}")
            return 1
        for r in results:
            print(f"[{r['score']}] {r['key']} = {r['value'][:120]}")
        print()
        print(f"({len(results)} ranked)")
    return 0


def cmd_prune(args: argparse.Namespace) -> int:
    m = Memory()
    entries = m.cache_entries()
    result = prune_mod.prune(
        entries,
        namespace_filter=args.namespace or None,
        dry_run=args.dry_run,
    )
    if args.json:
        print(json.dumps({
            "pruned_count": result["pruned_count"],
            "survivor_count": result["survivor_count"],
            "dry_run": result["dry_run"],
        }, indent=2))
    else:
        print(f"✂️  Prune {'(DRY RUN)' if args.dry_run else '(LIVE)'}")
        print(f"   Pruned:   {result['pruned_count']}")
        print(f"   Survivors: {result['survivor_count']}")
        if args.dry_run:
            print()
            print("Run with --force to apply.")
    return 0


def cmd_sync(args: argparse.Namespace) -> int:
    m = Memory()
    result = sync_mod.sync_cache(m.cache_file)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"🔄 Synced {result['synced']} entries ({result['failed']} failed)")
    return 0


def cmd_consolidate(args: argparse.Namespace) -> int:
    m = Memory()
    entries = m.cache_entries()
    candidates = consolidate_mod.find_consolidation_candidates(
        entries,
        min_age_days=args.days,
    )
    if args.json:
        out = []
        for c in candidates:
            out.append({
                "topic": c["topic"],
                "source_count": len(c["entries"]),
                "proposed": consolidate_mod.build_summary(c["topic"], c["entries"]),
            })
        print(json.dumps(out, indent=2))
    else:
        if not candidates:
            print("No consolidation candidates found.")
            return 0
        print(f"📦 Found {len(candidates)} topic(s) for consolidation:")
        for c in candidates:
            print(f"\n  Topic: {c['topic']} ({len(c['entries'])} entries)")
            for e in c["entries"]:
                print(f"    - {e['key']}: {e['value'][:80]}")
            summary = consolidate_mod.build_summary(c["topic"], c["entries"])
            print(f"  Proposed: {summary['key']} = {summary['value'][:100]}...")
        if args.dry_run:
            print("\n(DRY RUN — no changes made)")
    return 0


def cmd_migrate_flag(args: argparse.Namespace) -> int:
    ok = sync_mod.set_migration_flag()
    if args.json:
        print(json.dumps({"migration_flag_set": ok}))
    else:
        if ok:
            print("✅ Migration flag set in Redis")
        else:
            print("❌ Failed to set migration flag")
    return 0 if ok else 1


# ─── Argparse ────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="memory",
        description="Ron-Memory v4 — second-brain memory store",
    )
    sub = p.add_subparsers(dest="verb", required=True)

    # set
    p_set = sub.add_parser("set", help="Save a memory")
    p_set.add_argument("key")
    p_set.add_argument("value")
    p_set.add_argument("--tier", choices=["anchored", "semantic", "episodic", "reminder", "working"])
    p_set.add_argument("--importance", type=int, default=50)
    p_set.add_argument("--context", default="")
    p_set.add_argument("--force", action="store_true")
    p_set.add_argument("--stale-ok", action="store_true")
    p_set.add_argument("--json", action="store_true")
    p_set.set_defaults(func=cmd_set)

    # get
    p_get = sub.add_parser("get", help="Retrieve a memory")
    p_get.add_argument("key")
    p_get.add_argument("--json", action="store_true")
    p_get.set_defaults(func=cmd_get)

    # delete
    p_del = sub.add_parser("delete", help="Delete a memory")
    p_del.add_argument("key")
    p_del.add_argument("--json", action="store_true")
    p_del.set_defaults(func=cmd_delete)

    # list
    p_list = sub.add_parser("list", help="List memories")
    p_list.add_argument("--namespace", help="Filter by namespace (e.g. anchored, family)")
    p_list.add_argument("--stats", action="store_true")
    p_list.add_argument("--json", action="store_true")
    p_list.set_defaults(func=cmd_list)

    # status
    p_status = sub.add_parser("status", help="System health snapshot")
    p_status.add_argument("--json", action="store_true")
    p_status.set_defaults(func=cmd_status)

    # search
    p_search = sub.add_parser("search", help="Fuzzy keyword search across key + value")
    p_search.add_argument("query")
    p_search.add_argument("--limit", type=int, default=10)
    p_search.add_argument("--namespace", help="Filter by namespace prefix")
    p_search.add_argument("--json", action="store_true")
    p_search.set_defaults(func=cmd_search)

    # rank
    p_rank = sub.add_parser("rank", help="Attention-based ranking for a task")
    p_rank.add_argument("task")
    p_rank.add_argument("--limit", type=int, default=20)
    p_rank.add_argument("--budget", type=int, default=2000)
    p_rank.add_argument("--namespaces", help="Comma-separated namespace filter")
    p_rank.add_argument("--json", action="store_true")
    p_rank.set_defaults(func=cmd_rank)

    # prune
    p_prune = sub.add_parser("prune", help="TTL enforcement (dry-run by default)")
    p_prune.add_argument("--namespace", help="Only prune this namespace")
    p_prune.add_argument("--dry-run", action="store_true", default=True)
    p_prune.add_argument("--force", action="store_true", help="Actually apply changes")
    p_prune.add_argument("--json", action="store_true")
    p_prune.set_defaults(func=cmd_prune)

    # sync
    p_sync = sub.add_parser("sync", help="Sync Redis -> local cache")
    p_sync.add_argument("--json", action="store_true")
    p_sync.set_defaults(func=cmd_sync)

    # consolidate
    p_cons = sub.add_parser("consolidate", help="Find episodic entries to consolidate")
    p_cons.add_argument("--days", type=int, default=14)
    p_cons.add_argument("--dry-run", action="store_true", default=True)
    p_cons.add_argument("--json", action="store_true")
    p_cons.set_defaults(func=cmd_consolidate)

    # migrate-flag
    p_mig = sub.add_parser("migrate-flag", help="Set the v2->v3 migration flag in Redis")
    p_mig.add_argument("--json", action="store_true")
    p_mig.set_defaults(func=cmd_migrate_flag)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
