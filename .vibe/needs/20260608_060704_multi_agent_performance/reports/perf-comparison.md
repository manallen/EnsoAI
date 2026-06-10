# Performance Comparison: multi-agent-performance

## Scope

This comparison has two layers:

1. Codex CLI process/agent scale: measured by `scripts/perf/codex-agent-benchmark.mjs` with 10/20/30 concurrent `codex exec --model gpt-5.5` agents. This has baseline and after data, so percentage deltas are valid.
2. EnsoAI app session scale: measured by `scripts/perf/enso-session-benchmark.mjs` after instrumentation, launching the built Electron app and creating real Codex sessions through `window.electronAPI.session.create/attach`. This has after data only because the original app had no benchmark counters or CDP harness before this change, so no app-level speedup percentage is claimed.

The app benchmark covers main-process session management, preload IPC delivery, PTY output batching, benchmark counters, and cleanup. It does not click through AgentPanel UI, so xterm DOM mount reduction is supported by code/runtime smoke, not by a before/after UI interaction timing.

## Codex CLI Agent Scale

count | baseline ok/failed | after ok/failed | baseline wall_ms | after wall_ms | wall_delta | baseline first_output_p50_ms | after first_output_p50_ms | first_output_delta | baseline duration_p50_ms | after duration_p50_ms | duration_delta
--- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
10 | 10/0 | 10/0 | 31062 | 25559 | -17.7% | 273 | 119 | -56.4% | 27278 | 14695 | -46.1%
20 | 20/0 | 20/0 | 54375 | 39399 | -27.5% | 1580 | 182 | -88.5% | 46343 | 33148 | -28.5%
30 | 30/0 | 30/0 | 90529 | 56946 | -37.1% | 2733 | 573 | -79.0% | 52842 | 43828 | -17.1%

## EnsoAI App Session Scale

count | ok/failed | wall_ms | first_output_p50_ms | first_output_p95_ms | duration_p50_ms | duration_p95_ms | data_events | data_bytes | peak_tree_rss_mib | peak_tree_cpu_percent | max_pid_count
--- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---:
10 | 10/0 | 29666 | 2764 | 9567 | 26365 | 29321 | 111 | 9199 | 7087.3 | 772.5 | 187
20 | 20/0 | 103231 | 950 | 5738 | 37518 | 42816 | 214 | 14369 | 7419.8 | 729.4 | 246
30 | 30/0 | 99498 | 13531 | 24504 | 78668 | 85922 | 328 | 27497 | 9610.3 | 394.0 | 352

Notes:

- `wall_ms` includes serial session create/attach plus wait/cleanup; `duration_*` is measured per session after it is created.
- All app benchmark sessions completed and were cleaned up; post-run `sessionCounts` was zero for every group.
- The app run started with very low free memory (152 MiB reported at start), and 20/30 concurrent Codex runs emitted occasional Codex system-skill install race warnings, but exits were successful.

## EnsoAI Runtime Changes Backed By Code And Smoke

- Hidden/background terminals are no longer mounted globally; `AgentPanel` mounts current worktree active sessions, current worktree pending-command sessions, and a short prewarm set.
- Persistent local agent sessions now detach into buffering instead of destroying PTY, so on-demand unmount does not kill running Codex/Claude sessions.
- Renderer session events now use one event bus with one global `session.onData/onExit/onState` listener set, then dispatch by `sessionId`.
- Main-process PTY output now batches per session with a 16ms window and flushes before exit/dead state.
- Activity polling stops when `AgentTerminal` is inactive.
- Benchmark counters are available through `window.electronAPI.benchmark.snapshot/reset`.

## Conclusion

The measured CLI layer shows same-machine 10/20/30 Codex process runs were faster in the after run, with wall time improving 17.7% / 27.5% / 37.1%. The EnsoAI app layer now has real 10/20/30 session evidence with zero failures, but because there was no pre-change app baseline, the product-level speedup is reported as structural plus after-capacity verified rather than a quantified app percentage.
