# Review Latest: 10-20 agent runtime P0

Date: 2026-06-12
Scope:
- `src/renderer/hooks/useXterm.ts`
- `src/renderer/components/chat/AgentTerminal.tsx`
- `src/renderer/components/chat/AgentPanel.tsx`
- `src/renderer/stores/agentSessions.ts`

## Verdict

PASS.

本轮实现符合 10-20 agent 并行卡顿优化目标：隐藏终端暂停 xterm DOM 写入、xterm window 级事件监听收敛、`AgentTerminal` memo 化、父组件传入稳定 callbacks、session/title 无变化早退。没有发现 Critical / Major 阻塞。

## Acceptance Checks

| Check | Result | Evidence |
|---|---|---|
| 隐藏终端不写 xterm DOM | PASS | `flushBufferedData` 在不可见时进入 hidden buffer，业务 `onData` 仍触发 |
| hidden replay 顺序正确 | PASS | 可见 flush 会先 drain hidden buffer，再写当前 buffered data |
| window 级监听收敛 | PASS | `resize` / `visibilitychange` / `focus` 由模块级 registry 单次监听，terminal 只注册 subscriber |
| `AgentTerminal` memo | PASS | `AgentTerminalComponent` 经 `memo` 导出 |
| 父组件 callbacks 稳定 | PASS | `AgentPanel` 使用 id 参数化 handler，替换渲染循环内大部分 inline callbacks |
| session 更新降噪 | PASS | `updateSession` 无变化返回原 state；title 相同早退 |

## Findings

### Critical

None.

### Major

None.

### Minor

1. Module-level window listeners intentionally live for renderer lifetime.

   Evidence: `ensureTerminalWindowEventListeners()` only installs once and does not remove the three native listeners. Subscriber callbacks are removed on terminal unmount, so this is a fixed-size renderer-lifetime listener set, not per-terminal leakage. This is acceptable for an Electron renderer lifecycle.

2. `AgentTerminal` memo still sees primitive prop churn from session state changes.

   Memo now protects against parent re-renders with unchanged props, but actual session field changes (`initialized`, `activated`, `pendingCommand`, `terminalTitle` path through store) still re-render the affected terminal. This is expected.

3. Hidden display history remains bounded.

   Hidden replay keeps the last 1,000,000 JS string code units. PTY data and business `onData` are still consumed, but old terminal display history can be truncated before the session becomes visible.

## Verification

| Command | Result |
|---|---|
| `pnpm exec biome check --write src/renderer/hooks/useXterm.ts src/renderer/components/chat/AgentTerminal.tsx src/renderer/components/chat/AgentPanel.tsx src/renderer/stores/agentSessions.ts` | PASS |
| `pnpm typecheck` | PASS |
| `pnpm vitest run` | PASS, 34 tests |
| `pnpm lint` | PASS, 415 files |

## Non-blocking Extras

- `ResizeObserver` and `IntersectionObserver` remain per terminal because they observe each terminal container; hidden paths early-return before resize work.
- `AgentPanel` still maps all `globalSessionIds`; this is improved by memo/stable callbacks but not full terminal virtualization.
- `WorktreePanel` / `TreeSidebar` duplicate git diff polling remains a separate background-load target.

## Requirement Compliance

Compliant. The changes reduce renderer work under many mounted agent terminals without changing PTY ownership, process lifetime, or session routing semantics.

## Recommendation

Continue to packaging. For a future optimization batch, the next highest-value runtime target is app-level stress measurement plus optional xterm UI detach for long-hidden sessions.
