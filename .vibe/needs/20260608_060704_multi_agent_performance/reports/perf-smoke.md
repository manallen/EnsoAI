# Codex Agent Benchmark: smoke

- Generated: 2026-06-07T23:47:30.045Z
- Mode: version
- CWD: `/Users/zlb/Code/2026code/EnsoAI`
- Command template: `codex --version`
- Codex version: `codex-cli 0.137.0`
- Node version: `v22.22.3`
- Platform: `darwin 25.4.0`
- CPU: Apple M5 x 10
- Memory: 24576 MiB total, 236 MiB free at start

## Scope

This report measures Codex CLI process/agent scale. EnsoAI app-level UI/IPC/xterm observations are separate and must be compared with the same label before claiming EnsoAI runtime speedup.

## EnsoAI App Observations

Not captured by this CLI script. Add EnsoAI app-level metrics or manual observations before using this report as EnsoAI speed evidence.

## Summary

count | ok/failed | wall_ms | first_output_p50_ms | first_output_p95_ms | duration_p50_ms | duration_p95_ms | avg_peak_rss_mib | max_peak_rss_mib | max_peak_cpu_percent
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
1 | 1/0 | 59 | 56 | 56 | 59 | 59 | 0 | 0 | 0

## Failures

- none

## Raw Data

See `perf-smoke.raw.json`.
