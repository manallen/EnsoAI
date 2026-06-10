# After Plan Checkpoint

- **Requirement**: multi-agent-performance
- **Generated**: 2026-06-08 07:38:04 Asia/Shanghai
- **Task Count**: 10
- **Estimated Work**: 中到高；核心风险集中在 session 生命周期、输出顺序和 AgentPanel 按需挂载。

## Key Dependencies

- T0 baseline 必须先于 runtime 代码改动，且要区分 Codex CLI 进程成本与 EnsoAI 应用内 session/UI/IPC/xterm 成本。
- T1 persistent detach 是 T4 按需卸载隐藏 terminal 的前置条件。
- T2 session event bus 是 `useXterm` 去全局 listener 放大的前置条件。
- T3 output batching 与 T4 xterm 按需挂载可在 T1/T2 后并行。
- T8/T9 是 READY gate，不能被文档结论替代。

## Risk Tasks

- T0/T9：真实 10/20/30 Codex Agent benchmark 可能受 Codex CLI 认证、限流、系统负载和 Electron 自动化能力影响；失败要记录 blocker，不能用 CLI-only 数据证明 EnsoAI UI 提速。
- T1：detach 语义变更若错误，会误杀 PTY 或泄漏进程。
- T3：batching 若 flush 顺序错误，会造成输出乱序或 exit 前丢尾部输出。
- T4：按需挂载若遗漏 pending/replay，会让后台 Agent 切回时输出缺失。

## Handoff

下一阶段进入 `exec`。建议按 L0-L6 执行，并在可用子代理时对不共享文件的任务使用 `gpt-5.5 xhigh` 并行处理；共享 `SessionManager.ts` / `AgentPanel.tsx` 的任务需要主线串行合并。
