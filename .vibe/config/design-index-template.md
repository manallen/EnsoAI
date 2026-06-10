# Design Template Index

这里收录可用于 `vibe:design` 的参考模板索引。命令运行时可以先从这里匹配产品类型，再按需拉取模板正文并缓存到 `.vibe/design/.cache/`。

当前模板源固定到 fork 快照：`manallen/awesome-design-md@3c8fcd2c4ff70d30964de2317a01a26b580f8db8`，避免上游变动再次导致 `404`。

## 使用方式

1. 根据 `prd.md` 判断产品类型、目标用户和设计调性
2. 先选 2 个最匹配的模板
3. 优先读取缓存；没有缓存时再拉取远程原始 Markdown
4. 如果远程拉取失败，降级使用内置极简设计模板

## 模板索引

| ID | 适用产品 | 风格关键词 | Raw DESIGN.md URL |
|----|----------|------------|---------|
| `ai-assistant-minimal` | AI 助手 / Copilot | clean, dark, productivity | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/opencode.ai/DESIGN.md` |
| `saas-dashboard-pro` | SaaS 后台 | structured, neutral, data-heavy | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/sentry/DESIGN.md` |
| `fintech-trust` | 金融科技 | trust, calm, precise | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/coinbase/DESIGN.md` |
| `dev-platform-console` | 开发者平台 | technical, dense, modern | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/supabase/DESIGN.md` |
| `productivity-focus` | 效率工具 | lightweight, crisp, task-oriented | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/linear.app/DESIGN.md` |
| `community-warm` | 社区 / 内容产品 | warm, social, layered | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/intercom/DESIGN.md` |
| `consumer-mobile-bright` | 消费级移动端 | vivid, friendly, touch-first | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/airbnb/DESIGN.md` |
| `b2b-enterprise` | 企业工作台 | stable, modular, scalable | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/hashicorp/DESIGN.md` |
| `analytics-bento` | 数据分析产品 | bento, insight, metric-first | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/posthog/DESIGN.md` |
| `knowledge-base-calm` | 文档 / 知识库 | readable, calm, content-first | `https://raw.githubusercontent.com/manallen/awesome-design-md/3c8fcd2c4ff70d30964de2317a01a26b580f8db8/design-md/mintlify/DESIGN.md` |

## 缓存约定

建议缓存文件名：

```text
.vibe/design/.cache/<template-id>.md
```

如果缓存已存在，优先读缓存，不必重复联网。
