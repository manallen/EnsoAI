# Code Review: multi-agent-performance

## Scope

- Reviewed current working tree changes for requirement `multi-agent-performance`.
- Primary files reviewed: `SessionManager`, session lifecycle/batcher helpers, renderer session event bus, `useXterm`, `AgentPanel`, `AgentTerminal`, benchmark metrics IPC, and performance scripts.

## Findings

### Critical

- None.

### Major

- None remaining.

### Fixed During Review

- `SessionManager.detach` now flushes pending output batch before removing the window attachment. Without this, a fast hide/switch/re-attach inside the 16ms batch window could replay the same buffered bytes and then flush the old pending batch, producing duplicate terminal output.
- `useXterm` delayed write flush now checks that the captured terminal is still current before writing. This avoids writing into a disposed xterm instance after unmount or remount races.
- Removed duplicate old benchmark script `scripts/perf/enso-app-session-benchmark.mjs`; `scripts/perf/enso-session-benchmark.mjs` is the maintained app-session benchmark used by reports.

## Requirements Compliance

- Keeps Electron + React + node-pty + xterm stack.
- Keeps hidden/switched agent sessions alive by using persistent detach buffering instead of PTY destroy.
- Reduces renderer amplification through single session event bus and AgentTerminal on-demand mounting.
- Reduces IPC amplification through per-session output batching and exit/dead flush.
- Reduces background activity polling by stopping `getActivity` polling for inactive terminals.
- Provides repeatable benchmark scripts and captured 10/20/30 Codex evidence.

## Evidence Checked

- `pnpm test -- src/main/services/session/__tests__/sessionOutputBatcher.test.ts src/main/services/session/__tests__/sessionLifecycle.test.ts src/renderer/lib/__tests__/sessionEventBus.test.ts`: passed, 50 tests.
- `pnpm typecheck`: passed.
- Targeted Biome check for changed review files and perf scripts: passed with known `fit()` false-positive warnings in `useXterm`; exit code was 0.
- Performance reports exist for CLI baseline/after and EnsoAI app-session after benchmark.

## Residual Risk

- Full `pnpm lint` still has existing/out-of-scope repository diagnostics documented in `verification.md`.
- EnsoAI app-session benchmark has after data only. The original code did not have app benchmark counters/CDP harness, so app-level before/after percentage is intentionally not claimed.
- The app-session benchmark drives preload session APIs directly; it does not click through AgentPanel UI. AgentPanel/xterm reduction is verified through code review, typecheck, smoke, and session cleanup evidence.

## Verdict

No blocking review issues remain for this requirement. Continue to `vibe test` closeout.

---

## Re-Review: Agent Batch Create Menu Fix

### Scope

- Reviewed the follow-up fix for adding a default `3` batch count to Agent selection menus.
- Files reviewed:
  - `src/renderer/components/chat/AgentCreateCountInput.tsx`
  - `src/renderer/components/chat/AgentPanel.tsx`
  - `src/renderer/components/chat/AgentGroup.tsx`
  - `src/renderer/components/chat/SessionBar.tsx`

### Findings

#### Critical

- None.

#### Major

- None remaining.

### Fixed During Re-Review

- The prior Major finding is fixed: the screenshot-relevant `SessionBar` top `+` Agent menu now renders the batch count control and passes `count` through `onNewSessionWithAgent`.
- `AgentGroup` empty-group Agent menu now uses the same batch count control and passes `count`.
- `AgentPanel` empty-state Agent menu now uses the shared `AgentCreateCountInput` instead of duplicate local input markup.
- `handleNewSessionWithAgent` remains the single creation path and clamps count before creating sessions.

### Requirements Compliance

- Default count is `3`.
- Agent menu count is shared across empty panel, empty group, and existing-session `SessionBar` menus.
- Normal direct `New Session` button still creates one session.
- Batch creation activates the last created session in the target group.
- Count is clamped to `1..30`.

### Evidence Checked

- `pnpm typecheck`: passed.
- `pnpm exec biome check src/renderer/components/chat/AgentCreateCountInput.tsx src/renderer/components/chat/AgentPanel.tsx src/renderer/components/chat/AgentGroup.tsx src/renderer/components/chat/SessionBar.tsx`: passed.
- `pnpm test -- src/main/services/session/__tests__/sessionOutputBatcher.test.ts src/main/services/session/__tests__/sessionLifecycle.test.ts src/renderer/lib/__tests__/sessionEventBus.test.ts`: passed, 50 tests.
- Source review confirmed `AgentPanel -> AgentGroup -> SessionBar -> handleNewSessionWithAgent` forwards the optional `count` argument.

### Residual Risk

- UI was not launched in Electron during this re-review to avoid adding node load after the reported freeze. The behavior was verified through typecheck, targeted Biome, tests, and source trace.

### Verdict

No blocking review issues remain after the Agent batch-create menu fix.
