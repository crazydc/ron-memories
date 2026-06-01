#!/bin/bash
# v4 shim for memory-healthcheck.sh
exec python3 -m ron_memory.cli status "$@"
