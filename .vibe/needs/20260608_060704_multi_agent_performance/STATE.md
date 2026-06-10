# Requirement State

## Basic Info

- **Name**: multi-agent-performance
- **Description**: 优化 EnsoAI 在同时运行多个 Codex / Claude CLI Agent 时的卡顿问题，重点降低 renderer、IPC、xterm 和状态更新的放大开销。
- **Phase**: ready
- **Started**: 2026-06-08 06:07:04 Asia/Shanghai
- **Last Updated**: 2026-06-08 09:15:00 Asia/Shanghai

## Start Input

用户反馈：在 EnsoAI 里开了很多 Codex、Claude CLI Agent 后明显卡顿，希望重新详细探索代码，明确如何优化提升速度，并使用 Vibe explore 沉淀需求。

已知上下文：
- 项目是 Electron 39 + React 19 + TypeScript + node-pty + xterm.js。
- 多 Agent 并行运行是产品核心场景，不能简单要求用户少开 Agent。
- 需要保留每个 worktree / repo 的 Agent 会话可恢复体验，但可以调整前端挂载、输出分发、后台 buffer 和默认性能设置。
- 本轮探索优先基于 repo/source，不引入新依赖，不做 Rust/Tauri 重写方案落地。

需要重点探索：
- AgentTerminal 全量挂载和隐藏终端资源占用。
- PTY 输出从主进程到 renderer 的 IPC 发送/订阅模型。
- xterm 渲染、scrollback、renderer 默认值和后台 terminal 刷新策略。
- Agent 活动检测轮询的系统调用成本。
- Zustand store 订阅范围、React 重渲染和全局状态更新放大。
- 可量化的性能验收标准。

## Phase Progress

| Phase | Status | Updated |
|-------|--------|---------|
| explore | completed | 2026-06-08 06:18:00 Asia/Shanghai |
| design | skipped | 2026-06-08 06:18:00 Asia/Shanghai |
| tech | completed | 2026-06-08 06:38:00 Asia/Shanghai |
| plan | completed | 2026-06-08 07:38:04 Asia/Shanghai |
| exec | completed | 2026-06-08 09:02:00 Asia/Shanghai |
| test | completed | 2026-06-08 09:15:00 Asia/Shanghai |

## Explore Output

- `prd.md`: generated
- `prd.summary.md`: refreshed
- `requirements.md`: extracted_from_prd
- `checkpoints/after-explore.md`: generated
- **Recommended Next Phase**: tech

## Tech Output

- `tech-spec.md`: generated
- `tech-spec.summary.md`: refreshed
- `checkpoints/after-tech.md`: generated
- `memory/decisions`: 3 decisions added
- **Recommended Next Phase**: plan

## Plan Output

- `plan.md`: generated
- `plan.summary.md`: refreshed
- `checkpoints/after-plan.md`: generated
- **Recommended Next Phase**: exec

## Exec Progress

- T0 completed: Codex CLI baseline generated for 10/20/30 `gpt-5.5` agents; EnsoAI in-app metrics baseline remains a recorded instrumentation gap.
- T1 completed: persistent local session detach now buffers instead of destroying PTY.
- T2 completed: renderer session event bus added and `useXterm` uses per-session subscriptions.
- T3 completed: main-process session output now uses per-session batching with exit/dead flush.
- T4 completed: AgentPanel now mounts AgentTerminal on demand instead of all sessions globally.
- T5 completed: AgentTerminal activity polling stops outside active visible sessions.
- T6 completed: benchmark metrics IPC and renderer event bus debug snapshot added.
- T7 completed: output-state selector path normalization moved out of hot selector body.
- T8 completed: test/typecheck/build/runtime startup smoke passed for changed code; full lint blocked by existing diagnostics.
- T9 completed: 10/20/30 Codex CLI baseline/after comparison completed; EnsoAI built-app session/IPC 10/20/30 after benchmark completed with zero failures. App-level before/after percentage remains intentionally unclaimed because no pre-change app benchmark harness existed.

## Test Output

- `reports/review-latest.md`: generated, no blocking Critical/Major issues remain.
- `test-report.md`: generated, requirement coverage and test evidence recorded.
- `test-report.summary.md`: generated.
- `checkpoints/after-test.md`: generated.
- **Result**: READY with documented residual risks.
