# After Tech Checkpoint

## 推荐方案

保持 Electron/React/node-pty/xterm，不做 Rust/Tauri 重写。优化主线是后端 session 保活、前端 xterm 按需挂载、renderer 单一 session event bus、主进程 per-session 输出批量合并、不可见 terminal 不写 xterm、活动检测按需降频，并配套 10/20/30 个 Codex Agent 前后对比基准。

## 关键决策

- 后端 PTY/replay buffer 是会话连续性 authority。
- 前端隐藏或切换只 detach，不 kill。
- renderer `SESSION_DATA/EXIT/STATE` 只保留一组 IPC listener。
- 主进程输出批量窗口从 16ms 起步，必要时调到 30ms。
- 未采集可比 benchmark 前，只能称为结构性优化假设。

## 新增 Decision 记忆

- `.vibe/memory/decisions/multi-agent-session-event-bus.md`
- `.vibe/memory/decisions/backend-keeps-agent-session.md`
- `.vibe/memory/decisions/per-session-output-batching.md`

## 下一阶段

进入 `plan`，需要把方案拆为可并行执行的原子任务，并把 10/20/30 Codex Agent 性能测试列为硬门槛。

