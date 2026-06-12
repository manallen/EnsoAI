# 优化路线图（第二批起）

- 日期: 2026-06-10
- 目标: ① 启动快 ② 开 10+ agent 不卡
- 依据: 两路代码深度探索（启动链路 / 随会话数放大的运行时热点），证据均为 file:line

## A. 启动链路（按收益排序）

### A1. Monaco 顶层 await 阻塞首帧（最大头）🔴
`src/renderer/components/files/monacoSetup.ts:35,59-67,82` — 模块顶层 `await loader.init()` + 预创建 19 个语言 model + shiki highlighter 初始化。该模块经 `components/files/index.ts:2` ← `App.tsx:50` 静态进入入口 chunk，**React 连空壳都渲染不了，窗口 ready-to-show 一直等它**。
→ 改为导出 `initMonaco()` 异步函数；EditorArea/DiffViewer/MergeEditor/DiffReviewModal 用 `React.lazy`；19 个 model 预热和 shiki 移到 `requestIdleCallback` 或首次打开编辑器时。

### A2. 零代码分割，Monaco+xterm+shiki 全在入口 chunk 🔴
`electron.vite.config.ts:36-52` 无 manualChunks；全仓无任何 `React.lazy`。入口含 monaco-editor 全量 ESM（~3-4MB parse/eval）、xterm+5 addons、shiki、framer-motion、emoji-picker 等。
→ MainContent 各 tab 面板（Terminal/Settings/SourceControl/Todo）按 activeTab 懒加载；配 manualChunks（monaco/xterm/vendor）。

### A3. main 进程 `shellEnvSync()` 顶层 await 🔴
`src/main/index.ts:25-32` — 同步 spawn 交互式登录 shell 取 env，重 zshrc 下 200ms–2s+，门控整个主进程模块求值。
→ 改异步并与 `app.whenReady()` 并行；或缓存到 userData、后台刷新（PTY 路径已有自己的 PATH 增强兜底 `PtyManager.ts:286-365`）。

### A4. `autoStartHapi()` 在创建窗口之前 await 🔴（开启 hapi 时）
`src/main/index.ts:627` — hapi server 启动 + `waitForHapiReady` 最多 30s 轮询 + runner/cloudflared，全部发生在 `createMainWindow()`（:631）之前，期间无窗口。
→ 移到窗口创建后 fire-and-forget。

### A5. 启动期杂项 🟡
- `await checkGitInstalled()`（index.ts:303，仅打日志）与 `await cleanupTempFiles()`（:326）串行 → 改 fire-and-forget。
- electron-updater 被 `src/main/ipc/index.ts:3` 顶层 import，废掉了 index.ts:280 的动态导入 → 恢复懒加载；sqlite3（ipc/todo.ts:6）同理可动态导入。
- BrowserWindow 未设 `backgroundColor`（MainWindow.ts:70-94），index.html 硬编码 `class="dark"` → 浅色用户有暗色闪烁。
- 设置 store 经 IPC 异步 hydration，首帧用默认值 → 主题/布局闪烁（stores/settings/storage.ts:6-12）→ localStorage 存一份 theme/layout 小快照供同步首读。
- TreeSidebar 两个 hook 实例重复查询全部 repo 的 worktree（TreeSidebar.tsx:230-232，query key 不同），启动时 `git worktree list` 子进程数 ×2 → 合并查询。

## B. 多 Agent 运行时（第一批已完成 IPC 合并/分发器/invisible；第 4/5 条已规划）

### B1. statusLine/hook 每次事件 spawn 一个完整 node 进程 🔴 HIGH
`ClaudeHookManager.ts:578-582`（statusLine）、`:293-299`（hook：Stop/UserPromptSubmit/PermissionRequest/PostToolUse）。Claude 流式输出期间 statusLine 高频刷新，每次 = 一次 Node 冷启动（50-150ms CPU、30-50MB 瞬时 RSS）+ readdirSync 锁文件 + HTTP POST。10 个会话 = 持续的进程风暴。
→ 换成 sh+curl 零运行时脚本，或常驻 helper 进程走 socket；端口可安装时固化。

### B2. terminalTitle 变更无等值守卫 → 全局重渲染 + 同步 localStorage 写 🔴 HIGH
`AgentPanel.tsx:1754-1764` 无 `title === session.terminalTitle` 检查；`agentSessions.ts:251-254` updateSession 重建整个 sessions 数组；触发持久化订阅（:581-587，JSON.stringify 全量 + 同步 localStorage.setItem）+ AgentPanel 全量重渲染（N 个未 memo 的 AgentTerminal，props 全是内联闭包）+ MainContent/RunningProjectsPopover/agentTasks 联动。Claude/codex 工作时频繁改 OSC 标题。
→ 等值早退；terminalTitle 移入 runtimeStates（非持久化）；AgentTerminal 包 React.memo + 稳定回调。

### B3. 内存：10000 行 scrollback × N + tmux 双份历史 🔴 HIGH
默认 scrollback 10000（settings/index.ts:117），每实例 10-25MB；tmux 包裹（AgentTerminal.tsx:409-423）又在 tmux server 里存 2000 行/pane。
→ 隐藏终端运行时把 `options.scrollback` 收缩到 1-2k、激活恢复；tmux 命令加 history-limit 0（xterm 已有历史）。

### B4. 隐藏会话全量解析（= 既定第 4 条）+ WebGL 池化（= 既定第 5 条）🔴
useXterm.ts:613-655 不分可见性照常 write。维持原计划：隐藏排队 + 激活 flush + resize 抖动兜底；WebGL 仅可见终端持有，随后默认渲染器改 webgl。

### B5. resize/focus 事件 N 倍放大 🟡 MEDIUM
useXterm.ts:794-815 每终端一份 window.resize + ResizeObserver；:849-868 每次 visibilitychange/focus 全部终端 full refresh。
→ 不可见终端跳过 fit/refresh（IntersectionObserver 状态已有现成接线）。

### B6. 双面板重复 10s git diff 轮询 🟡 MEDIUM
WorktreePanel.tsx:184-200 与 TreeSidebar.tsx:320-338 各自对所有活跃 worktree 每 10s `git diff --stat`，且依赖 activities 导致 interval 频繁重置；WorktreeRow 订阅整个 map，每 tick 全行重渲染。
→ 收敛为 store 级单一调度器；等值跳过 set；行选择器窄化。

### B7. 其他 🟢 LOW-MEDIUM
- glow 聚合选择器 O(sessions) × 订阅行数，且 enhanced input 每键触发 store 变更（useOutputState.ts:14-39）→ store 内预计算 per-path 状态。
- 4 个独立 onAgentStop 监听各自 O(N) find → 单一分发 + sessionId Map。
- 文件 watcher ignore 列表过窄（仅 node_modules/.git/dist/out），agent 高频写盘时 git status 失效风暴 → 扩 ignore + 动态加长 debounce。
- worktreeActivity 每次状态迁移 console.log → 删除。

## 建议批次

- **第二批（启动）**: A1 + A2 + A3 + A4 + A5（预期冷启动从"秒级白屏"降到主要受 Electron 自身启动限制）
- **第三批（运行时高优）**: B1 + B2 + B4（既定第 4/5 条）
- **第四批（打磨）**: B3 + B5 + B6 + B7
