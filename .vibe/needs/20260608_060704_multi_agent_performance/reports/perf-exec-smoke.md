# Codex Agent Benchmark: exec-smoke

- Generated: 2026-06-07T23:48:06.323Z
- Mode: exec
- CWD: `/Users/zlb/Code/2026code/EnsoAI`
- Command template: `codex exec --skip-git-repo-check --ephemeral --sandbox read-only --color never -C /Users/zlb/Code/2026code/EnsoAI --model gpt-5.5 Reply with exactly BENCHMARK_OK and nothing else. Do not inspect files or run commands.`
- Codex version: `codex-cli 0.137.0`
- Node version: `v22.22.3`
- Platform: `darwin 25.4.0`
- CPU: Apple M5 x 10
- Memory: 24576 MiB total, 731 MiB free at start

## Scope

This report measures Codex CLI process/agent scale. EnsoAI app-level UI/IPC/xterm observations are separate and must be compared with the same label before claiming EnsoAI runtime speedup.

## EnsoAI App Observations

Not captured by this CLI script. Add EnsoAI app-level metrics or manual observations before using this report as EnsoAI speed evidence.

## Summary

count | ok/failed | wall_ms | first_output_p50_ms | first_output_p95_ms | duration_p50_ms | duration_p95_ms | avg_peak_rss_mib | max_peak_rss_mib | max_peak_cpu_percent
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
1 | 1/0 | 7195 | 83 | 83 | 7195 | 7195 | 41.8 | 41.8 | 0.2

## Failures

- none

## Raw Data

See `perf-exec-smoke.raw.json`.
