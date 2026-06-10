# Decision: Per-Session Output Batching

## Context

`SessionManager` 当前按 PTY chunk 直接 `webContents.send(session:data)`，高频输出会造成大量 IPC 消息。

## Decision

在主进程按 session 维护 pending output buffer，使用 16-33ms 短窗口批量 flush。exit 前必须先 flush data，再发送 exit。

## Consequences

- 降低 `webContents.send` 次数。
- 窗口过大会影响 TUI 实时性，必须通过性能测试校准。
- replay buffer 与 live output 必须保序。

