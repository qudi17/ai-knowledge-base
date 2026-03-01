# 🧠 费曼验证引导：Contextual Retrieval

**准备好开始验证了吗？**

我会通过一系列问题引导你解释这个技术。请**用自己的话回答**，不要看笔记！

---

## 第 1 轮：核心概念

### ❓ 问题 1

**请用一句话解释：什么是 Contextual Retrieval？**

要求：
- 不超过 50 字
- 让非技术人员能听懂

<details>
<summary>💡 参考要点（先自己想！）</summary>

- 是一种改进的 RAG 检索方法
- 核心是给每个文本块添加上下文信息
- 目的是提高检索准确率
</details>

---

### ❓ 问题 2

**传统 RAG 有什么问题？**

要求：
- 能举一个具体例子
- 说明为什么会导致检索失败

<details>
<summary>💡 参考要点</summary>

- 分块后丢失文档级上下文
- 例子：chunk 只说"公司收入增长 3%"，但没说哪个公司、哪个季度
- 用户问"ACME 公司 Q2 收入"时，找不到这个 chunk
</details>

---

### ❓ 问题 3

**Contextual Retrieval 的两个子技术是什么？**

<details>
<summary>💡 答案</summary>

1. **Contextual Embeddings**：添加上下文后做 embedding
2. **Contextual BM25**：添加上下文后创建 BM25 索引
</details>

---

## 第 2 轮：技术细节

### ❓ 问题 4

**上下文是如何生成的？**

要求：
- 说明用什么工具
- 说明输入是什么
- 说明输出是什么

<details>
<summary>💡 参考要点</summary>

- 工具：Claude（原文用 Haiku）
- 输入：完整文档 + 当前 chunk
- 输出：50-100 tokens 的上下文说明
- 用 prompt 让 LLM 生成
</details>

---

### ❓ 问题 5

**性能提升了多少？**

要求：
- Baseline 是多少
- Contextual Retrieval 是多少
- 加上 Reranking 是多少

<details>
<summary>💡 答案</summary>

- Baseline（仅 Embedding）：检索失败率 5.7%
- + Contextual Embeddings + BM25：2.9%（降低 49%）
- + Reranking：1.9%（降低 67%）
</details>

---

### ❓ 问题 6

**为什么 Contextual Retrieval 成本低？**

提示：Anthropic 提到了一个关键技术

<details>
<summary>💡 答案</summary>

**Prompt Caching**

- 文档只需加载到缓存一次
- 后续所有 chunks 复用缓存
- 成本：$1.02 / 百万文档 tokens（一次性）
</details>

---

## 第 3 轮：深度理解

### ❓ 问题 7

**Contextual Retrieval 和以下方法有什么区别？**

1. 添加通用文档摘要
2. Hypothetical Document Embedding
3. Summary-based Indexing

<details>
<summary>💡 答案</summary>

- 其他方法：通用摘要，不针对每个 chunk
- Contextual Retrieval：**chunk-specific** 的上下文
- 每个 chunk 的上下文都不同，更精确
</details>

---

### ❓ 问题 8

**Reranking 的作用是什么？为什么能进一步提升性能？**

<details>
<summary>💡 答案</summary>

- 作用：从大量候选（如 top-150）中精选最相关（如 top-20）
- 为什么有效：
  - 初步检索可能包含不相关信息
  - Reranking 模型更精确地评分
  - 减少 LLM 处理的 token 数，提高质量
</details>

---

### ❓ 问题 9

**如果让你实现 Contextual Retrieval，关键步骤是什么？**

<details>
<summary>💡 参考流程</summary>

1. 文档分块（~800 tokens）
2. 用 Claude 为每个 chunk 生成上下文
3. Prepend 上下文到 chunk
4. 创建 Embedding 和 BM25 索引
5. 检索时合并两者结果
6. （可选）Reranking 精选
</details>

---

## 第 4 轮：应用能力

### ❓ 问题 10

**场景题**：

你有一个公司内部知识库，包含：
- 10,000+ 篇技术文档
- 员工经常问技术问题
- 当前 RAG 系统检索准确率约 85%

**问题**：
1. 你会用 Contextual Retrieval 吗？为什么？
2. 预估能提升多少？
3. 实施成本如何？

<details>
<summary>💡 参考思路</summary>

1. **会用**，因为：
   - 技术文档有丰富的上下文信息
   - 当前准确率有提升空间
   - 文档量大，适合 RAG 优化

2. **预估提升**：
   - 检索失败率可能降低 40-60%
   - 最终准确率可能达到 90-95%

3. **成本**：
   - 一次性预处理：约 $10-20（10K 文档）
   - 存储成本略增（上下文 tokens）
   - 检索成本不变
</details>

---

### ❓ 问题 11

**如果用一句话向老板建议采用 Contextual Retrieval，你会怎么说？**

要求：
- 说明价值
- 说明成本
- 有说服力

<details>
<summary>💡 示例</summary>

"我们可以用 Anthropic 最新的技术，把 RAG 检索准确率从 85% 提升到 95%，一次性成本约 XX 元，之后没有额外开销，能显著减少员工查找信息的时间。"
</details>

---

## 📊 自我评估

完成以上问题后，请诚实评估：

| 维度 | 评分 | 说明 |
|------|------|------|
| 核心概念理解 | ⬜⬜⬜⬜⬜ | |
| 技术细节掌握 | ⬜⬜⬜⬜⬜ | |
| 性能数据记忆 | ⬜⬜⬜⬜⬜ | |
| 应用能力 | ⬜⬜⬜⬜⬜ | |

### 评分标准

- ⭐⭐⭐⭐⭐：能流畅回答所有问题
- ⭐⭐⭐⭐：大部分问题能回答，少数卡壳
- ⭐⭐⭐：核心问题能回答，细节模糊
- ⭐⭐：只能回答部分问题
- ⭐：需要重新学习

---

## 📝 理解盲区识别

**请列出你卡壳的问题**：

- [ ] 问题 X：[描述]
- [ ] 问题 X：[描述]

---

## 🔄 行动计划

### 需要补充学习

- [ ] 重新阅读 [章节]
- [ ] 查看 Cookbook
- [ ] 研究附录数据
- [ ] 实践实现

### 下次验证时间

⬜ 1 天后  ⬜ 3 天后  ⬜ 7 天后

---

**验证完成日期**：2026-XX-XX  
**验证结果**：⬜ 通过 ⬜ 部分通过 ⬜ 需重新学习
