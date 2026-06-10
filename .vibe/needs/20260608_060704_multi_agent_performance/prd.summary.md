# PRD Summary: multi-agent-performance

目标是优化 EnsoAI 多 Codex/Claude Agent 同时运行时的卡顿。探索定位到主要瓶颈：`AgentPanel` 全量挂载所有 AgentTerminal、每个 `useXterm` 都订阅全局 session IPC、主进程按 PTY chunk 直接 `webContents.send`、隐藏 xterm 仍持有 DOM/observer/scrollback、活动检测频繁 `pidtree + pidusage`、默认 DOM renderer + 10000 scrollback。范围包括后台 session 前端轻量化、单一 IPC 订阅分发、主进程输出批量合并、不可见终端不写 xterm、活动检测限频、性能设置与基准。必须保持多 Agent 并行、worktree session 恢复、PTY 不误杀、输出不丢不重不串 session。下一阶段建议 `tech`，评估具体分发层、replay 恢复和批量窗口实现。

