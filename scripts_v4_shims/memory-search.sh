#!/bin/bash
# v4 shim for memory-search.sh — delegates to Python core
# Resolves symlinks so it works from any path
REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
SKILL_DIR="$(cd "$(dirname "$REAL_SCRIPT")/.." && pwd)"
export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$SKILL_DIR"
exec python3 -m ron_memory.cli search "$@"
