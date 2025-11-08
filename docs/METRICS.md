# System Metrics Documentation

This document describes available metrics, output formats, configuration options, examples nad troubleshooting for the system metrics collector found in src/system_metrics.sh.

## Available metrics

### CPU
- **system_cpu_usage_percent** - Total CPU usage percentage (gauge)
- **cpu_load** (text/json) - system load averages (1, 5, 15)

### Memory
- **system_memory_bytes_total** - Total RAM in bytes (gauge)
- **system_memory_bytes_used** - Used RAM in bytes (gauge)
- **system_memory_bytes_free** - Free RAM in bytes (gauge)
- **system_memory_usage_percent** - Memory usage percent (gauge)

### Disk (root /)
- **system_disk_root_bytes_total** - Total bytes for root (/) partition (gauge)
- **system_disk_root_bytes_used** - Used bytes for root (/) partition (gauge)
- **system_disk_root_usage_percent** - Root partition usage percent (gauge)

### Processes (text/json)
- top processes by CPU and by memory:
    - fields: userm pid, pcpu (percent), pmem (percent), cmd (truncated command)

## Metric names and Prometheus exposition

When run in Prometheus mode, the exporter outputs the following metrics with HELP and TYPE headers:

- system_cpu_usage_percent (gauge)
- system_memory_bytes_total (gauge)
- system_memory_bytes_used (gauge)
- system_memory_bytes_free (gauge)
- system_memory_usage_percent (gauge)
- system_disk_root_bytes_total (gauge)
- system_disk_root_bytes_used (gauge)
- system_disk_root_usage_percent (gauge)

Example Prometheus output:

```
# HELP system_cpu_usage_percent System CPU usage percent
# TYPE system_cpu_usage_percent gauge
system_cpu_usage_percent 12.34

# HELP system_memory_bytes_total
# TYPE system_memory_bytes_total gauge
system_memory_bytes_total 16777216
# HELP system_memory_bytes_used
# TYPE system_memory_bytes_used gauge
system_memory_bytes_used 8388608
# HELP system_memory_bytes_free
# TYPE system_memory_bytes_free gauge
system_memory_bytes_free 8388608
# HELP system_memory_usage_percent
# TYPE system_memory_usage_percent gauge
system_memory_usage_percent 50.00

# HELP system_disk_root_bytes_total
# TYPE system_disk_root_bytes_total gauge
system_disk_root_bytes_total 536870912
# HELP system_disk_root_bytes_used
# TYPE system_disk_root_bytes_used gauge
system_disk_root_bytes_used 268435456
# HELP system_disk_root_usage_percent
# TYPE system_disk_root_usage_percent gauge
system_disk_root_usage_percent 50
```

## JSON output schema

One-shot JSON produced by `--json` or collect_json():

```
{
  "timestamp": "2025-11-07T12:34:56Z",
  "cpu_load": "0.12 0.34 0.56",
  "memory": {
    "total_bytes": 16777216,
    "used_bytes": 8388608,
    "free_bytes": 8388608,
    "used_percent": 50.00
  },
  "disk_root": {
    "used_bytes": 268435456,
    "size_bytes": 536870912,
    "used_percent": "50%"
  },
  "top_cpu": [
    {"user":"root","pid":123,"pcpu":12.3,"pmem":1.2,"cmd":"mydaemon --flag"},
    ...
  ],
  "top_mem": [
    {"user":"app","pid":456,"pcpu":0.5,"pmem":20.0,"cmd":"java -Xmx..."},
    ...
  ]
}
```

Notes:
- Numeric fields are integers or floats where appropriate.
- top_cpu / top_mem arrays length = TOP_PROCS_COUNT (default 5)

## CLI usage

Usage: `./src/system_metrics.sh [--watch seconds] [--json] [--exporter port] [--help]`

- `--watch seconds`
    - Repeat collection every N seconds (default: run once)
- `--json`
    - Output results in JSON (one-shot or repeated if --watch is used)
- `--exporter port`
    - Start Prometheus exporter on given port (runs src/prometheus_exporter.sh)
- exporter (subcommand)
    - `./src/system_metrics.sh exporter [9100]` run the bundled exporter script on port 9100

Environment variables / config options (can be set in configs/metrics_config.conf or via environment in Docker):

- `COLLECTION_INTERVAL` (default 0) - interval in seconds for periodic collection (overriden by --watch)
- `PROMETHEUS_PORT` / `EXPORTER_PORT` (default 9100) - port for exporter
- `OUTPUT_FORMAT` (text, json, prometheus) - choose output format
- `TOP_PROCS_COUNT` (default 5) - number of top processes to show
- `REFRESH_INTERVAL` (used in Docker imahe as example, not required by script)

## Examples

Local one-shot (text, default):
`./src/system_metrics.sh`

JSON one-shot:
`./src/system_metrics.sh --json`

JSON repeated every 10s:
`./src/system_metrics.sh --json --watch 10`

Start Prometheus exporter on default port (9100) using the CLI flag:
`./src/system_metrics.sh --exporter 9100`

Start exporter subcommand (execs prometheus_exporter.sh):
`./src/system_metrics.sh exporter 9100` OR `./src/system_metrics.sh exporter`

Docker run (example):
```
docker build -t system-monitor .
docker run -p 9100:9100 -e OUTPUT_FORMAT=prometheus -e EXPORTER_PORT=9100 system-monitor
```

`docker-compose example` (compose should expose port 9100 and set envs accordingly).

## Configuration file (configs/metrics_config.conf)

The collector will source configs/metrics_config.conf if present. Supported keys (shell variables):

- `COLLECTION_INTERVAL=0`
- `PROMETHEUS_PORT=9100`
- `OUTPUT_FORMAT=text|json|prometheus`
- `TOP_PROCS_COUNT=5`

Example configs/metrics_config.conf:
`COLLECTION_INTERVAL=5`
`OUTPUT_FORMAT=text`
`TOP_PROCS_COUNT=10`

Notes:
- The script sets defaults if variables are not found.
- Command-line flags take precedence over config file variables.

## Dependecies

The script checks for minimal utilities at startup. Required:
- `ps`
- `df`
- `free`
- `awk`

Optional (recommended):
- `numfmt` (for nicer human-readable sizes)
- `tput` (for computing terminal width; fallbacks exist)

If required utilities are missing, the script exits wth code 3 and prints which commands are missing.

## Files of interest and responsibilities

- `helpers/cpu_metrics.sh` - functions used by main script to compute CPU values (expected function: get_cpu_usage, get_cpu_load)
- `helpers/memory_metrics.sh` - expected functions: read_memory_values, get_memory_usage_human
- `helpers/disk_metrics.sh` - expected functions: get_disk_root_bytes, get_disk_root_human
- `src/system_metrics.sh` - CLI, formatting and metrics collector (main script)
- `src/prometheus_exporter.sh` - HTTP exporter that serves Prometheus-formatted metrics
- `configs/metrics_config.conf` - optional configuration file
- `Dockerfile` / `docker-compose.yml` - containerization examples

If helper scripts deviate from the expected function names/return formats, adjust this document accordingly.

## Troubleshooting

- Missing utilities: ensure ps, df, free, awk are installed.
- Non-numeric or empty values from helper functions: Prometheus output falls back to 0 for invalid numeric values. Fix the helper output formatm(should be plain numbers for byte counts and percent values).
- Incorrect JSON: ensure top process extraction in helpers or OS ps output matches expected columns (ps variations across platforms can break JSON construction).
- Prometheus exporter fails to bindL check EXPORTER_PORT/PROMETHEUS_PORT env and container port mapping.

## Testing

Run included basic test (shell-based):
`./tests/test_core_metrics.sh`

Expectations:
- test script validates that core functions return numeric outputs and JSON/Prometheus output contains required metric names.

## Maintainability notes (for implementers)

- All numeric calculations force C local (LC_NUMERIC=C) to avoid locale-specific decimal separators.
- The script uses defensive parsing: helpers stderr suppressed and falls to zero on parse failures.
- When adding new metrics, keep naming consistent with Prometheus conventions: `<subsystem>_<metric>_<unit>` ann add HELP/TYPE blocks in output_prometheus().

- Missing utilities: ensure ps, df, free, awk are installed.
- Non-numeric or empty values from helper functions: Prometheus output falls back to 0 for invalid numeric values. Fix the helper output formatm(should be plain numbers for byte counts and percent values).
- Incorrect JSON: ensure top process extraction in helpers or OS ps output matches expected columns (ps variations across platforms can break JSON construction).
- Prometheus exporter fails to bindL check EXPORTER_PORT/PROMETHEUS_PORT env and container port mapping.

## Testing

Run included basic test (shell-based):
`./tests/test_core_metrics.sh`

Expectations:
- test script validates that core functions return numeric outputs and JSON/Prometheus output contains required metric names.

## Maintainability notes (for implementers)

- All numeric calculations force C local (`LC_NUMERIC=C`) to avoid locale-specific decimal separators.
- The script uses defensive parsing: helpers stderr suppressed and falls to zero on parse failures.
- When adding new metrics, keep naming consistent with Prometheus conventions: `<subsystem>_<metric>_<unit>` ann add HELP/TYPE blocks in output_prometheus().
I
