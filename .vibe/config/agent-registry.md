# Agent Registry

记录当前仓库内 Agent 的分类、能力和适用阶段。

## workflow

### vibe-explorer
- category: workflow
- capabilities: 需求探索、约束提取、问题生成
- inputs: 用户描述、搜索结果、探索上下文
- outputs: 结构化约束、探索发现
- phases: explore
- standalone: 否

### vibe-reviewer
- category: workflow
- capabilities: 代码质量审查、安全/性能/结构检查、设计一致性审查
- inputs: 代码变更、计划文件、技术决策、设计规范
- outputs: 审查报告、问题分级、改进建议
- phases: exec, review
- standalone: 是

### vibe-evidence-collector
- category: workflow
- capabilities: 规格和证据交叉验证、Done 标准核对、测试结果归集
- inputs: 任务定义、验证结果、测试输出
- outputs: 功能正确性结论、证据清单
- phases: exec, test
- standalone: 否

## architecture

### vibe-architect
- category: architecture
- capabilities: 架构设计、模块拆分、技术方案评估
- inputs: 需求约束、项目结构、技术候选
- outputs: 架构建议、设计权衡
- phases: tech
- standalone: 是

### vibe-ux-architect
- category: architecture
- capabilities: CSS 架构、设计令牌落地、组件样式组织
- inputs: 设计需求、前端技术栈、样式方案
- outputs: 前端样式架构建议
- phases: tech, exec
- standalone: 是

## quality

### vibe-adversary
- category: quality
- capabilities: 挑战假设、发现边界情况、指出逻辑漏洞
- inputs: 需求文档、方案、计划
- outputs: 反驳点、风险清单
- phases: explore, tech, plan
- standalone: 否

### vibe-reality-checker
- category: quality
- capabilities: 规格与测试证据交叉验证、最终质量门禁
- inputs: 测试报告、成功判据、硬约束
- outputs: READY / NEEDS WORK 判定
- phases: test
- standalone: 否

### vibe-security-engineer
- category: quality
- capabilities: 安全审查、漏洞识别、安全风险提示
- inputs: 安全相关代码、验证结果、任务说明
- outputs: 安全问题报告
- phases: exec, review
- standalone: 是

## design

### vibe-ui-designer
- category: design
- capabilities: 视觉方向、界面风格、UI 优化建议
- inputs: 产品定位、界面目标、竞品观察
- outputs: 视觉建议、组件规范
- phases: explore, design
- standalone: 是

### vibe-ux-researcher
- category: design
- capabilities: 用户研究、可用性分析、用户画像
- inputs: 产品需求、目标用户、竞品信息
- outputs: 研究结论、用户洞察
- phases: explore, design
- standalone: 是

### vibe-ui-architect
- category: design
- capabilities: 解读 `DESIGN.md`、提取 design tokens、映射到前端技术栈、检查 UI 反模式
- inputs: `DESIGN.md`、design tokens、前端技术栈、UI 反模式记忆
- outputs: 前端设计落地方案、样式令牌映射建议
- phases: design, tech, exec
- standalone: 是

## seo

### vibe-seo-auditor
- category: seo
- capabilities: SEO 审计、站点问题诊断
- inputs: URL、页面抓取结果、站点结构
- outputs: SEO 审计报告
- phases: independent tool
- standalone: 是

### vibe-seo-specialist
- category: seo
- capabilities: SEO 策略制定、关键词和内容建议
- inputs: 业务目标、竞品信息、站点现状
- outputs: SEO 策略方案
- phases: independent tool
- standalone: 是

## research

### vibe-trend-researcher
- category: research
- capabilities: 趋势研究、竞品趋势、行业动态收集
- inputs: 产品方向、搜索主题
- outputs: 趋势摘要、来源列表
- phases: explore, tech
- standalone: 是

### vibe-executive-summary
- category: research
- capabilities: 生成执行摘要、归档摘要
- inputs: 需求文档、技术方案、执行结果
- outputs: SCQA 摘要、项目总结
- phases: archive
- standalone: 否
