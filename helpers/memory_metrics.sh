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

: "${HOST_PROC:=/proc}"

_get_meminfo() {
  local f="$HOST_PROC/meminfo"
  if [[ ! -r "$f" ]]; then
    return 1
  fi
  cat "$f"
}
get_memory_raw() {
  read_memory_values
}

get_memory_usage_human() {
  read total used free_bytes <<<"$(get_memory_raw)"
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
  local memfile="${HOST_PROC:-/proc}/meminfo"
  if [[ ! -r "$memfile" ]]; then
    printf "0 0 0"
    return 0
  fi

  read total_k used_k free_k < <(
    awk '
      /^MemTotal:/ { total_k=$2 }
      /^MemAvailable:/ { avail_k=$2 }
      /^MemFree:/ { free_k=$2 }
      END {
        if (total_k ~ /^[0-9]+$/) {
          if (avail_k ~ /^[0-9]+$/) {
            used_k = total_k - avail_k
            free_k = avail_k
          } else if (free_k ~ /^[0-9]+$/) {
            used_k = total_k - free_k
          } else {
            used_k = 0; free_k=0
          }
          printf "%d %d %d", total_k, used_k, free_k
        } else {
          printf "0 0 0"
        }
      }' "$memfile"
    )

    # Convert kB -> bytes in bash (64-bit safe)
    total=$(( (total_k + 0) * 1024 ))
    used=$(( (used_k + 0) * 1024 ))
    free_bytes=$(( (free_k + 0) * 1024 ))

    printf "%d %d %d" "$total" "$used" "$free_bytes"
}
