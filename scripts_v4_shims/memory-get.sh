#!/bin/bash
# v4 shim for memory-get.sh
exec python3 -m ron_memory.cli get "$@"
