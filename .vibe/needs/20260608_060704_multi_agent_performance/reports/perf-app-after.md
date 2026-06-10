# EnsoAI Session Benchmark: app-after

- Generated: 2026-06-08T00:54:57.615Z
- CWD: `/Users/zlb/Code/2026code/EnsoAI`
- Command template: `codex 'exec' '--skip-git-repo-check' '--ephemeral' '--sandbox' 'read-only' '--color' 'never' '-C' '/Users/zlb/Code/2026code/EnsoAI' '--model' 'gpt-5.5' 'Reply with exactly BENCHMARK_OK and nothing else. Do not inspect files or run commands.'`
- Codex version: `codex-cli 0.137.0`
- Electron command: `/Users/zlb/Code/2026code/EnsoAI/node_modules/.bin/electron --remote-debugging-port=19317 .`
- Node version: `v22.22.3`
- Platform: `darwin 25.4.0`
- CPU: Apple M5 x 10
- Memory: 24576 MiB total, 152 MiB free at start

## Scope

This benchmark launches the built EnsoAI Electron app and creates real Codex agent sessions through `window.electronAPI.session.create/attach`. It covers EnsoAI main-process session management, preload IPC delivery, output batching, and process cleanup. It does not click through the React AgentPanel UI, so xterm/DOM mount cost should be interpreted from code changes and separate smoke checks.

## Summary

count | ok/failed | wall_ms | first_output_p50_ms | first_output_p95_ms | duration_p50_ms | duration_p95_ms | data_events | data_bytes | peak_tree_rss_mib | peak_tree_cpu_percent | max_pid_count
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
10 | 10/0 | 29666 | 2764 | 9567 | 26365 | 29321 | 111 | 9199 | 7087.3 | 772.5 | 187
20 | 20/0 | 103231 | 950 | 5738 | 37518 | 42816 | 214 | 14369 | 7419.8 | 729.4 | 246
30 | 30/0 | 99498 | 13531 | 24504 | 78668 | 85922 | 328 | 27497 | 9610.3 | 394 | 352

## Failures

- none

## Raw Data

See `perf-app-after.raw.json`.
