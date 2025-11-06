#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-${EXPORTER_PORT:-9100}}"
HOST="${2:-0.0.0.0}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-5}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
METRICS_BIN="${SCRIPT_DIR}/system_metrics.sh"
CACHE_FILE="/tmp/metrics.prom"
ERR_FILE="/tmp/metrics.err"

# Ensure python3 present
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 required" >&2
  exit 2
fi

(
  while true; do
    PROMETHEUS=1 "$METRICS_BIN" > "$CACHE_FILE" 2> "$ERR_FILE" || true
    sleep "$REFRESH_INTERVAL"
  done
  ) &

# Small HTTP server in Python that invokes the metrics generator per request
exec python3 - <<PY
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

HOST = "${HOST}"
PORT = int("${PORT}")
CACHE = "${CACHE_FILE}"
ERRF = "${ERR_FILE}"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")
            return
        try:
            if not os.path.exists(CACHE):
                self.send_response(503)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"metrics not ready")
                return
            with open(CACHE, "rb") as f:
                body = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def log_message(self, format, *args):
        return

httpd = HTTPServer((HOST, PORT), Handler)
try:
    httpd.serve_forever()
except KeyboardInterrupt:
    pass
PY
