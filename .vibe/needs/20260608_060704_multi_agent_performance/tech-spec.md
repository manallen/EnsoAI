# Tech Spec: multi-agent-performance

## 1. 目标架构

目标架构分成五层：

1. **后端 session 保活层**：`SessionManager` / `PtyManager` 继续负责 PTY 生命周期、replay buffer、attach/detach、kill。隐藏或切换 UI 不杀 PTY。
2. **主进程输出批量层**：`SessionManager` 对每个 session 的 PTY data 做短窗口合并，再向 renderer 发送 `session:data`，降低 `webContents.send` 频率。
3. **renderer session event bus**：preload 仍暴露 IPC，但 renderer 侧只保留一个全局 `SESSION_DATA/EXIT/STATE` 订阅，再按 `sessionId` 分发给目标消费者。
4. **xterm 按需挂载层**：`AgentPanel` 不再为所有 repo/worktree 的 session 常驻完整 `AgentTerminal`。只有当前可见 session、正在执行 pending command 的 session、以及短暂预热窗口内的 session 挂载 xterm；其他 session 只保留轻量 metadata 和 backendSessionId。
5. **性能验证层**：增加可重复基准，实测 10 / 20 / 30 个 Codex Agent session 的启动、输出、切换和恢复表现，输出基线与优化后对比。

## 2. 关键技术决策

### D1. 不做 Rust / Tauri 重写

性能瓶颈主要出现在 renderer/xterm/IPC 放大和 Agent CLI 自身资源占用。Rust 只能优化一部分主进程开销，无法消除隐藏 xterm DOM、React effects、IPC listener 放大和 Codex/Claude 进程资源。本期保持 Electron + React + node-pty。

### D2. 后端保活，前端按需挂载

当前 `AgentPanel` 通过 `globalSessionIds` 挂载所有 `AgentTerminal` 来避免切换丢失。改造后保留后端 session，前端只挂载可见或需要执行输入的 terminal。后台 session 的输出进入后端 replay buffer 和轻量前端状态；切回时 attach 并 replay。

关键边界：
- 切换 repo/worktree/tab 只 detach renderer，不 kill PTY。
- 关闭 session 才 kill backend session。
- 后台 session 不保留完整 xterm scrollback；恢复依赖 `SessionManager.replayBuffer` 和 live attach。

### D3. 单一 session event bus

当前每个 `useXterm` 都调用 `window.electronAPI.session.onData/onExit/onState`。改造为 renderer 内单一 event bus：

- `src/renderer/lib/sessionEventBus.ts` 或等价模块在首次订阅时注册唯一 IPC listener。
- bus 按 `sessionId` 管理 `Set<handler>`。
- `useXterm` 改为订阅指定 `backendSessionId`，只接收目标 session 事件。
- 消费者清理时必须 unsubscribe，bus 在无消费者时可保留单一 IPC listener，避免反复注册。

这能把 `SESSION_DATA` listener 数从 O(terminal count) 降为 O(1)，并减少每个输出 chunk 唤醒所有隐藏 terminal 的成本。

### D4. 主进程 per-session 输出批量合并

在 `SessionManager.handleLocalData` 和 remote session data 路径上引入短窗口合并：

- 每个 session 维护 pending data buffer。
- 首个 chunk 后启动 16ms 或 30ms timer。
- timer 到期后一次 `emitData(sessionId, combinedData)`。
- replay buffer 在收到原始 chunk 时立即 append，或 flush 前 append；必须保证 replay 与发往 renderer 的内容顺序一致。
- exit 前必须 flush pending data，再发送 exit。

默认窗口建议从 16ms 起步，必要时通过常量调整到 30ms。窗口过大会影响 TUI 体验，过小收益不足。

### D5. 不可见 terminal 不写 xterm

`useXterm` 的 `terminal.write` 只对可见 session 执行。后台输出通过后端 replay buffer 保留；前端仅更新轻量字段：

- `lastOutputAt`
- `unread/outputting/idle`
- 可选 `backgroundOutputBytes`

切回时执行 attach：

1. 订阅 bus 的目标 session。
2. 调用 `session.attach({ sessionId, cwd })`。
3. 写入 replay。
4. 进入 live 输出。

### D6. 活动检测按需降频

`AgentTerminal` 当前用户 Enter 后每秒调用 `session.getActivity`，主进程再 `pidtree + pidusage`。优化策略：

- 优先使用 Claude Hook / Stop Hook / output state 判断。
- Codex session 没有 hook 时，只对当前可见且正在监控的 session 做轮询。
- 后台 session 默认不轮询进程树，只根据 output data 更新最近活动时间。
- 为进程树检测增加更长 TTL 或 shared scheduler，避免多个 UI 组件同时触发同一 session 检测。

### D7. 性能设置与基准优先

保留 DOM 兼容模式，但为多 Agent 场景提供性能建议：

- 建议 scrollback 降到 1000 或 5000。
- 支持 WebGL renderer 时提示更适合大量输出场景。
- 可增加“多 Agent 性能模式”设置，一键应用较小 scrollback、降低后台刷新、关闭不必要动画或 glow。

性能证明必须来自测试，不得在未采集 evidence 前宣称“已证明更快”。

## 3. 备选方案与取舍

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| 全量 Rust/Tauri 重写 | 潜在内存下降，主进程性能好 | 周期大，仍无法解决 xterm/React/Agent CLI 核心开销 | 不采用 |
| 只调默认 WebGL/scrollback | 改动小，立刻有收益 | 无法解决全量挂载和 IPC listener 放大 | 作为辅助 |
| 保留所有 xterm，仅做主进程批量 | 降低 IPC 频率 | 隐藏 DOM/observer/状态 effect 仍大量存在 | 作为第二优先 |
| 前端按需挂载 + event bus + 主进程批量 | 覆盖主要放大路径，保留现有架构 | 需要处理 replay/exit/attach 边界 | 推荐 |
| 完全不渲染后台输出，只保留最后 N 行文本 | 最省资源 | 会丢失终端状态、TUI 恢复差 | 只作为极限模式，不作为默认 |

## 4. 风险与缓解

| 风险 | 缓解 |
|------|------|
| replay 重复或丢失 | 对 attach/replay/live 顺序加单元测试；exit 前 flush pending data。 |
| 后台 session 被误杀 | 区分 detach 和 kill；关闭按钮走 kill，隐藏/切换只 detach。 |
| event bus handler 泄漏 | bus 暴露 subscriber count debug；useEffect cleanup 必须覆盖。 |
| TUI 输出延迟 | 批量窗口从 16ms 起步，并通过性能测试确认交互延迟。 |
| 切回时大 replay 卡顿 | replay 限制为现有 65,536 chars 或配置值；必要时分块写入 xterm。 |
| 活动状态变慢 | 当前可见 session 保留更及时检测；后台使用 output/Stop Hook 驱动。 |
| WebGL 兼容问题 | 不强制 WebGL；作为性能模式建议，保留 DOM fallback。 |

## 5. 与 PRD 验收标准映射

| PRD | 技术方案 |
|-----|----------|
| F1 后台 Agent 前端轻量化 | D2 + D5：后端保活，前端按需挂载，后台仅轻量状态。 |
| F2 单一 IPC 订阅 | D3：renderer session event bus。 |
| F3 主进程输出批量合并 | D4：per-session pending buffer + timer flush。 |
| F4 不可见终端不写 xterm | D5：仅可见 session 执行 `terminal.write`。 |
| F5 切换恢复体验保持 | D2 + D5：attach + replay + live 输出。 |
| F6 活动检测降噪 | D6：可见 session 按需轮询，后台 output/hook 驱动。 |
| F7 性能设置可见 | D7：性能模式或明确设置建议。 |
| F8 性能基准可重复 | D7：10/20/30 Codex Agent 实测基准。 |

## 6. 实施顺序建议

1. 建立性能基准脚本和指标采集，先拿优化前 baseline。
2. 引入 renderer session event bus，保持行为不变。
3. 修改 AgentPanel 挂载策略，让后台 session detach xterm 但保留 backend session。
4. 增加主进程输出批量合并和 exit 前 flush。
5. 降低活动检测成本，后台 session 不轮询进程树。
6. 增加性能模式 / 推荐设置。
7. 运行 10 / 20 / 30 个 Codex Agent 的前后对比，并把结果写入 test report。

## 7. 验证策略

基础验证：
- `pnpm typecheck`
- `pnpm lint`
- 现有 `pnpm test`，尤其 session / git 相关测试。

行为验证：
- 创建多个 Agent session，切换 repo/worktree/group，不误杀 PTY。
- 后台输出后切回，replay 不重复、不丢失、不串 session。
- 输入、resize、focus 只作用于当前可见 session。

性能验证：
- 基线与优化后都测试 10 / 20 / 30 个 Codex Agent。
- 指标至少包括：启动耗时、renderer CPU、main CPU、RSS、`SESSION_DATA` 事件数、renderer IPC listener 数、xterm 实例数、切回恢复 P95、输入延迟。
- 如果本地无法安全启动 30 个真实 Codex session，必须明确记录限制；但仍应提供脚本和降级实测证据，不能把窄 smoke 当成完整性能证明。

