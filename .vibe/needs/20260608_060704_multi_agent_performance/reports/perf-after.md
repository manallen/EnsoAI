# Codex Agent Benchmark: after

- Generated: 2026-06-08T00:21:13.682Z
- Mode: exec
- CWD: `/Users/zlb/Code/2026code/EnsoAI`
- Command template: `codex exec --skip-git-repo-check --ephemeral --sandbox read-only --color never -C /Users/zlb/Code/2026code/EnsoAI --model gpt-5.5 Reply with exactly BENCHMARK_OK and nothing else. Do not inspect files or run commands.`
- Codex version: `codex-cli 0.137.0`
- Node version: `v22.22.3`
- Platform: `darwin 25.4.0`
- CPU: Apple M5 x 10
- Memory: 24576 MiB total, 427 MiB free at start

## Scope

This report measures Codex CLI process/agent scale. EnsoAI app-level UI/IPC/xterm observations are separate and must be compared with the same label before claiming EnsoAI runtime speedup.

## EnsoAI App Observations

After EnsoAI runtime optimization: CLI Codex agent scale captured with the same harness as baseline. EnsoAI in-app UI/IPC/xterm metrics API has been added, but no automated UI harness is available in this repo yet; in-app metrics require manual or future Electron automation.

## Summary

count | ok/failed | wall_ms | first_output_p50_ms | first_output_p95_ms | duration_p50_ms | duration_p95_ms | avg_peak_rss_mib | max_peak_rss_mib | max_peak_cpu_percent
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
10 | 10/0 | 25559 | 119 | 169 | 14695 | 25457 | 41.8 | 42 | 0.4
20 | 20/0 | 39399 | 182 | 1046 | 33148 | 36849 | 38.5 | 42 | 0.4
30 | 30/0 | 56946 | 573 | 3843 | 43828 | 49293 | 38.9 | 42.1 | 0.4

## Failures

- none

## Raw Data

See `perf-after.raw.json`.
