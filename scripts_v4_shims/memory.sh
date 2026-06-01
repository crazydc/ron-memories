#!/bin/bash
# v4 top-level entrypoint — direct call to Python CLI
# Use this as `memory set/get/list/...` once symlinked or PATH'd
exec python3 -m ron_memory.cli "$@"
