#!/bin/bash
# v4 shim for memory-consolidate.sh
exec python3 -m ron_memory.cli consolidate "$@"
