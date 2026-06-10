# Global Context

EnsoAI 是 Git Worktree 管理器 + 多 AI Agent 集成应用，技术栈为 Electron 39、React 19、TypeScript 5.9、Tailwind 4、Zustand、node-pty 和 xterm.js。

关键目录：
- `src/main/`: Electron 主进程、IPC、服务和原生模块集成。
- `src/preload/`: context bridge，暴露 `window.electronAPI`。
- `src/renderer/`: React 前端、组件、stores 和 hooks。
- `src/shared/`: 跨进程共享类型。

终端链路：
- 后端 PTY 管理在 `src/main/services/terminal/PtyManager.ts`。
- 统一 session 生命周期和 replay buffer 在 `src/main/services/session/SessionManager.ts`。
- renderer xterm 集成在 `src/renderer/hooks/useXterm.ts`。
- Agent UI 和多 session/group 管理在 `src/renderer/components/chat/AgentPanel.tsx`、`AgentTerminal.tsx`。

约束：
- Biome 替代 ESLint/Prettier。
- 禁止 `as any` / `@ts-ignore`。
- UI 优先复用现有组件和项目设计约定。
- 不直接修改 `globals.css` 主题；终端和主题走现有设置机制。
- 质量检查命令：`pnpm typecheck`、`pnpm lint`、必要时 `pnpm test`。

