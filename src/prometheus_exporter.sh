#!/usr/bin/env bash
set -euo pipefail

# Simple Prometheus exporter using netcat (nc or ncat).
# Listens on a TCP port and returns metrics in Prometheus text format.
# Usage: ./prometheus_exporter.sh [PORT]
#
# Behavior:
# - Finds an available nc-like binary (ncat or nc).
# - On each connection, runs the metrics generator script (system_metrics.sh)
#   and returns an HTTP/1.1 response with Content-Type: text/plain; version=0.0.4.
# - For nc that supports -q, uses -q 1 to close after sending. For ncat, uses --sh-exec
#   to run a small inline handler. The exporter ignores the incoming HTTP request
#   payload and always returns the latest metrics snapshot.
#
# Requirements:
# - system_metrics.sh must be executable and located next to this script:
#     ./src/system_metrics.sh
# - netcat (nc) or ncat must be installed.
#
# Notes:
# - This script avoids trying to change behavior of the main metrics script;
#   it simply executes it and returns its stdout as the Prometheus payload.
# - Keep the implementation minimal and robust: no background daemons or PID files.

PORT="${1:-9100}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
METRICS_BIN="${SCRIPT_DIR}/system_metrics.sh"

# Find nc-like binary
find_nc() {
  for cmd in ncat nc; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "$cmd"
      return 0
    fi
  done
  return 1
}

NC_BIN="$(find_nc || true)"
if [[ -z "$NC_BIN" ]]; then
  echo "Error: netcat (nc) or ncat required" >&2
  exit 2
fi

# Generate metrics by executing the metrics script.
# We try a couple of invocations:
# 1) If the metrics script supports a mode to output Prometheus format directly,
#     prefer that. Common safe approach: set an env var PROMETHEUS=1 so the script
#     can detect it if implemented.
# 2) Fallback to running the script and using whatever it outputs.
generate_metrics() {
  if [[ ! -x "$METRICS_BIN" ]]; then
    echo ""
    return
  fi

  # Prefer explicit prometheus mode via environment (non-invasive).
  METS="$(
    PROMETHEUS=1 "$METRICS_BIN" 2>/dev/null || true
  )"

  if [[ -z "$METS" ]]; then
    METS="$("$METRICS_BIN" 2>/dev/null || true)"
  fi

  printf '%s' "$METS"
}

# Build HTTP response with proper headers and payload
send_http_response() {
  local payload="$1"
  printf 'HTTP/1.1 200 OK\r\n'
  printf 'Content-Type: text/plain; version=0.0.4\r\n'
  printf 'Connection: close\r\n'
  printf '\r\n'
  printf '%s' "$payload"
}

# Main loop: accept connections and serve generated metrics.
case "$(basename "$NC_BIN")" in
  ncat)
    # Use ncat --sh-exec to run a small handler on each connection.
    # The inline handler executes a bash snippet that runs the metrics generator
    # and writes an HTTP response to the socket.
    NC_PATH="$(command -v ncat)"
    while true; do
      (
        while IFS= read -r -t 0.1 line; do
          [[ -z "$line" ]] && break
        done 2>/dev/null || true

        METS="$(generate_metrics)"
        if [[ -z "$METS" ]]; then
          printf 'HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nfailed to generate metrics'
        else
          printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain; version=0.0.4\r\nConnection: close\r\n\r\n%s' "$METS"
        fi
      ) | "$NC_PATH" -l -p "$PORT" -q 1
    done
    ;;
  nc)
    # For traditional nc, run a loop: for each connection, pipe the HTTP response into nc.
    while true; do
      {
        METS="$(generate_metrics)"
        if [[ -z "$METS" ]]; then
          printf 'HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nfailed to generate metrics'
        else
          send_http_response "$METS"
        fi
      } | "$NC_BIN" -l -p "$PORT" -q 1
    done
    ;;
  *)
    echo "Unsupported nc binary: $NC_BIN" >&2
    exit 3
    ;;
esac
