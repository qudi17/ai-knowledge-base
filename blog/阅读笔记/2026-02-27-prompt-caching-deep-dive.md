---
tags: [AI/Prompt Caching, AI/性能优化，架构/成本优化]
source: Anthropic Cookbook
url: https://platform.claude.com/cookbook/misc-prompt-caching
read_date: 2026-02-27
status: 已阅读
related: [Provider 特定功能对比，RAG 架构优化]
---

# Prompt Caching 深度解读

## 📌 一句话总结

Prompt Caching 通过缓存重复的上下文内容，实现**90% 成本折扣**和**3 倍速度提升**，是 RAG 系统必配的优化技术。

---

## 🔑 核心内容

### 1. 两种缓存模式

**自动缓存（推荐）**：
```python
response = client.messages.create(
    model="claude-sonnet-4-20250514",
    messages=[...],
    extra_headers={"anthropic-beta": "prompt-caching-2024-07-31"}
)
# 系统自动在最后一个可缓存块设置断点
```

**显式断点**：
```python
{
    "type": "text",
    "text": system_prompt,
    "cache_control": {"type": "ephemeral"}  # 手动指定缓存位置
}
```

### 2. 缓存机制

| 阶段 | 行为 | 价格 | 延迟 |
|------|------|------|------|
| **Cache Write** | 首次写入缓存 | 1.25x 基础价格 | 正常 |
| **Cache Read** | 从缓存读取 | 0.1x 基础价格 | **快 2-3 倍** |

### 3. 关键参数

- **最小缓存长度**：Sonnet 1K tokens，Opus/Haiku 4K tokens
- **TTL**：5 分钟（默认），1 小时（2x 价格）
- **断点数量**：最多 4 个显式断点
- **自动移动**：多轮对话断点自动前移

### 4. 多轮对话优化

```
请求 1: System + User:A → 缓存写入
请求 2: System + User:A（读缓存）+ Asst:B + User:C → 写入新内容
请求 3: System 通过 User:C（读缓存）+ Asst:D + User:E → 继续写入
```

**效果**：第一轮后，近 100% 输入 tokens 从缓存读取

---

## 🏗️ 架构师视角的洞察

### 1. 缓存命中率是关键

**高命中场景**（适合缓存）：
- ✅ RAG 系统（相同文档，不同问题）
- ✅ 多轮对话助手
- ✅ 批量处理相似任务
- ✅ 客服机器人（FAQ + 个性化）

**低命中场景**（不适合缓存）：
- ❌ 每次上下文都完全不同
- ❌ 查询间隔 > 5 分钟且无重复
- ❌ 上下文 < 1K tokens

### 2. 成本模型分析

**盈亏平衡点**：
```
缓存写入成本 = 1.25x × 静态内容 tokens
缓存读取节省 = 0.9x × 静态内容 tokens × 查询次数

盈亏平衡：1.25 = 0.9 × N
N ≈ 1.4 次查询
```

**结论**：同一份文档被查询 2 次以上就开始盈利

### 3. 缓存策略设计

**三层缓存架构**：
```
L1: 应用层缓存（Redis）
    - 完全相同的查询
    - TTL: 1 小时 - 24 小时
    - 命中率：10-30%

L2: Prompt Caching
    - 相同文档，不同问题
    - TTL: 5 分钟
    - 命中率：40-60%

L3: 向量检索 + LLM
    - 全新查询
    - 命中率：100%
```

---

## 💡 可落地的实践建议

### 公司业务场景（RAG 系统）

**立即实施**：
1. **系统提示词缓存**
   ```python
   # 始终缓存系统提示词
   {
       "role": "system",
       "content": "你是公司知识库助手...",
       "cache_control": {"type": "ephemeral"}
   }
   ```

2. **知识库文档缓存**
   ```python
   # 按文档类型分组缓存
   - 产品文档组（频繁查询）
   - 技术文档组（中等频率）
   - FAQ 组（高频，考虑 L1 缓存）
   ```

3. **监控指标**
   - Cache Hit Rate（目标：>50%）
   - 平均响应时间（目标：<2s）
   - 成本/查询（目标：降低 70%）

**中期优化**：
1. 实现智能缓存预热（预测高频文档）
2. 设计缓存失效策略（文档更新时）
3. 建立 A/B 测试框架（对比缓存效果）

### 个人使用场景

1. **Claude Code 项目**
   - 将项目规范写入 CLAUDE.md 并缓存
   - 多轮代码审查共享上下文

2. **个人知识库**
   - 常用文档预加载并缓存
   - 多问题探索同一文档

3. **自动化工作流**
   - 批量文档处理使用相同提示词
   - 利用缓存降低 API 成本

---

## 🔗 相关资源

- [Anthropic Prompt Caching 文档](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Cookbook 完整示例](https://platform.claude.com/cookbook/misc-prompt-caching)
- [OpenAI Prompt Caching](https://platform.openai.com/docs/guides/prompt-caching)

---

## 📝 阅读笔记

### 性能数据（实测）

| 场景 | 无缓存 | 缓存写入 | 缓存读取 | 提升 |
|------|--------|---------|---------|------|
| 单轮（187K tokens） | 4.89s | 4.28s | **1.48s** | **3.3x** |
| 多轮 Turn 1 | 5.19s | - | - | - |
| 多轮 Turn 2 | - | - | 8.27s | 缓存读取 187K tokens |
| 多轮 Turn 3 | - | - | 8.74s | 缓存读取 187K+ tokens |
| 多轮 Turn 4 | - | - | 7.06s | 缓存读取 187K+ tokens |

### 关键洞察

1. **多轮对话是缓存的最大受益者**：第一轮后，后续所有查询都从缓存读取
2. **自动缓存足够覆盖 80% 场景**：无需手动管理断点
3. **5 分钟 TTL 是合理的**：大多数对话在 5 分钟内完成
4. **1 小时 TTL 适合离线任务**：批量处理时值得 2x 价格

---

## ✅ 行动项

### 本周（2026-02-27 ~ 2026-03-05）

- [ ] 分析当前 RAG 系统的 token 分布
- [ ] 识别可缓存的静态内容（系统提示词 + 知识库文档）
- [ ] 实现 Prompt Caching POC（单个文档）
- [ ] 测量缓存前后的成本和延迟

### 下周（2026-03-05 ~ 2026-03-12）

- [ ] 扩展到全部知识库文档
- [ ] 实现缓存监控仪表板
- [ ] 设计缓存预热策略
- [ ] 编写团队分享文档

---

## 🔄 回顾记录

| 日期 | 进展 | 备注 |
|------|------|------|
| 2026-02-27 | 完成阅读和笔记 | 创建行动项 |
| | | |
