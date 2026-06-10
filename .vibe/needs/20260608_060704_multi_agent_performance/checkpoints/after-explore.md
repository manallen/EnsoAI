# After Explore Checkpoint

## PRD 摘要

本需求聚焦 EnsoAI 多 Codex / Claude Agent 并行时的卡顿。源码探索显示主要瓶颈来自：所有 AgentTerminal 长期挂载、每个 xterm 独立订阅全局 IPC、主进程 PTY chunk 直接发送、隐藏 xterm 持续持有 DOM/observer/scrollback、活动检测频繁系统调用，以及默认 DOM renderer + 10000 scrollback。

## 约束计数

- MUST: 7
- SHOULD: 5
- MAY: 3

## 关键发现

- 后台保活应该迁移到后端 session / replay buffer，而不是靠隐藏完整 xterm。
- renderer 应使用单一 session IPC 订阅并按 sessionId 分发。
- 主进程应按 session 短窗口批量合并输出，减少 `webContents.send`。
- 不可见 session 应只维护轻量状态，不持续 `terminal.write`。
- 性能改造必须配套基准，覆盖 1/4/8/12 Agent。

## 产出物状态

- `prd.md`: generated
- `prd.summary.md`: refreshed
- `requirements.md`: extracted_from_prd
- `context.md`: explore findings updated

## 推荐下一阶段

推荐进入 `tech`。

原因：这是前端/主进程数据通路和 session 生命周期优化，不是页面改版或视觉设计优先事项。下一阶段需要评估具体技术方案：全局 IPC 分发层、后台 session detach/attach 语义、replay 恢复策略、主进程批量窗口、活动检测降频策略和性能基准实现。

