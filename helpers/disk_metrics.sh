#!/usr/bin/env bash
# Disk metric helpers for root filesystem.
#
# Returns:
#   get_disk_root_bytes() -> "<used_bytes> <size_bytes> <used_percent>" (e.g. "12345678 98765432 12%")
#   get_disk_root_human() -> human-readeble string, e.g. "11G used 50G (22%)"
#   get_disk_root_usage_percent() -> float - used percent without "%" (e.g. "22.00")
#
# Output format examlpe:
#   $ get_disk_root_bytes
#   12345678 98765432 12%

set -uo pipefail

get_disk_root_bytes() {
  df -B1 / 2>/dev/null | awk 'NR==2{print $3,$2,$5}'
}

get_disk_root_human() {
  df -h / 2>/dev/null | awk 'NR==2{printf "%s used %s (%s)\n",$3,$2,$5}'
}

get_disk_root_usage_percent() {
  local used size perc
  read -r used size perc < <(df -B1 / 2>/dev/null | awk 'NR==2{print $3, $2, $5}')
  if [[ -z "$size" || "$size" -eq 0 ]]; then
    printf "0.00"
    return 0
  fi
  # perc has trailing %, strip it
  perc=${perc%\%}
  # Ensure numeric
  if ! awk 'BEGIN{exit(!(ARGV[1] ~ /^[0-9]+(\.[0-9]+)?$/))}' "$perc" 2>/dev/null; then
    # fallback: compute from bytes
    awk -v u="$used" -v s="$size" 'BEGIN{if(s>0) printf "%.2f", u*100/s; else print "0.00"}'
  else
    printf "%.2f" "$perc"
  fi
}
