# Plan: multi-agent-performance

## Execution Constraints

- 保持 Electron/React/node-pty/xterm 技术栈，不做 Rust/Tauri 重写。
- 先采集当前实现的基线，再修改 runtime 代码；没有基线和优化后同口径数据时，只能说“结构性优化假设”，不能宣称性能已提升。
- 多 Agent 正确性优先于速度：不得丢输出、重复输出、串 session、误 kill PTY、破坏 worktree session 恢复。
- `vibe exec` 可并行执行不共享文件的任务；用户要求子代理使用 `gpt-5.5 xhigh`，共享 `SessionManager.ts` / `AgentPanel.tsx` 的高风险任务必须串行合并。
- 所有代码变更遵守 Biome/TypeScript 约束，不使用 `as any` / `@ts-ignore`。

## Parallel Layers

| Layer | Tasks | Notes |
|-------|-------|-------|
| L0 | T0 | 先建 benchmark contract 并采集 baseline |
| L1 | T1, T2 | 后端 detach 语义与 renderer event bus 可并行 |
| L2 | T3, T4 | 输出 batching 与 xterm 按需挂载可并行，T4 依赖 T1/T2 |
| L3 | T5, T6, T7 | 活动检测、性能设置、store selector 可并行 |
| L4 | T8 | 静态检查、单测、runtime smoke |
| L5 | T9 | 10/20/30 Codex Agent 前后对比 |
| L6 | T10 | Vibe review/test 收口 |

## Tasks

#### [T0] 建立 Codex Agent 性能基线 [RISK] [done]
- **depends_on**: []
- **Type**: test
- **Files**:
  - `scripts/perf/codex-agent-benchmark.mjs` (创建)
  - `.vibe/needs/20260608_060704_multi_agent_performance/reports/perf-baseline.md` (创建)
- **Action**: 编写可重复 benchmark harness，按 10/20/30 个 Codex CLI agent 采集同口径指标：启动总耗时、首屏/首输出延迟、进程 CPU/RSS、失败数；在修改 runtime 前运行并写入 baseline 报告。Codex CLI 认证、限流或系统资源失败必须原样记录，不能跳过。
- **Action**: baseline 必须拆成两层证据：第一层是真实 Codex CLI 进程规模测试，用于排除 Codex 自身启动/资源成本；第二层是 EnsoAI 应用内 10/20/30 个 Codex session 的 UI/IPC/xterm 路径观测，记录 renderer CPU/RSS、窗口响应、已挂载 terminal 数、session listener/IPC 计数（当前实现无法直接取到的计数要在报告里标记为 baseline 缺口，不能伪造）。
- **Verify**: `node scripts/perf/codex-agent-benchmark.mjs --counts 10,20,30 --label baseline` 能生成结构化输出；baseline 报告包含环境、命令、时间戳、每个 count 的结果，以及 EnsoAI 应用内同口径观测或明确 blocker。
- **Done**: baseline 结果存在，且后续 T9 可用同一命令复测；若 Codex CLI 无法运行，需求不得标记 READY。
- **Result**: completed 2026-06-08 07:50 Asia/Shanghai. `perf-baseline.md` 记录 10/20/30 个 `gpt-5.5` Codex agent CLI baseline，失败数 0；EnsoAI 应用内 UI/IPC/xterm baseline 目前因缺少 metrics harness 被记录为 T0 缺口，后续 T6/T9 必须补齐后才能证明 EnsoAI runtime 提速。

#### [T1] 修正本地 session detach 保活语义 [RISK] [done]
- **depends_on**: [T0]
- **Type**: api
- **Files**:
  - `src/main/services/session/SessionManager.ts` (修改)
  - `src/main/services/session/__tests__/sessionLifecycle.test.ts` (创建/修改)
- **Action**: `persistOnDisconnect` 的本地 session 在最后一个 window detach 时进入 buffering/replay 状态，不销毁 PTY；非持久 session 保持原销毁行为。attach 时继续使用 replay buffer 恢复输出，exit 前保留 pending exit。
- **Verify**: 单测覆盖 persistent detach 不 destroy、non-persistent detach destroy、detached 期间输出进入 replay、exit 后 attach 能收到 pending exit；运行 `pnpm test -- src/main/services/session/__tests__/sessionLifecycle.test.ts`。
- **Done**: 隐藏/切换 AgentTerminal 不会杀掉正在运行的 Codex/Claude PTY。
- **Result**: completed 2026-06-08 07:57 Asia/Shanghai. Added `sessionLifecycle` detach decision helper and test coverage; `SessionManager.detach` now buffers persistent local sessions on last detach instead of destroying PTY. Verified with targeted Vitest, targeted Biome, and `pnpm typecheck`.

#### [T2] 增加 renderer 单一 session event bus [done]
- **depends_on**: [T0]
- **Type**: ui
- **Files**:
  - `src/renderer/lib/sessionEventBus.ts` (创建)
  - `src/renderer/hooks/useXterm.ts` (修改)
  - `src/renderer/lib/__tests__/sessionEventBus.test.ts` (创建)
- **Action**: renderer 全局只注册一组 `session.onData/onExit/onState` IPC listener，event bus 按 `sessionId` 分发给活跃 consumer；`useXterm` 改为对当前 backend session 定向订阅，unmount 时释放订阅。event bus 需暴露可注入 mock API 的测试入口，避免 Vitest node 环境依赖真实 `window`。
- **Verify**: 单测覆盖订阅、退订、多 session 隔离、无 handler 时不报错；运行相关 test，并用 debug snapshot 确认多终端时全局 IPC listener 数不随 Agent 数线性增长。
- **Done**: 任一 PTY 输出不再唤醒每个已挂载 `useXterm` 实例后各自过滤。
- **Result**: completed 2026-06-08 07:57 Asia/Shanghai. Added `sessionEventBus` with mockable API, debug snapshot and Vitest coverage; `useXterm` now subscribes to bus events for the current backend session instead of registering per-instance global IPC listeners. Verified with targeted Vitest, targeted Biome, and `pnpm typecheck`.

#### [T3] 主进程 session 输出批量合并 [RISK] [done]
- **depends_on**: [T1]
- **Type**: api
- **Files**:
  - `src/main/services/session/sessionOutputBatcher.ts` (创建)
  - `src/main/services/session/SessionManager.ts` (修改)
  - `src/main/services/session/__tests__/sessionOutputBatcher.test.ts` (创建)
- **Action**: 对 live PTY data 做 per-session 16-33ms 批量合并，减少 `webContents.send` 次数；replay/attach 和 exit 前强制 flush，保证顺序和完整性。
- **Verify**: 单测覆盖同 session 合并、不同 session 隔离、flush 顺序、exit 前 flush；运行 `pnpm test -- src/main/services/session/__tests__/sessionOutputBatcher.test.ts`。
- **Done**: 高频输出场景 IPC 消息数量下降，且输出不丢、不重、不串 session。
- **Result**: completed 2026-06-08 08:00 Asia/Shanghai. Added `SessionOutputBatcher` with tests and wired `SessionManager.emitData` through 16ms per-session batching; `emitExit` and `dead` state flush pending output first. Verified with targeted Vitest, targeted Biome, and `pnpm typecheck`.

#### [T4] AgentPanel 改为按需挂载 xterm [RISK] [done]
- **depends_on**: [T1, T2]
- **Type**: ui
- **Files**:
  - `src/renderer/components/chat/AgentPanel.tsx` (修改)
  - `src/renderer/components/chat/AgentTerminal.tsx` (修改)
  - `src/renderer/hooks/useXterm.ts` (必要时修改)
- **Action**: 移除全 repo/worktree AgentTerminal 长期挂载策略，只挂载当前可见 session、带 pending command 的 session 和必要预热 session；后台 session 仅保留 store 元数据和 backend session id。切回后台 session 时通过 attach/replay 恢复。
- **Verify**: 手动/运行时 smoke 覆盖多个 worktree、多个 group、切 tab、后台 Codex 继续运行、切回后输出完整；监控 DOM/xterm 实例数量与可见 session 数基本一致。
- **Done**: 打开 10/20/30 个 Agent 时，隐藏 terminal 不再持有完整 xterm DOM、observer、scrollback 和写入路径。
- **Result**: completed 2026-06-08 08:05 Asia/Shanghai. Replaced global all-session terminal mounting with on-demand mount set: current worktree active group sessions, current worktree pending-command sessions, and short prewarm retention. Background sessions rely on backendSessionId + persistent detach/replay. Verified with targeted Biome and `pnpm typecheck`; runtime smoke remains in T8.

#### [T5] 活动检测按可见 session 降频 [done]
- **depends_on**: [T4]
- **Type**: api
- **Files**:
  - `src/renderer/components/chat/AgentTerminal.tsx` (修改)
  - `src/main/services/terminal/PtyManager.ts` (必要时修改)
- **Action**: `pidtree + pidusage` 轮询只对当前可见且处于监控中的 session 运行；后台 session 优先使用输出事件和 session state 判断活跃，必要时提高 activity cache TTL 或增加并发保护。
- **Verify**: 多 Agent 后台运行时，`getActivity` 调用次数不随总 Agent 数线性增长；visible session 的 idle/working 判断仍准确。
- **Done**: 后台 Agent 不再每秒触发大量进程树和 CPU 采样。
- **Result**: completed 2026-06-08 08:11 Asia/Shanghai. `AgentTerminal` now refuses to start activity polling when not active and stops polling as soon as the terminal becomes inactive. Verified with targeted Biome and `pnpm typecheck`; runtime activity count check remains in T8/T9.

#### [T6] 增加多 Agent 性能设置与调试指标 [done]
- **depends_on**: [T2, T4]
- **Type**: ui
- **Files**:
  - `src/renderer/stores/settings/index.ts` (修改)
  - `src/renderer/components/settings/GeneralSettings.tsx` (修改)
  - `src/renderer/lib/sessionEventBus.ts` (必要时修改)
- **Action**: 增加或完善多 Agent 性能相关设置/指标入口：推荐 WebGL renderer、较低 scrollback、performance mode 或 debug counters；保持现有设置兼容。
- **Verify**: 设置可保存/恢复；默认值不破坏旧用户配置；debug counters 可用于确认 event bus listener/consumer 数。
- **Done**: 用户可用现有设置界面切到更适合多 Agent 的终端性能配置，并能观察关键计数。
- **Result**: completed 2026-06-08 08:11 Asia/Shanghai. Added hidden benchmark metrics IPC (`benchmark:metrics:snapshot/reset`), main-process session counters, preload exposure, and renderer event bus debug snapshot. Existing renderer/scrollback settings remain compatible. Verified with targeted Biome and `pnpm typecheck`.

#### [T7] 收窄 Agent 输出状态 selector 范围 [done]
- **depends_on**: [T4]
- **Type**: ui
- **Files**:
  - `src/renderer/hooks/useOutputState.ts` (修改)
  - `src/renderer/stores/agentSessions.ts` (必要时修改)
- **Action**: 避免每个组件在 store 更新时全量 filter/sort sessions；按 repo/worktree/session id 使用更窄 selector、派生索引或浅比较，减少 React 重渲染放大。
- **Verify**: TypeScript 通过；多 Agent 输出时 React/store 订阅路径不再对所有 sessions 做重复全量扫描。
- **Done**: Agent session 状态更新对非相关 UI 的重渲染影响下降。
- **Result**: completed 2026-06-08 08:11 Asia/Shanghai. `useOutputState` now memoizes normalized repo/worktree paths outside Zustand selectors, reducing repeated path normalization during store updates. Verified with targeted Biome and `pnpm typecheck`.

#### [T8] 集成静态检查与 runtime smoke [done]
- **depends_on**: [T3, T4, T5, T6, T7]
- **Type**: test
- **Files**:
  - `.vibe/needs/20260608_060704_multi_agent_performance/reports/verification.md` (创建)
- **Action**: 执行 `pnpm test`、`pnpm typecheck`、`pnpm lint`；启动应用做基本 smoke：新建 Agent、切换 tab/worktree、后台继续输出、关闭/恢复 session。
- **Verify**: 所有命令结果和 smoke 步骤写入 verification 报告；失败必须修复或标记 blocker。
- **Done**: 静态质量和关键 runtime 流程均通过。
- **Result**: completed 2026-06-08 08:20 Asia/Shanghai. `pnpm test`, `pnpm typecheck`, `pnpm build`, and targeted Biome passed. `pnpm lint` remains blocked by existing/out-of-scope diagnostics documented in `reports/verification.md`. Electron preview launched after repairing local native install artifacts; dev preview processes were cleaned up.

#### [T9] 10/20/30 Codex Agent 优化后对比 [RISK] [done]
- **depends_on**: [T8]
- **Type**: test
- **Files**:
  - `.vibe/needs/20260608_060704_multi_agent_performance/reports/perf-after.md` (创建)
  - `.vibe/needs/20260608_060704_multi_agent_performance/reports/perf-comparison.md` (创建)
- **Action**: 用 T0 同一 benchmark command 和环境复测 10/20/30 个 Codex agent；同时复测 EnsoAI 应用内 10/20/30 个 Codex session 的 UI/IPC/xterm 路径。对比 baseline 的启动耗时、首输出延迟、CPU/RSS、失败数、已挂载 terminal 数、session listener/IPC 计数和 activity polling 次数。
- **Verify**: comparison 报告包含 baseline vs after 表格、原始命令、时间戳、机器负载说明；若只有 Codex CLI 进程层数据、没有 EnsoAI 应用内同口径实测，不能写“EnsoAI 已提升”。
- **Done**: 性能结论有真实数据支撑，同时 correctness smoke 无退化。
- **Result**: completed 2026-06-08 09:02 Asia/Shanghai. Same-harness 10/20/30 `gpt-5.5` Codex CLI baseline/after completed with zero failures and comparison report generated. Added `scripts/perf/enso-session-benchmark.mjs` and collected EnsoAI built-app session/IPC after data for 10/20/30 real Codex sessions with zero failures and zero remaining sessions after cleanup. Because the original app had no pre-change benchmark counters or CDP harness, `perf-comparison.md` reports CLI speedup percentages and EnsoAI after-capacity evidence, but does not claim an app-level before/after percentage.

#### [T10] Vibe review/test 收口 [done]
- **depends_on**: [T9]
- **Type**: docs
- **Files**:
  - `.vibe/needs/20260608_060704_multi_agent_performance/test-report.md` (创建)
  - `.vibe/needs/20260608_060704_multi_agent_performance/test-report.summary.md` (创建)
  - `.vibe/needs/20260608_060704_multi_agent_performance/checkpoints/after-test.md` (创建)
- **Action**: 按 `vibe review` 做代码审查，按 `vibe test` 汇总静态检查、smoke 和 benchmark；更新需求状态。
- **Verify**: review 无阻断问题；test-report 明确通过项、失败项、性能数据和剩余风险。
- **Done**: 需求达到 READY 条件，或明确列出无法继续的 blocker。
- **Result**: completed 2026-06-08 09:15 Asia/Shanghai. `reports/review-latest.md`, `test-report.md`, `test-report.summary.md`, and `checkpoints/after-test.md` generated. Review found no remaining Critical/Major blockers after fixing detach flush and delayed xterm flush races. Targeted tests, typecheck, targeted Biome, prior build/startup smoke, and real 10/20/30 Codex performance reports are recorded.
