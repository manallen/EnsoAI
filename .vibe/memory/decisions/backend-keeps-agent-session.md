# Decision: Backend Keeps Agent Session, Frontend Mounts Xterm On Demand

## Context

当前 `AgentPanel` 通过挂载所有 AgentTerminal 保留会话，隐藏终端仍持有 xterm DOM、observer、scrollback 和 effects。

## Decision

保留后端 PTY / `SessionManager` replay buffer 作为 session continuity authority。前端只挂载当前可见、pending command 或短暂预热的 xterm；隐藏或切换只 detach renderer，不 kill PTY。

## Consequences

- 降低大量后台 xterm 的 DOM、observer 和 render cost。
- 切回需要 attach + replay + live 输出恢复。
- 必须严格区分 detach 和 kill，避免误杀 Agent。

