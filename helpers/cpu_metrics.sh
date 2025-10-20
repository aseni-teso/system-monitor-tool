#!/usr/bin/env bash
# CPU metric helpers

set -uo pipefail

get_cpu_load() {
  uptime | awk -F'load average:' '{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}'
}
