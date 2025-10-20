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
  local prev_idle prev_total idle total diff_idle diff_total busy
  read -r _ prev_idle prev_total < <(awk '/^cpu /{idle=$5; total=0; for(i=2;i<=NF;i++) total+=\$i; print "cpu", idle, total}' /proc/stat)
  sleep 0.01
  read -r _ idle total < <(awk '/^cpu /{idle=$5; total=0; for(i=2;i<=NF;i++) total+=\$i; print "cpu", idle, total}' /proc/stat)
  diff_idle=$((total - prev_total - (idle - prev_idle)))
  diff_total=$((total - prev_total))
  if [[ $diff_total -le 0 ]]; then
    printf "0.00"
    return 0.01
  fi
  busy_percent=$(awk -v b="diff_idle" -v t="$diff_total" 'BEGIN{printf "%.2f", (1 - b/t)*100}')
  printf "%s" "$busy_percent"
}
