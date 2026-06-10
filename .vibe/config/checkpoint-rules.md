# Checkpoint Rules

定义各阶段检查点的触发时机、文件格式和回退处理原则。

## 检查点触发时机

| 阶段 | 文件 |
|------|------|
| explore 完成 | `checkpoints/after-explore.md` |
| design 完成 | `checkpoints/after-design.md` |
| tech 完成 | `checkpoints/after-tech.md` |
| plan 完成 | `checkpoints/after-plan.md` |
| exec 风险/交接/批量恢复节点 | `checkpoints/exec-progress-{n}.md` |
| test 完成 | `checkpoints/after-test.md` |

说明：
- `fix` 不创建检查点，它是回环操作。
- `archive` 不创建检查点，它是终态。

## 检查点格式

```markdown
---
phase: explore | design | tech | plan | exec | test
created: ISO-8601
requirement: {req-name}
next_phase: design | tech | plan | exec | test | archive
artifacts:
  - file: prd.md
    status: generated
---

## 已确认约束
MUST: ...
SHOULD: ...

## 关键发现摘要
1. ...
2. ...
```

## 各阶段最低内容要求

### after-explore

- PRD 摘要
- MUST / SHOULD / MAY 计数
- 产出物状态：`prd.md`、`requirements.md`
- 推荐下一阶段：`design` 或 `tech`，并说明是否命中 `design-first`

### after-design

- 设计方向摘要
- 设计令牌产出状态
- 覆盖层情况（是否存在需求级 `DESIGN.md`）

### after-tech

- 核心技术方案摘要
- 关键技术决策列表
- decision 记忆写入结果

### after-plan

- 任务总数
- 关键依赖
- 预估工作量

### exec-progress-{n}

- 已完成任务列表
- 待完成任务列表
- 当前执行备注摘要

### after-test

- pass / fail / skip 数量
- 覆盖率
- 质量门禁结论

## 回退原则

回退通过 `vibe:rollback` 执行，不通过 `switch` 实现。

### 过期产出物处理

- 过期文件必须重命名保留，不直接删除。
- 推荐命名：`{name}.rollback-{timestamp}` 或 `before-rollback-{timestamp}`。
- 需求定义层（回退到 explore）应使用 `before-rollback`，避免和普通阶段回退混淆。

### `context.md` 回退策略

对目标阶段之后的结构化段落：

1. 保留原内容
2. 在段落附近插入 `<!-- rolled back at {timestamp} -->`
3. 在标题或内容中加 `[rolled-back]` 标记
4. 后续重新执行该阶段时，允许覆盖整段内容

### `## 回退记录` 段要求

至少记录：
- 回退时间
- 当前阶段 → 目标阶段
- 回退原因（如果有）
- 归档文件列表

## 统一归档映射原则

命令层在实现具体回退映射时，应遵守：

- 回退到 `tech`：至少归档 `plan.md` 及其后续产物
- 回退到 `plan`：至少归档 exec / test / archive 侧产物
- 回退到 `explore`：归档 `prd.md`、`requirements.md`、需求级 `DESIGN.md`（若存在）以及 explore 之后所有核心产物

## 命令层要求

- `rollback` 命令需要先验证目标阶段是否早于当前阶段。
- 当前阶段是 `fix` 时，要先给出风险警告。
- 回退到 `explore` 时，要明确进行二次确认。
- 检查点文件只记录状态快照，不直接承担主文档职责。
