# Review: 多 Agent 性能优化第一批（IPC 合并 + 分发器 + 隐藏终端 paint 消除）

- 日期: 2026-06-10
- 范围: 7 文件, +179/-60
- 验收项: ① 主进程 PTY 数据按会话合并发送 ② preload 单一分发器按 ptyId 路由 ③ 隐藏终端跳过 paint
- 模式: 主会话 inline review（全部 diff 文件已在上下文，未拉起独立 reviewer）
- 前序报告: `review-20260608-sessionmanager-iteration.md`（前一会话的 SessionManager 方案迭代，与本批实现无直接关联）

## 结论

**PASS** — 无 Critical/Major 问题，typecheck/biome/vitest 全部通过，建议继续。

## 问题分级

### Critical
无。

### Major
无。

### Minor

1. **`DATA_FLUSH_MAX_BYTES` 实际计量的是 UTF-16 code unit 数而非字节**
   `src/main/ipc/terminal.ts` — `buffer.length >= DATA_FLUSH_MAX_BYTES`。多字节字符场景下实际内存约为 2 倍（~128KB），不影响正确性，仅命名不精确。

2. **`destroyByWorkdir` 路径上 batcher Map 条目泄漏（已知接受）**
   `PtyManager.destroyByWorkdir()` 由 worktree 删除流程直接调用，绕过 `terminal.ts` 的 exit/destroy 钩子，对应 batcher 条目残留（每条 ~几十字节闭包，timer 最多 16ms 后自然结束，残余数据发往无监听的 id 被分发器 O(1) 丢弃，无副作用）。频率低、体积小，接受。

### Suggestion

- 渲染端 `useXterm` 的 30ms 合并窗口与主进程 16ms 窗口叠加，最坏回显延迟 ~46ms（首块立发机制下典型场景仍为 ~30ms，与改动前持平）。如后续有输入延迟反馈，可将渲染端 30ms 降为 1 个 rAF。

## 通过项

1. **数据顺序与 exit 时序正确**：batcher 同步 send 保序；exit 回调先 `flush()` 再发 `TERMINAL_EXIT`，渲染端永远先收数据后收退出。
2. **首块立发（leading-edge）设计**：空闲首 chunk 零延迟直发，回显延迟与改动前一致；持续输出时稳态 ≤2 条消息/16ms/终端，消息量降一个数量级以上。
3. **生命周期清理完整**：TERMINAL_DESTROY、exit 回调、sender destroyed（按 ownerId）、destroyAll/destroyAllAndWait 四条路径均清理 batcher；preload 侧监听 Set 空时删除 Map 条目。
4. **无监听时序回归**：`onData(ptyId, cb)` 注册发生在 `await create()` 同一 task 内，IPC 事件按 macrotask 排队，不会注册前丢数据（与旧实现一致）。
5. **`invisible` 替换 `opacity-0` 安全**：保留布局（xterm fit/measure 不受影响），跳过 paint/合成；QuickTerminalModal 配合 `transition-all`，visibility 在过渡末尾翻转，淡出动画保留；隐藏元素已 `pointer-events-none` 且无聚焦路径。
6. **死代码清理**：`useTerminalData`（全仓无调用方）随 API 改签名一并移除。
7. **验证**：`tsc --noEmit` ✓、`biome check`（7 文件）✓、`vitest run`（34 用例）✓。

## Non-blocking extras

1. AgentPanel 挂载所有跨仓库会话的架构未动（属后续优化范围，本批不扩面）。
2. `terminalRenderer` 默认仍为 `'dom'`（依赖后续 WebGL 池化才能安全改默认）。
3. 渲染端 onExit 仍为通配监听——exit 事件频率极低，无性能意义，保持现状。

## 需求合规结论

变更严格落在承诺的 2+3+1 三项内，未扩展到第 4 条（隐藏暂停写入）和第 5 条（WebGL 池化）。完成通知 / 空闲检测链路（`handleData`）不受影响——本批未改变数据到达渲染端的语义，仅减少消息条数与隐藏元素绘制。

## 设计一致性

无 UI 视觉变更，不适用。

## 建议

继续推进。后续第 4 条（后台暂停写入）实施时重点回归：后台 agent 完成通知、tab 标题更新、切 tab 后画面完整性。
