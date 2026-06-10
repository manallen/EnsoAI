# Test Report: multi-agent-performance

## Result

READY with documented residual risks.

## Requirement Coverage

| Requirement | Evidence | Status |
|-------------|----------|--------|
| 多 Agent 并行、worktree session 和切换恢复体验 | Persistent local detach buffers instead of destroying PTY; `AgentPanel` mounts active/pending/prewarm sessions only; `useXterm` attaches by backend session and replays output. | Pass |
| 隐藏/切换不得误杀后端 PTY | `SessionManager.detach` uses `getLocalDetachDecision`; persistent sessions enter `buffering`; stale `useXterm` init calls `detach`, not `kill`. | Pass |
| replay/live 输出按 session 保序，不跨 session | `SessionOutputBatcher` isolates sessions, flushes before exit/dead; detach flushes pending output before removing window attachment. | Pass |
| 输入/resize/focus 只作用于当前可见 session | `AgentPanel` computes `isTerminalActive` from active panel, current worktree, visible session, and active group. | Pass |
| 保持 Electron + React + node-pty + xterm | No stack migration. | Pass |
| 不使用 `as any` / `@ts-ignore` | Changed code avoids type escapes. | Pass |
| 可重复性能验证 | `codex-agent-benchmark.mjs` and `enso-session-benchmark.mjs`; raw JSON and markdown reports saved. | Pass |

## Commands Run

- `pnpm test -- src/main/services/session/__tests__/sessionOutputBatcher.test.ts src/main/services/session/__tests__/sessionLifecycle.test.ts src/renderer/lib/__tests__/sessionEventBus.test.ts`
  - Passed: 5 files, 50 tests.
- `pnpm typecheck`
  - Passed.
- Targeted Biome check for changed review files and perf scripts
  - Passed with existing `fit()` false-positive warnings in `useXterm`; command exit code was 0.
- Earlier full validation during T8:
  - `pnpm test`: passed, 49 tests before the additional batcher test.
  - `pnpm typecheck`: passed.
  - `pnpm build`: passed.
  - Electron preview startup smoke passed after repairing local native artifacts.

## Performance Evidence

### Codex CLI baseline vs after

count | baseline wall_ms | after wall_ms | wall_delta | baseline duration_p50_ms | after duration_p50_ms | duration_delta | failures
--- | ---: | ---: | ---: | ---: | ---: | ---: | ---:
10 | 31062 | 25559 | -17.7% | 27278 | 14695 | -46.1% | 0 / 0
20 | 54375 | 39399 | -27.5% | 46343 | 33148 | -28.5% | 0 / 0
30 | 90529 | 56946 | -37.1% | 52842 | 43828 | -17.1% | 0 / 0

### EnsoAI built-app session benchmark after optimization

count | ok/failed | wall_ms | first_output_p50_ms | duration_p50_ms | data_events | post-run sessions
--- | --- | ---: | ---: | ---: | ---: | ---:
10 | 10/0 | 29666 | 2764 | 26365 | 111 | 0
20 | 20/0 | 103231 | 950 | 37518 | 214 | 0
30 | 30/0 | 99498 | 13531 | 78668 | 328 | 0

App benchmark scope: built Electron app, real Codex sessions through `window.electronAPI.session.create/attach`, main-process session management, preload IPC delivery, PTY output batching, benchmark counters, and cleanup. It does not click through AgentPanel UI, so app-level UI timing is not claimed.

## Review

- `reports/review-latest.md`: no Critical/Major blockers remain.
- Fixed during review:
  - Detach now flushes pending output before removing window attachment.
  - Delayed xterm flush no longer writes into a disposed/remounted terminal.
  - Removed duplicate old app benchmark script.

## Known Limitations

- Full `pnpm lint` remains blocked by existing/out-of-scope repository diagnostics documented in `reports/verification.md`.
- EnsoAI app-session benchmark has after data only; the original code had no app benchmark counters/CDP harness, so app-level before/after percentage is not claimed.
- The 10/20/30 app benchmark caused heavy memory pressure during execution. It completed and cleaned up; no high-memory benchmark residual processes remained when checked afterward. Do not rerun it casually on a busy machine.

## Reality Check

- All MUST constraints from `requirements.md` have direct code or test evidence.
- Performance comparison includes real 10/20/30 Codex data.
- Remaining gaps are documented and do not block this requirement's implementation scope.
