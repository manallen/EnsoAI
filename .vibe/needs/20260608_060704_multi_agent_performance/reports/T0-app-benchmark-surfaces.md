# T0 App Benchmark Surfaces

## Scope

- Goal: inspect whether EnsoAI already has Electron/UI automation, debug metrics, and IPC/terminal counting surfaces usable for 10/20/30 Codex session in-app benchmark.
- Constraints followed: read-only source inspection, no binary reads, `rg` first for narrowing, no source edits. This report is the only written file.

## Findings

### 1. Electron/UI Automation

Current status: no reusable Electron UI automation entry found.

Evidence:

- `package.json`
  - Scripts: `dev`, `build`, platform builds, `test`, `test:watch`, `typecheck`, `lint`.
  - Test script is `vitest run`.
  - No `playwright`, `e2e`, `electron`, or benchmark script.
- `vitest.config.ts`
  - Node-only Vitest config: `environment: 'node'`, include `src/**/__tests__/**/*.test.ts`.
- `pnpm-lock.yaml`
  - No `@playwright/test`, Playwright Electron `_electron`, Spectron, WebDriver, or Electron e2e dependency found.
- Existing tests are unit-style:
  - `src/main/services/git/__tests__/gitLogFormat.test.ts`
  - `src/renderer/components/files/__tests__/javaFolding.test.ts`

Candidate startup surface:

- `scripts/dev.js`
  - Wraps `electron-vite dev`.
  - Handles process-tree cleanup on SIGINT/SIGTERM.
  - Usable as the manual/dev startup path for a benchmark harness, but not itself an automation harness.

Recommendation:

- Add a separate Electron automation harness if real in-app benchmark needs app orchestration.
- Minimal candidate: Playwright with Electron launch against built output or `electron-vite` dev process.
- Keep benchmark scripts separate from normal `pnpm test`, e.g. `benchmark:app` or `e2e:benchmark`.

### 2. Web Inspector / Debug Hooks

Current status: there is an app debug/inspection server, but it is DOM-inspection oriented rather than performance-metrics oriented.

Candidate files:

- `src/main/services/webInspector/WebInspectorServer.ts`
  - Starts local HTTP server on `127.0.0.1:18765`.
  - Accepts `POST /inspect`.
  - Forwards parsed `InspectPayload` to renderer via `web-inspector:data`.
  - Exposes status `{ running, port }`.
- `src/main/ipc/webInspector.ts`
  - IPC handlers: `web-inspector:start`, `web-inspector:stop`, `web-inspector:status`.
- `src/preload/index.ts`
  - Exposes `window.electronAPI.webInspector.start/stop/status/onStatusChange/onData`.
- `src/shared/types/webInspector.ts`
  - `InspectPayload` contains element, path, attributes, styles, position, innerText, url, timestamp, optional component source.
- `src/main/index.ts`
  - Calls `webInspectorServer.setMainWindow(mainWindow)`.
  - Updates target window on `browser-window-focus`.
- `src/renderer/components/settings/WebInspectorSettings.tsx`
  - UI toggle/status for Web Inspector.
  - Points users to `scripts/web-inspector.user.js`.

Benchmark relevance:

- Useful for app-internal debug plumbing and proof that renderer-to-main debug events can be forwarded.
- Not enough for benchmark metrics because it does not expose app resource usage, session counts, IPC counters, terminal throughput, latency, memory, or CPU samples.

Recommendation:

- Do not overload Web Inspector for benchmark metrics unless the benchmark is browser/DOM inspection related.
- Prefer a new narrow benchmark/debug IPC namespace that returns structured metrics snapshots.

### 3. Session / Terminal IPC Surfaces

Current status: strong existing session and terminal lifecycle IPC exists. It can create/list/kill sessions and stream terminal data. It does not expose aggregate counters or metrics snapshots.

Candidate files:

- `src/shared/types/ipc.ts`
  - Session IPC channels:
    - `session:create`
    - `session:attach`
    - `session:detach`
    - `session:kill`
    - `session:write`
    - `session:resize`
    - `session:list`
    - `session:getActivity`
    - `session:data`
    - `session:exit`
    - `session:state`
  - Legacy terminal wrappers:
    - `terminal:create`
    - `terminal:write`
    - `terminal:resize`
    - `terminal:destroy`
    - `terminal:getActivity`
- `src/main/ipc/session.ts`
  - Registers all session IPC handlers.
  - Legacy terminal handlers delegate to `SessionManager`.
- `src/main/ipc/terminal.ts`
  - Re-exports `registerSessionHandlers` as `registerTerminalHandlers`.
- `src/preload/index.ts`
  - Exposes `window.electronAPI.session.*`.
  - Exposes legacy `window.electronAPI.terminal.*`.
  - Provides `onData`, `onExit`, and `onState` subscriptions.
- `src/shared/types/session.ts`
  - `SessionDescriptor` includes `sessionId`, `backend`, `kind`, `cwd`, `persistOnDisconnect`, `createdAt`, `metadata`.
- `src/shared/types/terminal.ts`
  - Terminal create/resize types.

Benchmark relevance:

- A benchmark harness can already drive local Codex-like terminal sessions through:
  - `window.electronAPI.session.create({ cwd, kind: 'agent' | 'terminal', initialCommand })`
  - `window.electronAPI.session.write(sessionId, data)`
  - `window.electronAPI.session.list()`
  - `window.electronAPI.session.getActivity(sessionId)`
  - `window.electronAPI.session.onData(...)`
  - `window.electronAPI.session.onExit(...)`
- This is enough to count sessions from the renderer side, but only from attached sessions visible to that window.
- It is not enough to measure all internal counters accurately without adding instrumentation.

### 4. PTY / Activity Existing Capability

Current status: PTY process activity detection exists, but it is boolean and cached.

Candidate files:

- `src/main/services/terminal/PtyManager.ts`
  - Uses `node-pty`.
  - Tracks local PTY sessions in a private `sessions` map.
  - `allocateId()` returns `pty-N`.
  - `getProcessActivity(id)`:
    - Uses `pidtree(pid, { root: true })`.
    - Uses `pidusage(pids)`.
    - Returns `true` if any process in tree has CPU > 3%.
    - Caches result for 2 seconds.
- `src/main/services/session/SessionManager.ts`
  - Owns `localPtyManager`.
  - Tracks sessions in a private `sessions` map.
  - Maintains `replayBuffer` up to 65,536 chars.
  - Emits `session:data`, `session:exit`, `session:state` to attached windows.

Benchmark relevance:

- Existing `getActivity` is useful as a coarse busy/idle signal.
- It cannot report CPU percent, memory, child process count, throughput, write count, data byte count, active session count across windows, or p95 latency.
- `pidusage` is already installed, so adding richer per-PTY process metrics is low dependency risk.

## Minimal Missing Observability

For 10/20/30 Codex session in-app benchmark, add the smallest explicit metrics surface instead of scraping UI state.

Recommended new surfaces:

1. Main-process benchmark metrics service
   - Candidate new file: `src/main/services/benchmark/BenchmarkMetricsService.ts`
   - Track:
     - active session count by `kind` and `backend`
     - PTY count
     - session creates/kills/exits
     - writes count and bytes
     - emitted data event count and bytes
     - session state transitions
     - optional CPU/memory/process-tree stats per session using existing `pidusage` + `pidtree`

2. IPC handler
   - Candidate new file: `src/main/ipc/benchmark.ts`
   - Candidate channels in `src/shared/types/ipc.ts`:
     - `benchmark:metrics:snapshot`
     - `benchmark:metrics:reset`
   - Return a typed snapshot rather than logs.

3. Type definitions
   - Candidate new file: `src/shared/types/benchmark.ts`
   - Include `BenchmarkMetricsSnapshot`, `SessionMetrics`, `ProcessTreeMetrics`.

4. Session/PTY integration points
   - `src/main/services/session/SessionManager.ts`
     - Increment create/attach/detach/kill/write/resize/data/exit/state counters.
     - Expose internal session count through service-level snapshot, not by leaking private maps.
   - `src/main/services/terminal/PtyManager.ts`
     - Add optional method for process-tree stats if detailed CPU/memory is needed.
     - Existing `getProcessActivity` can remain boolean for UI.

5. Preload exposure for automation
   - `src/preload/index.ts`
   - Expose:
     - `window.electronAPI.benchmark.snapshot()`
     - `window.electronAPI.benchmark.reset()`

6. Optional renderer helper for manual verification
   - Candidate path: `src/renderer/stores/benchmark.ts` or hidden dev-only panel.
   - Not required if benchmark is driven by automation through preload.

## Candidate Benchmark Execution Path

Without source changes, a harness can partially benchmark through renderer preload APIs:

1. Start app with `pnpm dev` through `scripts/dev.js`.
2. From Electron renderer automation, create N sessions via `window.electronAPI.session.create`.
3. Launch Codex-like command using `initialCommand`.
4. Subscribe to `window.electronAPI.session.onData/onExit/onState`.
5. Poll `window.electronAPI.session.list()` and `getActivity(sessionId)`.

Limitations of this no-change path:

- Session count is window-attached only.
- No main-process aggregate counters.
- No terminal byte throughput unless harness counts renderer events itself.
- No accurate CPU/memory per session beyond boolean `getActivity`.
- No built-in Playwright/Electron automation harness exists.

Recommended path for accepted benchmark:

1. Add benchmark IPC snapshot/reset.
2. Add Playwright/Electron automation harness.
3. Add script such as `pnpm benchmark:app --sessions=10`, then run 10/20/30 profiles.
4. Record metrics snapshots before, during, and after each profile.

## Highest-Value Candidate Paths

- `package.json`
- `scripts/dev.js`
- `vitest.config.ts`
- `src/main/ipc/session.ts`
- `src/main/ipc/terminal.ts`
- `src/main/ipc/webInspector.ts`
- `src/main/ipc/index.ts`
- `src/main/ipc/window.ts`
- `src/main/services/session/SessionManager.ts`
- `src/main/services/terminal/PtyManager.ts`
- `src/main/services/webInspector/WebInspectorServer.ts`
- `src/shared/types/ipc.ts`
- `src/shared/types/session.ts`
- `src/shared/types/terminal.ts`
- `src/shared/types/webInspector.ts`
- `src/preload/index.ts`
- `src/renderer/stores/terminal.ts`
- `src/renderer/components/settings/WebInspectorSettings.tsx`
- `scripts/web-inspector.user.js`
