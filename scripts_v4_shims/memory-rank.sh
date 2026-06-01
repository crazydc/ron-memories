#!/bin/bash
# v4 shim for memory-rank.sh
exec python3 -m ron_memory.cli rank "$@"
