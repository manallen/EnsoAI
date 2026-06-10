# Requirement Context: multi-agent-performance

## 关键发现
<!-- managed-section: explore -->
- 多 Agent 卡顿的主要瓶颈在 renderer / IPC / xterm 生命周期放大，不是单纯语言性能问题。
- `AgentPanel` 当前维护 `globalSessionIds` 并渲染所有 repo/worktree 的 AgentTerminal，隐藏终端仍保留完整 xterm、observer 和 IPC 监听。
- `useXterm` 每实例注册 `session.onData/onExit/onState`，导致任一 PTY 输出都会唤醒所有挂载终端的 listener 后再过滤。
- `SessionManager` 当前按 PTY chunk 直接发送 `session:data`，主进程缺少 per-session 批量合并和背压。
- 默认 DOM renderer + 10000 scrollback、每秒活动轮询 `pidtree + pidusage` 会在多 Agent 场景进一步放大开销。

## 技术决策
<!-- managed-section: tech -->
- 保持 Electron/React/node-pty/xterm 技术栈，不做 Rust/Tauri 重写。
- 以 `SessionManager` / `PtyManager` 的后端 session 和 replay buffer 作为会话连续性来源；隐藏或切换 UI 只 detach，不 kill PTY。
- renderer 增加单一 session event bus，全局只注册一组 `SESSION_DATA/EXIT/STATE` IPC listener，再按 sessionId 分发。
- `AgentPanel` 不再长期挂载所有 AgentTerminal；只对可见、pending command 或预热 session 挂载 xterm。
- `SessionManager` 对 PTY data 做 per-session 16-33ms 批量合并，exit 前 flush，减少 `webContents.send`。
- 活动检测改为可见 session 按需轮询，后台 session 依赖 output/hook 更新轻量状态。
- 性能证明必须来自 10/20/30 个 Codex Agent 前后对比 benchmark，不能用结构性假设替代实测。

## 设计摘要
<!-- managed-section: design -->

## 执行备注
<!-- managed-section: exec -->

## 回退记录
<!-- managed-section: rollback -->
