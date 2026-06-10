# Decision: Multi-Agent Session Event Bus

## Context

多 Agent 卡顿来自每个 `useXterm` 独立订阅全局 `SESSION_DATA/EXIT/STATE`，任一 PTY 输出都会唤醒所有挂载终端后再按 sessionId 过滤。

## Decision

renderer 引入单一 session event bus：全局只注册一组 IPC listener，再按 `sessionId` 分发到目标消费者。`useXterm` 订阅指定 backend session，卸载时取消订阅。

## Consequences

- `SESSION_DATA` listener 数从 O(terminal count) 降为 O(1)。
- 需要严格 cleanup，避免 handler 泄漏。
- 可增加 subscriber count debug 作为性能验证证据。

