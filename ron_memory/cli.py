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

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
