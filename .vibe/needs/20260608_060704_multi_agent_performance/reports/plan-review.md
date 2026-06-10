# Plan Review: multi-agent-performance

## Findings

- **Fixed**: T0/T9 原计划只明确 Codex CLI 进程层 benchmark，不足以证明 EnsoAI 内同时开 10/20/30 个 Agent 的 UI/IPC/xterm 路径改善。已补充双层证据要求：Codex CLI 进程规模 + EnsoAI 应用内 session 指标；如果只有 CLI-only 数据，不能写“EnsoAI 已提升”。

## Dependency Audit

- 无循环依赖。
- T0 baseline 在所有 runtime 代码改动前，顺序正确。
- T1 persistent detach 是 T4 按需卸载 hidden terminal 的必要前置，已覆盖。
- T2 event bus 是 `useXterm` 定向订阅的前置，已覆盖。
- T3/T4 文件边界基本可并行，但都属于高风险合并点，执行时需要主线审查。

## Verification Audit

- 每个任务都有 Verify 和 Done。
- 性能类任务保留 evidence wording：没有同口径 baseline/after 数据时，只能写结构性优化假设。
- READY gate 包含 `pnpm test`、`pnpm typecheck`、`pnpm lint`、runtime smoke 和真实 10/20/30 Codex benchmark。

## Result

Plan review passed after patching benchmark evidence scope.
