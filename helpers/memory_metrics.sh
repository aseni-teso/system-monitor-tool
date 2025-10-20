#!/usr/bin/env bash
# Memory metric helpers.
#
# Returns:
#   get_memory_raw() -> "total used free" (integers, bytes)
#   get_memory_usage_human() -> string  - human-readable "used/total (XX.XX%)", e.g. "1.2GiB/4.0GiB (30.00%)"
#   get_memory_usage_percent() -> float - used percent as number, e.g. "30.00"
#   read_memory_values() -> prints "total used free" (integers, bytes) for callers to read
#
# Output format example:
#   $ get_memory_raw
#   17179869184 5284823040 11895046144

set -uo pipefail

get_memory_raw() {
  free -b | awk '/^Mem:/ {printf "%d %d %d",$2,$3,$4}'
}

get_memory_usage_human() {
  read total used free_bytes <<<"$(_getmem=$(get_memory_raw); echo "$_getmem")"
  if [[ -n "$total" && "$total" -gt 0 ]]; then
    mem_percent=$(LC_NUMERIC=C awk -v u="$used" -v t="$total" 'BEGIN{OFS="."; printf "%.2f", u*100/t}')
    if command -v numfmt >/dev/null 2>&1; then
      human_total=$(numfmt --to=iec-i --suffix=B "$total")
      human_used=$(numfmt --to=iec-i --suffix=B "$used")
    else
      human_total="${total}B"
      human_used="${used}B"
    fi
    printf "%s/%s (%.2f%%)\n" "$human_used" "$human_total" "$mem_percent"
  else
    echo "N/A"
  fi
}

get_memory_usage_percent() {
  local total used
  read -r total used _ < <(free -b | awk '/^Mem:/{print $2, $3, $4}')
  if [[ -z "$total" || "$total" -eq 0 ]]; then
    printf "0.00"
    return 0
  fi
  awk -v u="$used" -v t="$total" 'BEGIN{printf "%.2f", u*100/t}'
}

read_memory_values() {
  read total used free_bytes <<<"$(get_memory_raw)"
  printf "%s %s %s" "${total:-0}" "${used:-0}" "${free_bytes:-0}"
}
