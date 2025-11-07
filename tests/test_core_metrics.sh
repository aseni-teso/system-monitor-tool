#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" >/dev/null 2>&1 && pwd)"
HELPERS_DIR="$ROOT_DIR/helpers"
SRC_DIR="$ROOT_DIR/src"

source "$HELPERS_DIR/cpu_metrics.sh"
source "$HELPERS_DIR/memory_metrics.sh"
source "$HELPERS_DIR/disk_metrics.sh"

is_number() {
  awk 'BEGIN{exit(!(ARGV[1] ~ /^[0-9]+(\.[0-9]+)?$/))}' "$1" 2>/dev/null
}

check_in_range() {
  local val="$1" min="$2" max="$3"
  printf '%s\n' "$val" | awk -v min="$min" -v max="$max" '{ v=$1+0; exit(!(v>=min && v<=max)) }'
}

test_helpers_executables() {
  for f in "$HELPERS_DIR"/*.sh "$SRC_DIR"/*.sh; do
    [[ -f "$f" ]] || continue
    [[ -x "$f" ]] || { echo "✗ $f is not executable"; exit 1; }
  done
  echo "✓ helper and src scripts are executable"
}

test_cpu_metric() {
  local cpu
  cpu="$(get_cpu_usage 2>/dev/null || echo "NA")"
  if ! is_number "$cpu"; then
    echo "✗ cpu is not numeric: '$cpu'"
    exit 100
  fi
  check_in_range "$cpu" 0 100 || { echo "✗ cpu out of range: $cpu"; exit 1; }
  echo "✓ cpu is numeric between 0 and 100 (value: $cpu)"
}

test_memory_metric() {
  local total used free
  read total used free <<<"$(read_memory_values 2>/dev/null || echo "NA NA NA")"
  if ! is_number "$total"; then echo "✗ memory total not numeric: $total"; exit 1; fi
  if ! is_number "$used"; then echo "✗ memory used not numeric: $used"; exit 1; fi
  if ! is_number "$free"; then echo "✗ memory free not numeric: $free"; exit 1; fi
  awk -v u="$used" -v t="$total" 'BEGIN{exit(!(u+0<=t+0))}' || { echo "✗ memory used > total"; exit 1; }
  echo "✓ memory metrics OK (total:$total used:$used free:$free)"
}

test_disk_metrics() {
  local used size perc
  read used size perc <<<"$(get_disk_root_bytes 2>/dev/null || echo "NA NA NA")"
  if ! is_number "$used"; then echo "✗ disk used not numeric: $used"; exit 1; fi
  if ! is_number "$size"; then echo "✗ disk size not numeric: $size"; exit 1; fi
  perc="${perc%\%}"
  if ! is_number "$perc"; then echo "✗ disk percent not numeric: $perc"; exit 1; fi
  awk -v p="$perc" 'BEGIN{exit(!(p>=0 && p<=100))}' || { echo "✗ disk percent out of range: $perc"; exit 1; }
  echo "✓ disk metrics OK (used:$used size:$size percent:${perc}%)"
}

main() {
  echo "Running core metrics tests..."
  test_helpers_executables
  test_cpu_metric
  test_memory_metric
  test_disk_metrics
  echo "All core metrics test passed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
