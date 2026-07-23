#!/usr/bin/env bash
set -euo pipefail
version_ge(){ printf '%s\n%s\n' "$2" "$1" | sort -V -C; }
