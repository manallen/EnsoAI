# manifest.json Schema

用于描述项目级 Vibe 运行时状态，支持初始化幂等检查、升级判断、上下文热更新和高级特性开关。

## 文件位置

- Claude Code: `.vibe/manifest.json`
- Codex: `.vibe/manifest.json`

## 结构

```json
{
  "schema_version": 2,
  "vibe_version": "2.0.19",
  "initialized_at": "ISO-8601",
  "last_updated": "ISO-8601",
  "project_profile_hash": "sha256-8char",
  "features": {
    "context_system": true,
    "memory_system": true,
    "checkpoints": true,
    "design_system": true,
    "instincts": true
  },
  "platform": "claude-code | codex"
}
```

## 字段说明

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `schema_version` | number | `2` | 运行时清单版本。当前唯一权威版本是 `2`。 |
| `vibe_version` | string | `2.0.19` | 当前安装的 Vibe 工作流版本。 |
| `initialized_at` | string | 首次初始化时间 | 首次完成 `vibe:init` 的时间。 |
| `last_updated` | string | 最近写入时间 | 最近一次初始化、升级或强制重建后的更新时间。 |
| `project_profile_hash` | string | `sha256-8char` | `project-profile.md` 的摘要，用于判断全局上下文是否需要热更新。 |
| `features.context_system` | boolean | `true` | 是否启用上下文系统。 |
| `features.memory_system` | boolean | `true` | 是否启用记忆系统。 |
| `features.checkpoints` | boolean | `true` | 是否启用检查点系统。 |
| `features.design_system` | boolean | `true` | 是否启用设计系统目录和设计阶段支持。当前 `vibe:init` 默认启用设计系统；只有显式关闭时才为 `false`。 |
| `features.instincts` | boolean | `true` | 是否启用 instinct 系统。当前高级特性已支持，默认开启。 |
| `platform` | string | 当前平台值 | 用于区分 Claude Code 与 Codex 的路径差异。合法值：`claude-code`、`codex`。 |

## 初始化规则

### 新安装（无 manifest）

- 视为未初始化项目。
- `vibe:init` 需要生成新的 `manifest.json`。
- 生成后写入 `schema_version: 2`。

### 已有 v2 manifest

- 若未传 `--force`，命令应先做幂等检查。
- 若 `schema_version` 和当前版本一致，可直接读取并复用。
- 若 `project_profile_hash` 变化，应触发 `context/global.md` 的热更新。

### `--force`

- 保留已有运行时数据。
- 重新扫描项目并生成新的 `project-profile.md`。
- 更新 `project_profile_hash` 与 `last_updated`。

## 迁移规则

### 无 manifest → v2

- 场景：新项目或旧安装未使用 manifest。
- 动作：按 v2 结构全量创建。

### v1 → v2

- 当前仓库未落地 v1 文件结构，这里只保留升级预留。
- 若未来出现 `schema_version: 1`：
  - 保留原有 `initialized_at`；
  - 增补 `platform`、`features.design_system` 和 `features.instincts`；
  - 如旧项目没有 `memory/instincts/`，升级时一并创建；
  - 将 `schema_version` 升到 `2`；
  - 更新 `last_updated`。

## 高级特性说明

- `features.instincts = true` 时，`fix` 和 `exec` 允许读写 `memory/instincts/`。
- 记忆导出 / 导入不要求额外 manifest 字段，但导入前仍应校验 manifest 与 JSON schema 是否兼容。
- `project_profile_hash` 不是只用来提示，它也服务 `vibe:start` 的轻量热更新判断。

## 使用约束

- 所有命令都应先读 manifest，再决定是否需要初始化或升级。
- `platform` 只用于路径判断，不用于业务分支。
- shell 安装脚本只负责复制模板，不负责生成完整 manifest；完整内容由 `vibe:init` 负责。
