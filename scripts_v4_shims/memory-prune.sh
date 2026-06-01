#!/bin/bash
# v4 shim for memory-prune.sh
exec python3 -m ron_memory.cli prune "$@"
