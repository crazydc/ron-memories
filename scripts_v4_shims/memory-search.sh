#!/bin/bash
# v4 shim for memory-search.sh
exec python3 -m ron_memory.cli search "$@"
