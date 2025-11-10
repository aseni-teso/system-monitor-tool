#!/usr/bin/env bash
# Script for CI: create a minimal /proc snapshot used for tests.
# Produces ./proc_snapshot directory with selected files.
set -euo pipefail

OUT_DIR="${1:-./proc_snapshot}"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# List of top-level files to copy
files=(/proc/stat /proc/uptime /proc/meminfo)

for f in "${files[@]}"; do
  if [[ -r "$f" ]]; then
    dest="$OUT_DIR${f}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$f" "$dest"
  fi
done

# Copy /proc/<pid>/status for pid 1 and current $ if present
pids=(1 $)
for pid in "${pids[@]}"; do
  src="/proc/${pid}/status"
  if [[ -r "$src" ]]; then
    dest="$OUT_DIR/proc/${pid}/status"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi
done

# Ensure permissions safe for CI mount
chmod -R a+rX "$OUT_DIR"
echo "Created proc snapshot at $OUT_DIR"
