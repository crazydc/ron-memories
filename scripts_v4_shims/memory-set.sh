#!/bin/bash
# v4 shim for memory-set.sh — delegates to Python core
# Usage is identical to the old version
exec python3 -m ron_memory.cli set "$@"
