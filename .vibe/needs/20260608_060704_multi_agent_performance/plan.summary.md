# Plan Summary: multi-agent-performance

计划先建立 10/20/30 Codex baseline，证据分为真实 Codex CLI 进程规模和 EnsoAI 应用内 session/UI/IPC/xterm 指标；再串行修复 session detach 保活与主进程输出 batching，并并行落地 renderer event bus、xterm 按需挂载、活动检测降频、性能设置和 selector 收窄。风险任务是 detach/replay、exit 前 flush、AgentPanel 挂载和真实 benchmark。没有同口径 baseline/after evidence 时只能称结构性优化假设；READY 依赖 correctness smoke、`pnpm test/typecheck/lint` 和性能报告。
