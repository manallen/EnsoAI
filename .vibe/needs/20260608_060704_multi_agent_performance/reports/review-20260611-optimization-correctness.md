# Review: 第一批性能优化正确性复核

- 日期: 2026-06-11
- 范围: `src/main/ipc/terminal.ts`, `src/preload/index.ts`, `src/renderer/hooks/useXterm.ts`, `src/renderer/hooks/useTerminal.ts`, `src/renderer/components/chat/AgentPanel.tsx`, `src/renderer/components/chat/QuickTerminalModal.tsx`, `src/renderer/components/terminal/TerminalPanel.tsx`
- 目标: 复核 PTY 数据合并、preload O(1) 分发、隐藏终端 `invisible` 优化，以及后续路线图判断是否有代码证据支撑

## 结论

**PASS with notes**。第一批代码优化方向正确，未发现 Critical/Major 级回归。主进程 PTY 合并、preload 单一分发器、渲染端按 id 订阅、隐藏终端从 `opacity-0` 改为 `invisible` 的实现整体成立。

已有报告里有两处表述需要收紧：

1. `pnpm lint` 全仓当前不通过，失败点是未触达的 `src/renderer/components/settings/HapiSettings.tsx:453` 格式问题。本批 7 个代码文件单独跑 `biome check` 通过。
2. `src/main/ipc/terminal.ts:132-158` 关于 `ptyId` 赋值早于首个 data 回调的假设符合 node-pty 通常异步行为，但代码层面没有强约束。低概率风险可接受，后续可通过让 `PtyManager.create()` 先生成 id 再注册 data 回调来消除。

## Findings

### Critical

无。

### Major

无。

### Minor

1. `DATA_FLUSH_MAX_BYTES` 命名不精确。
   `src/main/ipc/terminal.ts:17,55-57` 使用 `buffer.length` 判断，实际是 JS string code unit 数，不是真实字节数。性能保护目的仍成立，不影响正确性。

2. `destroyByWorkdir()` 绕过 batcher 清理。
   `src/main/ipc/worktree.ts:60` 和 `src/main/ipc/tempWorkspace.ts:216` 直接调用 `ptyManager.destroyByWorkdir()`，不会触发 `terminal.ts` 里的 `disposeBatcher(id)`。残留是 `dataBatchers` 的小闭包和空 buffer，频率低、体积小，接受；若要收干净，需要把 workdir 销毁也经过 terminal IPC 层的清理函数。

3. `ptyId` 捕获时序依赖 node-pty 异步 data。
   `src/main/ipc/terminal.ts:132-158` 先创建 batcher，闭包里发送 `{ id: ptyId }`，随后 `ptyManager.create()` 返回后才赋值。当前 `PtyManager.create()` 是 `pty.spawn()` 后注册 `onData()` 再返回，实际首包通常异步，不构成当前 blocker。

### Verification Notes

- `pnpm typecheck`: passed
- `pnpm vitest run`: passed, 34 tests
- `pnpm exec biome check <本批 7 个代码文件>`: passed
- `pnpm lint`: failed on unrelated formatting in `src/renderer/components/settings/HapiSettings.tsx:453`

## 通过项

1. PTY 数据合并逻辑保序。
   `createDataBatcher()` 首块立即 `send()`，后续 16ms 合并；同一 batcher 内同步 append 和 flush，不会重排单个 PTY 的输出。

2. exit 前 flush 方向正确。
   `src/main/ipc/terminal.ts:146-152` 先 `batcher.flush()`，再发 `TERMINAL_EXIT`，避免 renderer 先看到退出再看到尾部数据。

3. 主动 destroy 和窗口销毁清理有效。
   `TERMINAL_DESTROY` 调 `disposeBatcher(id)`；webContents destroyed 走 `disposeBatchersByOwner(ownerId)`；全局 shutdown 走 `disposeAllBatchers()`。

4. preload 分发器把 O(N) 过滤降为 O(1) 查表。
   `src/preload/index.ts:61-73` 单个 `ipcRenderer.on(TERMINAL_DATA)`，按 `event.id` 找 listener set；`onData(id, cb)` 解绑时空 set 删除。

5. renderer 调用链已正确迁移。
   `src/renderer/hooks/useXterm.ts:613-655` 直接订阅当前 `ptyId`，旧的 `event.id === ptyId` 分支移除；全仓没有 `useTerminalData` 调用残留。

6. `invisible` 替换是合理的隐藏终端 paint 优化。
   `AgentPanel`, `TerminalPanel`, `QuickTerminalModal` 都保留布局盒，配合 `pointer-events-none` 不接收交互。对 xterm fit/measure 比 `display: none` 安全。

## 路线图复核

后续路线图主要判断有代码证据支撑：

- Monaco 顶层 `await loader.init()` 和 Shiki 初始化确实在 `monacoSetup.ts` 模块求值期执行；`App.tsx` 通过 `components/files` 静态导入进入启动链路。
- renderer 配置没有 `manualChunks`，全仓未见 `React.lazy`，代码分割判断成立。
- main 进程 `shellEnvSync()` 是顶层 await，`autoStartHapi()` 在 `createMainWindow()` 前 await，启动阻塞判断成立。
- statusLine/hook 命令仍是 `node "<script>"`，title 更新没有等值守卫，WorktreePanel 和 TreeSidebar 均有 10s diff polling，运行时热点判断成立。

## 建议

可以继续推进第二批启动优化。第一批代码无需阻塞合入；如果想把实现再收紧，优先做两个小修：修正 `DATA_FLUSH_MAX_BYTES` 命名，给 `destroyByWorkdir()` 增加 batcher 清理通路。
