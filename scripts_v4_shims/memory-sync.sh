#!/bin/bash
# v4 shim for memory-sync.sh
exec python3 -m ron_memory.cli sync "$@"
