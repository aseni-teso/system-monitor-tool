#!/usr/bin/env bash
# CPU metric helpers: small utilities returning system load values.
#
# Returns:
#   get_cpu_load() -> string - load averages as returned by `uptime`, e.g. "0.00, 0.01, 0.05"
#   get_cpu_usage() -> float - overall CPU usage percent (0.0 - 100.0), e.g. "12.34"
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

get_cpu_usage() {
  # simple implementation use /proc/stat to compute busy/total over short interval
  local a b idle1 total1 idle2 total2 diff_idle diff_total busy
  read -r _ a b c d e f g h i j < /proc/stat
  idle1=$d
  total1=$((a + b + c + d + e + f + g + h + i + j))
  sleep 0.1
  read -r _ a b c d e f g h i j < /proc/stat
  idle2=$d
  total2=$((a + b + c + d + e + f + g + h + i + j))
  diff_idle=$((idle2 - idle1))
  diff_total=$((total2 - total1))
  if (( $diff_total <= 0 )); then printf "0.00"; return; fi
  busy=$((diff_total - diff_idle))
  awk -v b="$busy" -v t="$diff_total" 'BEGIN{printf "%.2f", b*100/t}'
}
