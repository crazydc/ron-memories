#!/bin/bash
# v4 shim for memory-list.sh
exec python3 -m ron_memory.cli list "$@"
