# Memory Management Rules

定义 Vibe 记忆系统的分类、写入、读取、衰减、整合以及跨项目导入导出规则。

## 目录结构

```text
memory/
├── MEMORY-INDEX.md
├── decisions/
├── patterns/
├── issues/
└── instincts/
```

## 记忆类型

### decisions

记录技术选型、架构权衡和被否决方案。

### patterns

记录可复用的代码模式、架构模式、项目经验。

### issues

记录可复用的问题模式、故障现象、已验证修复路径。

### instincts

记录已经稳定成 `trigger → action` 的快速修复本能，适合在 `fix` 阶段优先尝试。

## 标准记忆格式

```markdown
---
id: mem-001
type: decision | pattern | issue
created: 2026-04-08
last_accessed: 2026-04-08
access_count: 1
relevance_tags: [auth, jwt, security]
confidence: high | medium | low
source: vibe:tech session | vibe:fix session | vibe:archive session
---

# 标题

内容正文。

**Why:** 原因说明。
**How to apply:** 应用指导。
```

## Instinct 格式

```markdown
---
id: inst-001
type: instinct
created: 2026-04-08
last_accessed: 2026-04-08
access_count: 1
trigger: "错误特征描述"
domain: frontend | backend | data
action: "修复步骤"
evidence: "验证记录"
confidence: 0.0-1.0
source: vibe:fix session | promoted from issue
hit_count: 0
relevance_tags: [optional, tags]
---

# 标题

补充说明。
```

## MEMORY-INDEX.md 模板

```markdown
# Vibe Memory Index

## decisions/
- [mem-001](decisions/jwt-over-session.md) — JWT vs Session 选择 [auth, jwt]

## patterns/
(暂无)

## issues/
(暂无)

## instincts/
(暂无)
```

## 自动写入规则

| 触发阶段 | 记忆类型 | 写入位置 |
|----------|----------|----------|
| `tech` 完成 | decision | `memory/decisions/` |
| `exec` 修复通用错误后 | issue | `memory/issues/` |
| `fix` 修复成功后 | issue | `memory/issues/` |
| `fix` 修复形成稳定 `trigger → action` 路径时 | instinct | `memory/instincts/` |
| `exec` / `fix` 发现同类 issue 重复出现 | instinct promotion | `memory/instincts/` |
| `archive` 完成 | pattern | `memory/patterns/` |

写入原则：
- 默认自动写入，不额外要求用户确认。
- 阶段结束时用一句汇总提示用户新增了哪些记忆。
- 一次性 typo、纯路径错误、明显不可复用的临时现象，不应沉淀成记忆。
- instinct 比 issue 更严格，只有当修复路径已经稳定、可重复复用时才提升。

## 读取规则

- 所有记忆读取都必须先查 `MEMORY-INDEX.md`。
- `issues` 使用 `by_tag` 匹配。
- `instincts` 使用 `by_trigger` 匹配。
- 命中后：
  - `access_count + 1`
  - `last_accessed` 更新为当前日期
- 对 instinct 额外：
  - 每次实际命中并被采用时，`hit_count + 1`
- 不允许整库全量加载。

## 衰减规则

| 条件 | 动作 |
|------|------|
| `access_count = 0` 且 `age > 30 天` | 在 `vibe:init` 或 `vibe:init --force` 时提示为清理候选 |
| `MEMORY-INDEX.md > 50 条` | 在 `vibe:init` 或 `vibe:init --force` 时提示需要整合 |

说明：
- 衰减和整合只在 `vibe:init` 族命令里提示，不在每次写入时执行。
- 当前阶段只做提示，不做自动删除。

## 整合指导模板

当索引超过 50 条时，按以下顺序整理：

1. 优先合并 2-3 条低频、同标签、同类型的记忆。
2. 合并后的记忆必须保留原始来源引用，例如：`merged-from: mem-003, mem-011`。
3. 不自动删除：
   - `access_count > 3`
   - `confidence = high`
   - `hit_count > 2` 的 instinct
4. 如果无法稳定归纳共性，宁可保留原记忆。

## 导出 / 导入规则

### 导出

- 支持导出：`patterns`、`decisions`、`issues`、`instincts`
- 默认导出成 JSON 文件
- 导出文件最少包含：
  - `schema_version`
  - `type`
  - `exported_at`
  - `source_project`
  - `entries`

### 导入

- 导入前必须校验 JSON 结构和条目字段完整性。
- 目标目录按 `type` 决定，不允许把 `pattern` 导进 `issues/`。
- 同 id 同内容：跳过。
- 同 id 不同内容：保留本地版本，把导入版本标成冲突，不静默覆盖。
- 高相似条目：标成潜在重复项，默认不自动覆盖。
- 导入后必须同步更新 `MEMORY-INDEX.md`。

## 文件命名建议

- decisions：`{topic}-decision.md`
- patterns：`{pattern-name}.md`
- issues：`{issue-name}.md`
- instincts：`{trigger-name}-instinct.md`

要求：
- 文件名用英文 kebab-case
- 与 frontmatter 中的 `id` 分离，不依赖文件名排序

## 命令层约束

- `tech` 要沉淀 decision 记忆。
- `exec` / `fix` 要优先尝试命中的 issue 记忆。
- `fix` 诊断时还要尝试命中的 instinct。
- `fix` 修复成功后，除了 issue，还要判断是否提升为 instinct。
- `archive` 要沉淀 pattern 记忆。
- `/vibe:memory` 负责导出和导入，不直接替代日常自动沉淀。
