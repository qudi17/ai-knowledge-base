---
tags: [AI/Provider, AI/平台功能，架构/优化]
created: 2026-02-27
modified: 2026-02-27
status: 活文档
---

# Provider 特定功能对比

**目的**：追踪 Anthropic、OpenAI 等 Provider 的平台特定功能，优化 RAG 系统性能和成本

---

## 🎯 核心功能对比

### Prompt Caching

| 特性 | Anthropic | OpenAI | 应用建议 |
|------|-----------|--------|---------|
| 缓存折扣 | 90% OFF | 90% OFF | 优先用于静态内容 |
| 最小长度 | 1K/4K tokens | 1K tokens | Sonnet 最适合 |
| TTL | 5 分钟/1 小时 | 5 分钟 | 短对话用默认 |
| 多轮对话 | 自动移动断点 | 手动管理 | Anthropic 更简单 |

**RAG 收益**：成本降低 50-80%，延迟降低 2-3x

---

### Context Window

| 模型 | 上下文长度 | 价格 | 适用场景 |
|------|-----------|------|---------|
| Claude 3.7 Sonnet | 200K | $3/$15 | 长文档 RAG |
| GPT-4o | 128K | $2.5/$10 | 通用场景 |
| o1 | 200K | $15/$60 | 复杂推理 |

---

### Tool Use

| 特性 | Anthropic | OpenAI |
|------|-----------|--------|
| Function Calling | ✅ | ✅ |
| Parallel Calls | ✅ | ✅ |
| Computer Use | ✅ 独有 | ❌ |
| MCP 支持 | ✅ 原生 | ⚠️ 配置 |

---

### Embeddings

| 模型 | 维度 | 价格 | 性能 |
|------|------|------|------|
| text-embedding-3-large | 3072 | $0.00013/1K | 最佳 |
| text-embedding-3-small | 1536 | $0.00002/1K | 性价比 |

**注意**：Anthropic 不提供 Embedding，需配合 OpenAI 使用

---

## 💡 RAG 优化策略

### 策略 1：混合 Provider 架构

```
用户查询
    ↓
[路由层]
    ├── 简单问答 → Claude Haiku（缓存开启）
    ├── 复杂推理 → Claude Sonnet/Opus（缓存开启）
    ├── 需要 Embedding → OpenAI
    └── 需要图像 → GPT-4o/Claude
```

### 策略 2：三层缓存

```
L1: Redis 缓存（完全相同查询）
    ↓ Miss
L2: Prompt Caching（相同文档，不同问题）
    ↓ Miss
L3: 向量检索 + LLM 生成
```

### 策略 3：批量优化

- 非实时查询：使用 Batch API（50% 折扣）
- 多用户查询：合并请求，共享缓存
- 定期任务：离线处理，避开高峰

---

## 📊 成本计算模板

### Claude RAG 成本（带缓存）

假设：
- 系统提示词：5K tokens（缓存）
- 知识库文档：100K tokens（缓存）
- 用户问题：1K tokens（不缓存）
- 回答：2K tokens

**无缓存**：
```
输入：106K × $3/1M = $0.318
输出：2K × $15/1M = $0.03
总计：$0.348/查询
```

**有缓存（100 次查询）**：
```
缓存写入（1 次）：105K × $3.75/1M = $0.394
缓存读取（99 次）：105K × 99 × $0.3/1M = $3.119
问题部分（100 次）：1K × 100 × $3/1M = $0.3
输出（100 次）：2K × 100 × $15/1M = $3.0
总计：$6.813/100 查询 = $0.068/查询

节省：80.5%
```

---

## 🔗 关键资源

### Anthropic
- [Prompt Caching 文档](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Cookbook 示例](https://platform.claude.com/cookbook/misc-prompt-caching)
- [定价详情](https://www.anthropic.com/pricing)

### OpenAI
- [Prompt Caching](https://platform.openai.com/docs/guides/prompt-caching)
- [定价详情](https://openai.com/api/pricing/)

---

## 📝 更新日志

| 日期 | 更新内容 | 来源 |
|------|---------|------|
| 2026-02-27 | 初始版本，Prompt Caching 对比 | Anthropic Cookbook |

---

## ✅ 行动项

- [ ] 评估当前 RAG token 使用模式
- [ ] 实现 Prompt Caching POC
- [ ] 设计混合 Provider 架构
- [ ] 建立成本监控仪表板
