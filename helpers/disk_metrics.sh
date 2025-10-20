#!/usr/bin/env bash
# Disk metric helpers

set -uo pipefail

get_disk_root_bytes() {
  df -B1 / 2>/dev/null | awk 'NR==2{printf "%s used %s (%s)\n",$3,$2,$5}'
}

get_disk_root_human() {
  df -h / 2>/dev/null | awk 'NR==2{printf "%s used %s (%s)\n",$3,$2,$5}'
}
