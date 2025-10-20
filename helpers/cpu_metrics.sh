#!/usr/bin/env bash
# CPU metric helpers: small utilities returning system load values.
#
# Returns:
#   get_cpu_load() -> string - load averages as returned by `uptime`, e.g. "0.00, 0.01, 0.05"
#
# Output format example:
#   $ get_cpu_load
#   0.00, 0.01, 0.05
#
# Dependencies:
#   - expects `uptime` (POSIX) and/or /proc/stat for alternative implementations.

set -uo pipefail

get_cpu_load() {
  uptime | awk -F'load average:' '{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}'
}
