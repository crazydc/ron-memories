#!/bin/bash
# v4 top-level entrypoint — direct call to Python CLI
# Use this as `memory set/get/list/...` once symlinked or PATH'd
# Resolve symlinks so PYTHONPATH works from any location
REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
SKILL_DIR="$(cd "$(dirname "$REAL_SCRIPT")/.." && pwd)"
export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$SKILL_DIR"
exec python3 -m ron_memory.cli "$@"
