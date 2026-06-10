# Tech Spec Summary: multi-agent-performance

推荐方案保持 Electron/React/node-pty/xterm，不做 Rust/Tauri 重写。核心是后端 session 保活、前端 xterm 按需挂载、renderer 单一 session event bus、主进程 per-session 输出批量合并、不可见 terminal 不写 xterm、活动检测按需降频，并增加多 Agent 性能模式和 10/20/30 个 Codex Agent 前后对比基准。主要风险是 replay 顺序、exit 前 flush、误 kill PTY、event bus 泄漏和 TUI 延迟；通过 attach/replay 测试、subscriber debug、短批量窗口和性能 evidence gate 缓解。

