#!/usr/bin/env bash
# Main CLI: text / json output and ability to start Prometheus exporter (subcommand "exporter").

set -uo pipefail

# Force C locale for numeric computation (doesn't change user's LC_* outside script)
export LC_NUMERIC=C
export LANG=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
. "${ROOT_DIR}/helpers/cpu_metrics.sh"
. "${ROOT_DIR}/helpers/memory_metrics.sh"
. "${ROOT_DIR}/helpers/disk_metrics.sh"

CONFIG_FILE="${ROOT_DIR}/../configs/metrics_config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"
fi

: "${COLLECTION_INTERVAL:=0}"
: "${PROMETHEUS_PORT:=9100}"
: "${OUTPUT_FORMAT:=text}"
: "${TOP_PROCS_COUNT:=5}"

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

INTERVAL="${COLLECTION_INTERVAL}"

usage () {
  cat <<EOF
Usage: $0 [--watch seconds] [--json] [--exporter port] [--help]
  --watch seconds   Repeat collection every seconds (default: run once)
  --json            Output results in JSON (one-shot, ignores colors)
  --exporter port   Start Prometheus exporter on given port (default ${PROMETHEUS_PORT})
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

compute_max_cmd() {
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  local reserved=36 # space for columns
  local max=$((cols - reserved))
  if [[ $max -lt 20 ]]; then max=20; fi
  echo "$max"
}

print_top_procs_compact() {
  local sortfield="${1:-%cpu}" n=${2:-${TOP_PROCS_COUNT:-5}} maxcmd
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

collect_text() {
  local maxcmd
  maxcmd=$(compute_max_cmd)
  echo -e "${GREEN}=== System Metrics ===${NC}"
  echo -e "${BLUE}Timestamp:${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo -e "${BLUE}CPU Load (1,5,15):${NC} $(get_cpu_load)"
  echo -e "${BLUE}Memory:${NC} $(get_memory_usage_human)"
  echo -e "${BLUE}Disk (/) :${NC} $(get_disk_root_human)"
  echo -e "${BLUE}Top ${TOP_PROCS_COUNT} CPU processes:${NC}"
  print_top_procs_compact "%cpu" ${TOP_PROCS_COUNT} "$maxcmd" | sed 's/^/  /'
  echo -e "${BLUE}Top ${TOP_PROCS_COUNT} Memory processes:${NC}"
  print_top_procs_compact "%mem" ${TOP_PROCS_COUNT} "$maxcmd" | sed 's/^/  /'
}

collect_json () {
  read total used free_bytes <<<"$(read_memory_values)"
  mem_percent=$(LC_NUMERIC=C awk -v u="$used" -v t="$total" 'BEGIN{printf "%.2f", (t>0)?u*100/t:0}')
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cpu_load=$(get_cpu_load | sed 's/^ *//;s/"/\\"/g')
  disk_raw=$(get_disk_root_bytes || echo "0 0 0%")
  read disk_used disk_size disk_percent <<<"$disk_raw"
  top_cpu=$(ps aux --sort=-%cpu | head -n $((TOP_PROCS_COUNT + 1)) | awk 'NR>1{cmd=""; for(i=11;i<=NF;i++){cmd=cmd (i==11?"":" ") $i} gsub(/"/,"\\\"",cmd); printf "{\"user\":\"%s\",\"pid\":%s,\"pcpu\":%s,\"pmem\":%s,\"cmd\":\"%s\"}%s",$1,$2,$3,$4,cmd,(NR== (ENVIRON["TOP_N"]+1)?"":",") }' TOP_N="$TOP_PROCS_COUNT")
  top_mem=$(ps aux --sort=-%mem | head -n $((TOP_PROCS_COUNT + 1)) | awk 'NR>1{cmd=""; for(i=11;i<=NF;i++){cmd=cmd (i==11?"":" ") $i} gsub(/"/,"\\\"",cmd); printf "{\"user\":\"%s\",\"pid\":%s,\"pcpu\":%s,\"pmem\":%s,\"cmd\":\"%s\"}%s",$1,$2,$3,$4,cmd,(NR== (ENVIRON["TOP_N"]+1)?"":",") }' TOP_N="$TOP_PROCS_COUNT")

  cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "cpu_load": "${cpu_load}",
  "memory": {
    "total_bytes": ${total:-null},
    "used_bytes": ${used:-null},
    "free_bytes": ${free_bytes:-null},
    "used_percent": ${mem_percent}
  },
  "disk_root": {"used_bytes":${disk_used:-null}, "size_bytes":${disk_size:-null}, "used_percent":"${disk_percent:-null}"},
  "top_cpu": [${top_cpu}],
  "top_mem": [${top_mem}]
}
EOF
}

# Main loop / execution
main() {
  if [[ "${1:-}" == "exporter" ]]; then
    PORT="${2:-9100}"
    exec "${ROOT_DIR}/prometheus_exporter.sh" "$PORT"
  fi

  while [[ "${#}" -gt 0 ]]; do
    case "$1" in
      --watch) INTERVAL="${2:-0}"; shift 2;;
      --json) OUTPUT_FORMAT="json"; shift;;
      --exporter) PROMETHEUS_PORT="${2:-${PROMETHEUS_PORT:-9100}}"; exec "${ROOT_DIR}/prometheus_exporter.sh" "$PROMETHEUS_PORT";;
      --help) usage; exit 0;;
      *) echo "Unknown arg: $1"; usage; exit 2;;
    esac
  done

  if [[ "${OUTPUT_FORMAT}" == "json" ]]; then
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
