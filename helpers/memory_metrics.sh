#!/usr/bin/env bash
# Memory metric helpers

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

# small wrapper to return raw values to caller
read_memory_values() {
  read total used free_bytes <<<"$(get_memory_raw)"
  printf "%s %s %s" "${total:-0}" "${used:-0}" "${free_bytes:-0}"
}
