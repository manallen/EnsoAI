# Requirements Summary: multi-agent-performance

`prd.md` 是主需求文档；本文件仅提取 explore 后的约束摘要，供兼容读取。

## MUST

- 保持多 Agent 并行、worktree 独立 session 和切换恢复体验。
- 切换 / 隐藏 / 非当前 tab 不得误杀后端 PTY；只有关闭 session 才 kill。
- replay buffer 与 live 输出必须按 session 保序，不重复、不跨 session、不明显丢失。
- 输入、resize、focus 必须只作用于当前可见 / 激活 session。
- 保持 Electron + React + node-pty + xterm 技术栈，不做 Rust/Tauri 全量迁移。
- 遵守项目类型和 UI 约束，不使用 `as any` / `@ts-ignore`。
- 提供可重复性能回归验证。

## SHOULD

- 优先减少隐藏 xterm 实例、全局 IPC listener 和 `webContents.send` 次数。
- 主进程输出批量窗口建议从 16-33ms 验证。
- 将 replay、scrollback、后台恢复窗口等参数集中管理。
- 使用 sessionId 精确订阅，避免 store selector 全量扫描。
- 为多 Agent 用户提供性能模式或推荐设置。

## MAY

- 为后台 session 维护轻量输出计数 / 最后输出时间 / 未读状态。
- 按 Agent 类型定制活动检测策略。
- 增加开发期性能 debug 计数器。

