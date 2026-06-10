# EnsoAI Session Benchmark: app-smoke-poll

- Generated: 2026-06-08T00:54:23.919Z
- CWD: `/Users/zlb/Code/2026code/EnsoAI`
- Command template: `codex 'exec' '--skip-git-repo-check' '--ephemeral' '--sandbox' 'read-only' '--color' 'never' '-C' '/Users/zlb/Code/2026code/EnsoAI' '--model' 'gpt-5.5' 'Reply with exactly BENCHMARK_OK and nothing else. Do not inspect files or run commands.'`
- Codex version: `codex-cli 0.137.0`
- Electron command: `/Users/zlb/Code/2026code/EnsoAI/node_modules/.bin/electron --remote-debugging-port=19317 .`
- Node version: `v22.22.3`
- Platform: `darwin 25.4.0`
- CPU: Apple M5 x 10
- Memory: 24576 MiB total, 817 MiB free at start

## Scope

This benchmark launches the built EnsoAI Electron app and creates real Codex agent sessions through `window.electronAPI.session.create/attach`. It covers EnsoAI main-process session management, preload IPC delivery, output batching, and process cleanup. It does not click through the React AgentPanel UI, so xterm/DOM mount cost should be interpreted from code changes and separate smoke checks.

## Summary

count | ok/failed | wall_ms | first_output_p50_ms | first_output_p95_ms | duration_p50_ms | duration_p95_ms | data_events | data_bytes | peak_tree_rss_mib | peak_tree_cpu_percent | max_pid_count
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
2 | 2/0 | 16424 | 1138 | 1405 | 15496 | 15931 | 18 | 1021 | 2684.5 | 538.3 | 64

## Failures

- none

## Raw Data

See `perf-app-smoke-poll.raw.json`.
