# Codex Agent Benchmark: baseline

- Generated: 2026-06-07T23:48:41.739Z
- Mode: exec
- CWD: `/Users/zlb/Code/2026code/EnsoAI`
- Command template: `codex exec --skip-git-repo-check --ephemeral --sandbox read-only --color never -C /Users/zlb/Code/2026code/EnsoAI --model gpt-5.5 Reply with exactly BENCHMARK_OK and nothing else. Do not inspect files or run commands.`
- Codex version: `codex-cli 0.137.0`
- Node version: `v22.22.3`
- Platform: `darwin 25.4.0`
- CPU: Apple M5 x 10
- Memory: 24576 MiB total, 802 MiB free at start

## Scope

This report measures Codex CLI process/agent scale. EnsoAI app-level UI/IPC/xterm observations are separate and must be compared with the same label before claiming EnsoAI runtime speedup.

## EnsoAI App Observations

Baseline before EnsoAI runtime optimization: no existing app-level Electron/UI metrics harness is available. CLI Codex agent scale is captured here; EnsoAI in-app UI/IPC/xterm baseline remains a blocker until benchmark metrics instrumentation exists.

## Summary

count | ok/failed | wall_ms | first_output_p50_ms | first_output_p95_ms | duration_p50_ms | duration_p95_ms | avg_peak_rss_mib | max_peak_rss_mib | max_peak_cpu_percent
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
10 | 10/0 | 31062 | 273 | 1517 | 27278 | 30402 | 39.1 | 41.9 | 0.6
20 | 20/0 | 54375 | 1580 | 4075 | 46343 | 51740 | 41.5 | 42.1 | 0.9
30 | 30/0 | 90529 | 2733 | 9014 | 52842 | 65852 | 40.1 | 42.1 | 0.9

## Failures

- none

## Raw Data

See `perf-baseline.raw.json`.
