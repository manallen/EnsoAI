# T4 AgentPanel Worker Report

## Scope

- Task: analyze and implement on-demand xterm mounting for `AgentPanel`.
- Edited files:
  - `src/renderer/components/chat/AgentPanel.tsx`
- Files intentionally not edited:
  - `src/renderer/components/chat/AgentTerminal.tsx`
  - `src/renderer/hooks/useXterm.ts`
  - `src/renderer/lib/sessionEventBus.ts`
  - `src/main/services/session/*`

## Findings

`AgentPanel` previously used `globalSessionIds` as an ever-growing mounted-session set:

- every agent session from `allSessions` was added to `globalSessionIds`;
- removed sessions were pruned, but background sessions stayed mounted;
- the render map iterated `Array.from(globalSessionIds)` and rendered an `AgentTerminal` for each entry;
- hidden terminals used opacity and pointer-event hiding, but the React component and `useXterm` hook still existed.

This means hidden/background sessions still paid the renderer cost of mounted `AgentTerminal` and xterm instances.

`AgentTerminal` already supports the target remount path:

- it receives `backendSessionId`;
- `useXterm` first tries `window.electronAPI.session.attach({ sessionId: backendSessionId, cwd })`;
- attach returns replay output and writes it into the new terminal;
- unmount detaches instead of killing because agent terminals pass `persistOnDisconnect: true`.

No `AgentTerminal.tsx`, `useXterm.ts`, `eventBus`, or main/session change was needed.

## Implementation

Replaced the all-session mount list with an on-demand mount set:

- current visible sessions:
  - when the chat panel is active, mount each visible split group's `activeSessionId`;
  - inactive tabs in the same group are not mounted;
- pending command sessions:
  - mount current-worktree sessions with `pendingCommand`, even if they are not currently visible, so auto-execute can start;
- prewarmed sessions:
  - keep sessions mounted for `1500ms` after they leave the immediate set;
  - this covers fast tab/group/worktree switches and gives newly created terminals time to publish `backendSessionId`;
- background sessions:
  - after the prewarm TTL, only store metadata and `backendSessionId` remain;
  - switching back remounts `AgentTerminal`, which attaches and replays from the backend session.

The render map now uses `mountedSessions` instead of `globalSessionIds`.

## Acceptance Mapping

- Only current visible sessions are mounted:
  - active session per visible split group is mounted while `AgentPanel` is active.
- Pending command sessions are mounted:
  - current-worktree `session.pendingCommand` entries are in the immediate mount set.
- Necessary prewarm sessions are mounted:
  - recently visible/pending sessions stay mounted for `AGENT_TERMINAL_PREWARM_MS`.
- Background sessions keep metadata/backend ID:
  - sessions outside the immediate/prewarm set no longer render `AgentTerminal`.
- Switching back uses attach/replay:
  - relies on existing `backendSessionId` and `useXterm` attach/replay behavior.

## Verification

- `pnpm typecheck`
  - passed.
- `pnpm exec biome check src/renderer/components/chat/AgentPanel.tsx`
  - passed.
- `pnpm lint`
  - failed on pre-existing/out-of-scope diagnostics in unrelated files and `.vibe` JSON report formatting.
  - examples: unused imports under `src/main/services/ai/*`, formatter changes in existing `.vibe` raw JSON files, and existing `useXterm.ts` `fit()` false-positive diagnostics.

## Residual Risk

- A background session with no valid `backendSessionId` cannot be restored by attach/replay after unmount. The prewarm TTL reduces the risk for newly created terminals by giving `useXterm` time to call `onBackendSessionIdChange`.
- If a backend session has already died, remount behavior follows existing `useXterm` fallback behavior and may create a new backend session.
