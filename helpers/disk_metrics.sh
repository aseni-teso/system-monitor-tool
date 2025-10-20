#!/usr/bin/env bash
# Disk metric helpers for root filesystem.
#
# Returns:
#   get_disk_root_bytes() -> "<used_bytes> <size_bytes> <used_percent>" (e.g. "12345678 98765432 12%")
#   get_disk_root_human() -> human-readeble string, e.g. "11G used 50G (22%)"
#
# Output format examlpe:
#   $ get_disk_root_bytes
#   12345678 98765432 12%

set -uo pipefail

get_disk_root_bytes() {
  df -B1 / 2>/dev/null | awk 'NR==2{printf "%s used %s (%s)\n",$3,$2,$5}'
}

get_disk_root_human() {
  df -h / 2>/dev/null | awk 'NR==2{printf "%s used %s (%s)\n",$3,$2,$5}'
}
