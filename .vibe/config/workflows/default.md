# Default Workflow DAG

```text
explore ──→ [design] ──→ tech ──→ plan ──→ exec ──→ test ──→ archive
             (可选)                               ↑        │
                                                  └── fix ──┘
```

## 阶段说明

- `explore`：确认背景、范围、功能需求和验收标准，生成 `prd.md`。
- `design`：可选但高优先的 UI 分支。页面改版、布局或信息架构调整、交互重排、响应式改造、视觉/组件规范更新等需求，应先在这里为当前 requirement 生成 `DESIGN.md`、`DESIGN.summary.md` 和设计摘要，再进入 `tech`；项目级 design system / tokens / component-library 只在显式命中共享升级条件时才生成。
- `tech`：确定技术方案，沉淀 decision 记忆。
- `plan`：把 PRD 和技术方案拆成原子任务。
- `exec`：按任务实施，必要时做 issue 记忆沉淀和执行检查点。
- `fix`：问题回环，只在 exec / test 暴露问题时进入。
- `test`：按 PRD 验收标准和 plan 范围做验证。
- `archive`：归档整个需求生命周期，沉淀 pattern 记忆。

## 转换条件

| 从 | 到 | 条件 |
|----|----|------|
| explore | design | `prd.md` 已生成，且需求命中 `design-first` 信号（如页面改版、布局/信息架构调整、关键交互改造、响应式或视觉规范变更） |
| explore | tech | `prd.md` 已生成，范围和验收标准可用，且需求不属于 `design-first` |
| design | tech | requirement-level `DESIGN.md` 或 `DESIGN.summary.md` 已生成 |
| tech | plan | `tech-spec.md` 已生成 |
| plan | exec | `plan.md` 已生成且任务可执行 |
| exec | test | 计划内任务基本完成 |
| exec | fix | 实施中出现需要单独修复的问题 |
| fix | exec | 修复完成并可回到实施主线 |
| test | fix | 测试未通过或质量门禁失败 |
| test | archive | 测试通过且质量门禁 READY |

## 门控原则

- `start / explore / design` 要在各自的 phase boundary 停止：先产出当前阶段产物，再由用户决定是否进入下一阶段；不要在同一条回复里串行执行多个阶段。
- `start`：只负责初始化需求目录与占位文件，完成后停止；下一步由用户手动运行 `/vibe:explore`。
- `explore`：必须先生成 `prd.md` / `requirements.md` / `after-explore.md`，完成后停止；只推荐 `design` 或 `tech`，不要自动继续。
- `design`：默认必须先生成 requirement-level `DESIGN.md`、`DESIGN.summary.md` 和 `after-design.md`，完成后停止；下一步仅建议 `/vibe:tech`。共享 `design tokens`、组件库摘要和项目级 `DESIGN.md` 只属于显式 `design-system upgrade` 路径。
- `explore → design`：命中 `design-first` 信号时优先进入 `design`，不要直接跳过。
- `explore → tech`：必须有可用的 PRD，且仅在不需要先做设计收敛时才可直进 `tech`；旧版需求可暂时降级使用 `requirements.md`，但应提示补跑 explore。
- `plan → exec`：任务要具备验证方式和完成标准。
- `test → archive`：不能跳过质量门禁。
- `fix` 不改变主工作流终点，只负责回环修复。

`design-first` 常见信号：
- 页面结构或左右布局重排
- 信息架构、内容分区、导航方式调整
- 关键交互流程、引导方式或结果呈现改版
- 响应式展示方案变化
- 视觉风格、组件规范或 design tokens 需要补齐 / 重做

`design-first` 的默认语义是“先做当前 requirement 的 UI 设计收敛”，不是自动进入项目级设计系统重构。

只有命中以下任一条件时，`design` 才升级为共享 `design-system upgrade` 路径：
- 用户明确要求“设计系统 / tokens / 组件规范重做”
- 需求影响多个页面或多个 requirements 的共享视觉规范
- 当前任务目标本身就是补齐项目级 design system 基础设施
- 设计变更已超出单需求 UI 范围，必须统一到项目层才能避免漂移
