# PRD: multi-agent-performance

## 1. 背景与目标

EnsoAI 的核心使用场景是 Git Worktree + 多 AI Agent 并行协作。用户反馈在同一应用内同时运行多个 Codex、Claude CLI Agent 后明显卡顿，影响切换、输入、滚动和 Agent 输出阅读。

本轮源码探索显示，当前性能问题主要来自前端和 IPC 放大，而不是单纯的 TypeScript 计算慢：

- `AgentPanel` 为保持会话不丢，把所有 repo / worktree 的 AgentTerminal 都长期挂载，隐藏终端只用 `opacity-0 pointer-events-none`。
- 每个 `AgentTerminal` 内的 `useXterm` 都注册 `session.onData/onExit/onState`，所有挂载终端都会收到每个 PTY 输出事件后再按 `sessionId` 过滤。
- 主进程 `SessionManager` 对 PTY 输出按 chunk 直接 `webContents.send`，没有按 session 批量合并或背压。
- 每个 xterm 实例都持有 DOM、scrollback、link provider、ResizeObserver、visibility/focus refresh 等资源。
- Agent 活动检测在用户 Enter 后每秒轮询 `session.getActivity`，主进程再通过 `pidtree + pidusage` 检测进程树。
- 默认终端配置是 DOM renderer + 10000 行 scrollback，适合兼容性，但不适合大量后台 Agent 同时输出。

目标：在不牺牲多 Agent 并行和会话恢复能力的前提下，显著降低多 Agent 场景的 renderer 主线程占用、IPC 事件数量、隐藏终端 DOM/observer 数量和系统活动检测开销。

## 2. 范围与非范围

### 本期包含 (In Scope)

- 重构 Agent 终端前端挂载策略：后台 / 非当前 repo / 非当前 worktree / 非当前 tab 的 Agent session 保持后端 PTY 或 replay buffer，但不长期保留完整 xterm DOM 和所有 browser observer。
- 重构 renderer session 事件订阅：从“每个终端各自订阅全局 IPC”改为“单一全局订阅 + 按 sessionId 分发给当前需要消费的终端”。
- 在主进程为 session 输出增加批量合并：按 session 在短窗口内合并 PTY chunks，再发送给 renderer，同时保留 replay buffer。
- 优化后台输出策略：不可见终端只更新轻量状态 / replay buffer，不持续 `terminal.write` 到隐藏 xterm。
- 优化 xterm 默认和设置：提供面向多 Agent 的性能档，限制默认 scrollback 或提示用户对大量会话启用 WebGL / 较小 scrollback。
- 优化活动检测：减少 `pidtree + pidusage` 调用频率，优先使用 Claude hook / 输出状态，只有需要时才轮询进程树。
- 补充可重复的性能基准和手动验收脚本，覆盖 1、4、8、12 个 Agent 会话的输入延迟、输出吞吐、CPU、内存和 IPC 事件数。

### 本期不包含 (Out of Scope)

- 不进行 Rust / Tauri / 原生 UI 全量重写。
- 不改变 Codex、Claude CLI 自身行为和模型侧响应速度。
- 不取消多 Agent 并行能力，也不要求用户通过少开 Agent 解决问题。
- 不引入新的终端渲染库或大型状态管理框架。
- 不重做整体 UI 信息架构；如需新增性能模式设置，只做小范围设置项和提示。
- 不解决远程连接链路的网络延迟问题，除非它与 session 输出分发共用同一瓶颈。

## 3. 功能性需求与验收标准

| ID | 需求 | 验收标准 |
|----|------|----------|
| F1 | 后台 Agent session 前端轻量化 | Given 已创建 8 个 Agent session，When 当前只查看其中 1 个，Then DOM 中不应存在 8 个完整 xterm 实例；后台 session 的后端 PTY 继续运行，切回后可通过 replay 恢复最近输出。 |
| F2 | 单一 IPC 订阅与 session 分发 | Given 同一窗口有 N 个 AgentTerminal，When 任意 session 输出数据，Then renderer 只存在一个 `SESSION_DATA` IPC listener，且只唤醒目标 session 的消费者。 |
| F3 | 主进程输出批量合并 | Given 某 Agent 高频输出，When PTY 在 100ms 内产生多个 chunks，Then `SessionManager` 对同一 session 合并后发送，减少 `webContents.send` 次数，同时 replayBuffer 内容完整。 |
| F4 | 不可见终端不写入 xterm | Given session 不在当前 repo/worktree/tab 或不是当前可见 group，When 后端有输出，Then 不调用隐藏 xterm 的 `terminal.write`，只更新后端 replay / 轻量运行状态。 |
| F5 | 切换恢复体验保持 | Given 后台 Agent 已持续输出一段时间，When 用户切回该 session，Then UI 能显示最近输出并继续接收 live 输出，不重复大段内容，不丢失退出状态。 |
| F6 | 活动检测降噪 | Given 多个 Agent 同时运行，When 没有用户新输入或已有 Hook 状态可用，Then 不持续为所有 session 每秒执行 `pidtree + pidusage`；进程树检测应按需、限频、可取消。 |
| F7 | 性能设置可见 | Given 用户经常开多个 Agent，When 进入 Terminal 设置，Then 能看到与 renderer、scrollback、性能模式相关的清晰选项或推荐值。 |
| F8 | 性能基准可重复 | Given 开发者运行性能验证脚本或手动 checklist，When 分别测试 1/4/8/12 session，Then 能记录 CPU、内存、IPC 数据事件数、renderer long task、输入延迟和输出恢复耗时。 |

建议验收阈值（在本机基线重新测量后可调整）：

- 8 个 Agent session、只有 1 个可见时，renderer 主线程长任务数量较改造前下降至少 50%。
- 8 个 Agent session 高频输出时，`SESSION_DATA` listener 数量固定为 1，`webContents.send(session:data)` 次数下降至少 40%。
- 8 个后台 session 持续输出 60 秒后，切回任一 session 的最近输出恢复时间 P95 小于 500ms。
- 12 个空闲 Agent session 时，非 Agent CLI 自身造成的 EnsoAI renderer CPU 占用保持在低个位数百分比区间；如果本机基线不同，以改造前后对比下降至少 30% 为准。
- 不出现 session 丢失、后端 PTY 被误杀、重复 replay、退出事件丢失、输入写错 session。

## 4. 非功能性约束

### MUST

- 必须保持多 Agent 并行和每个 worktree 独立 session 的产品体验。
- 必须保持关闭 session 时才真正 kill 后端 PTY；仅隐藏、切换 repo/worktree 或切 tab 不应误杀进程。
- 必须保证 replay buffer 与 live 输出顺序一致，不重复、不明显丢失、不跨 session。
- 必须保证输入、resize、focus 只作用于当前可见/激活 session。
- 必须保留现有 TypeScript / Electron / React / node-pty / xterm 技术栈，不做整栈迁移。
- 必须遵守项目约束：不使用 `as any` / `@ts-ignore`，优先现有 UI / store / IPC 模式。
- 必须提供性能回归验证方法，避免只凭主观体感判断。

### SHOULD

- 应优先做架构上收益最大的减法：减少隐藏 xterm、减少全局 listener、减少 IPC 消息。
- 应将批量窗口控制在不影响 TUI 交互体验的范围内，建议 16-33ms 起步。
- 应将后台恢复窗口、replay 字符数、scrollback 等参数集中管理，避免散落 magic number。
- 应优先使用 sessionId 精确订阅，避免 store selector 扫描全量 sessions。
- 应为大量 Agent 用户提供性能模式默认值或一次性迁移提示。

### MAY

- 可以给后台 session 增加轻量输出计数、最后输出时间、未读状态，而不是完整终端渲染。
- 可以对 Codex / Claude / Cursor 等不同 Agent 设置不同活动检测策略。
- 可以增加开发期 debug 计数器，用于显示当前 xterm 实例数、session listener 数、IPC data rate。

## 5. 依赖与风险

### 依赖

- `src/renderer/components/chat/AgentPanel.tsx`：当前全量 AgentTerminal 挂载和 group/session 映射逻辑。
- `src/renderer/components/chat/AgentTerminal.tsx`：Agent command 构造、活动检测、通知、状态更新和 `useXterm` 接入。
- `src/renderer/hooks/useXterm.ts`：xterm 生命周期、IPC 订阅、输出 flush、resize/focus/visibility 逻辑。
- `src/main/services/session/SessionManager.ts`：后端 session 生命周期、replay buffer、数据发送。
- `src/preload/index.ts`：session IPC listener 暴露方式。
- `src/main/services/terminal/PtyManager.ts`：PTY 创建、进程活动检测和进程树管理。
- `src/renderer/stores/agentSessions.ts` / `worktreeActivity.ts` / `terminalWrite.ts`：运行状态、未读状态和外部写入。
- `src/renderer/stores/settings/index.ts` 与 `GeneralSettings.tsx`：默认 renderer、scrollback 和用户设置。

### 风险

- 轻量化隐藏终端可能引入切回时 replay 不完整、重复输出或退出事件顺序错乱。
- 单一 IPC 分发层如果清理不严格，可能造成消费者泄漏或 sessionId 映射到旧组件。
- 主进程批量合并窗口过大，会影响 TUI 刷新和交互实时性；窗口过小则收益不足。
- 减少前端挂载后，依赖 xterm buffer 的逻辑（例如根据当前行自动命名、slash command 检测）只能在可见 session 上工作，需要定义边界。
- 活动检测降频后，Agent “运行中/完成/未读”状态可能变慢，需要用 Claude Stop Hook、输出事件和超时策略组合补偿。
- WebGL 默认值可能在部分机器上有兼容问题，设置变更应谨慎，必要时保留 DOM 兼容模式。
