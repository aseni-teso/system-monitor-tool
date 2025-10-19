#!/usr/bin/env bash
# system-metrics.sh
# Simple, reliable metrics collection "core".

set -uo pipefail

# Force C locale for numeric computation (doesn't change user's LC_* outside script)
export LC_NUMERIC=C
export LANG=C.UTF-8

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Interval (seconds) between updates in watch mode; 0 = run once
INTERVAL=0
# Max command width to compact display (will be adjusted to terminal width)

usage () {
  cat <<EOF
Usage: $0 [--watch seconds] [--json] [--help] [--max-cmd N]
  --watch seconds   Repeat collection every seconds (default: run once)
  --json            Output results in JSON (one-shot, ignores colors)
  --help            Show this message
EOF
}

# Truncate a string to max length with ellipsis
truncate_cmd() {
  local s="$1" max=${2:-60}
  if [[ ${#s} -le $max ]]; then
    printf "%s" "$s"
  else
    printf "%s..." "${s:0:$(($max-1))}"
  fi
}

# Determine max cmd width based on terminal width
compute_max_cmd() {
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local reserved=36
  local max=$((cols - reserved))
  if [[ $max -lt 20 ]]; then max=20; fi
  echo "$max"
}

# Print top N procs with truncated CMD
print_top_procs_compact() {
  local sortfield="${1:-%cpu}" n=${2:-5} maxcmd
  maxcmd=$(compute_max_cmd)
  printf "  %-12s %-6s %6s %6s  %s\n" "USER" "PID" "%CPU" "%MEM" "CMD"
  ps -eo user,pid,pcpu,pmem,cmd --sort=-${sortfield} | awk -v n="$n" -v maxcmd="$maxcmd" '
    NR>1 && NR<=n+1{
      user=$1; pid=$2; pcpu=$3; pmem=$4;
      cmd=$5;
      for(i=6;i<=NF;i++) cmd=cmd " " $i;
      if (length(cmd) > maxcmd) {
        cmd = substr(cmd,1,maxcmd-1) "..."
      }
      printf "  %-12s %-6s %6s %6s  %s\n", user, pid, pcpu, pmem, cmd    
    }'
}

# Get CPU load (load averages)
get_cpu_load() {
  printf "%s\n" "$(uptime | awk -F'load average:' '{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')"
}

# Get memory usage (bytes and percent)
get_memory_usage() {
  read total used free <<<$(free -b | awk '/^Mem:/ {printf "%d %d %d",$2,$3,$4}')
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

# Disk usage for /
get_disk_usage_root() {
  df -B1 / 2>/dev/null | awk 'NR==2{printf "%s used %s (%s)\n",$3,$2,$5}' || \
  df -h / 2>/dev/null | awk 'NR==2{printf "%s used %s (%s)\n",$3,$2,$5}'
}

# Collect all metrics as colored text
collect_text() {
  local maxcmd
  maxcmd=$(compute_max_cmd)
  echo -e "${GREEN}=== System Metrics ===${NC}"
  echo -e "${BLUE}Timestamp:${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo -e "${BLUE}CPU Load (1,5,15):${NC} $(get_cpu_load)"
  echo -e "${BLUE}Memory:${NC} $(get_memory_usage)"
  echo -e "${BLUE}Disk (/) :${NC} $(get_disk_usage_root)"
  echo -e "${BLUE}Top 5 CPU processes:${NC}"
  print_top_procs_compact "%cpu" 5 "$maxcmd" | sed 's/^/  /'
  echo -e "${BLUE}Top 5 Memory processes:${NC}"
  print_top_procs_compact "%mem" 5 "$maxcmd" | sed 's/^/  /'
}

# Collect all metrics as JSON (no color)
collect_json () {
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cpu_load=$(get_cpu_load | sed 's/^ *//;s/"/\\"/g')

  read total used free <<<$(free -b | awk '/^Mem:/ {printf "%d %d %d",$2,$3,$4}')
  mem_percent=null
  if [[ -n "$total" && "$total" -gt 0 ]]; then
    mem_percent=$(LC_NUMERIC=C awk -v u="$used" -v t="$total" 'BEGIN{printf "%.2f", u*100/t}')
  fi

  disk_raw=$(df -B1 / 2>/dev/null | awk 'NR==2{printf "{\"used\":%d,\"size\":%d,\"use_percent\":\"%s\"}",$3,$2,$5}')
  if [[ -z "$disk_raw" ]]; then
    disk_raw=null
  fi

  top_cpu=$(ps aux --sort=-%cpu | head -n 6 | awk 'NR>1{cmd=""; for(i=11;i<=NF;i++){cmd=cmd (i==11?"":" ") $i} gsub(/"/,"\\\"",cmd); printf "{\"user\":\"%s\",\"pid\":%s,\"pcpu\":%s,\"pmem\":%s,\"cmd\":\"%s\"}%s",$1,$2,$3,$4,cmd,(NR==6?"":",") }')
  top_mem=$(ps aux --sort=-%mem | head -n 6 | awk 'NR>1{cmd=""; for(i=11;i<=NF;i++){cmd=cmd (i==11?"":" ") $i} gsub(/"/,"\\\"",cmd); printf "{\"user\":\"%s\",\"pid\":%s,\"pcpu\":%s,\"pmem\":%s,\"cmd\":\"%s\"}%s",$1,$2,$3,$4,cmd,(NR==6?"":",") }')

  cat <<EOF
{
  "timestamp": "${timestamp}",
  "cpu_load": "${cpu_load}",
  "memory": {
    "total_bytes": ${total:-null},
    "used_bytes": ${used:-null},
    "free_bytes": ${free_bytes:-null},
    "used_percent": ${mem_percent}
  },
  "disk_root": ${disk_raw},
  "top_cpu": [${top_cpu}],
  "top_mem": [${top_mem}]
}
EOF
}

# Main loop / execution
main() {
  MODE="text"
  while [[ "${#}" -gt 0 ]]; do
    case "$1" in
      --watch) INTERVAL="${2:-0}"; shift 2;;
      --json) MODE="json"; shift;;
      --help) usage; exit 0;;
      *) echo "Unknown arg: $1"; usage; exit 2;;
    esac
  done

  if [[ "$MODE" == "json" ]]; then
    if [[ "$INTERVAL" -gt 0 ]]; then
      while true; do
        collect_json
        sleep "$INTERVAL"
      done
    else
      collect_json
    fi
    return 0
  fi

  if [[ "$INTERVAL" -gt 0 ]]; then
    while true; do
      clear
      collect_text
      sleep "$INTERVAL"
    done
  else
    collect_text
  fi
}

# Check minimal dependencies
check_deps() {
  local miss=0
  command -v ps >/dev/null || { echo -e "${RED}ps not found${NC}"; miss=1; }
  command -v df >/dev/null || { echo -e "${RED}df not found${NC}"; miss=1; }
  command -v free >/dev/null || { echo -e "${RED}free not found${NC}"; miss=1; }
  command -v awk >/dev/null || { echo -e "${RED}awk not found${NC}"; miss=1; }
  # numfmt optional
  command -v numfmt >/dev/null || { echo -e "${YELLOW}numfmt not found; human-readable sizes may be unavailable${NC}"; }
  if [[ $miss -ne 0 ]]; then
    echo -e "${RED}Missing required utilities. Exiting.${NC}" >&2
    exit 3
  fi
}

check_deps
main "$@"
