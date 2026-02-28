# GitHub 项目研究文档索引

**最后更新**：2026-02-28  
**研究方法**：[毛线团研究法](./research-methodology.md)  
**研究项目**：4 个（MemoryBear, nanobot, MarkItDown, 对比研究）  
**总文档**：24 篇，~400KB

---

## 📚 研究项目清单

### 1. MemoryBear（企业级记忆平台）

**项目链接**：https://github.com/qudi17/MemoryBear  
**研究文档**：[GitHub/MemoryBear/](./MemoryBear/)  
**代码规模**：650 个文件，~65,000 行  
**研究深度**：⭐⭐⭐⭐⭐（完整）

| 文档 | 大小 | 说明 |
|------|------|------|
| [analysis-report.md](./MemoryBear/analysis-report.md) | 15KB | 基础分析 |
| [api-call-chain-analysis.md](./MemoryBear/api-call-chain-analysis.md) | 18KB | API 调用链 |
| [complete-research-report.md](./MemoryBear/complete-research-report.md) | 23KB | 完整研究 |
| [prompts-collection.md](./MemoryBear/prompts-collection.md) | 18KB | 56 个 Prompt |
| [prompt-usage-mapping.md](./MemoryBear/prompt-usage-mapping.md) | 20KB | Prompt 使用映射 |
| [rag-retrieval-flow.md](./MemoryBear/rag-retrieval-flow.md) | 13KB | RAG 检索流程 |
| [neo4j-queries-forgetting-curve.md](./MemoryBear/neo4j-queries-forgetting-curve.md) | 24KB | Neo4j+ 遗忘曲线 |
| [reflection-forgetting-engines.md](./MemoryBear/reflection-forgetting-engines.md) | 29KB | 反思 + 遗忘调度器 |
| [research-summary.md](./MemoryBear/research-summary.md) | 18KB | 📝 研究总结 |

**核心发现**：
- ✅ 三层记忆架构（Neo4j+RAG+Redis）
- ✅ ACT-R 遗忘曲线实现
- ✅ 自我反思引擎
- ✅ LangGraph 工作流

---

### 2. nanobot（轻量 Agent 框架）

**项目链接**：https://github.com/HKUDS/nanobot  
**研究文档**：[GitHub/nanobot/](./nanobot/)  
**代码规模**：57 个文件，~7,336 行  
**研究深度**：⭐⭐⭐⭐⭐（完整）

| 文档 | 大小 | 说明 |
|------|------|------|
| [01-quickstart.md](./nanobot/01-quickstart.md) | 8.6KB | 快速入门 |
| [02-architecture.md](./nanobot/02-architecture.md) | 11.8KB | 架构概览 |
| [03-message-flow.md](./nanobot/03-message-flow.md) | 27.8KB | 消息流程 |
| [04-tool-system.md](./nanobot/04-tool-system.md) | 28.5KB | 工具系统 |
| [05-core-modules.md](./nanobot/05-core-modules.md) | 25.5KB | 核心模块 |
| [06-channels.md](./nanobot/06-channels.md) | 23.2KB | 11 个 Channels |
| [07-extension-guide.md](./nanobot/07-extension-guide.md) | 18.3KB | 扩展指南 |
| [08-skills-mechanism.md](./nanobot/08-skills-mechanism.md) | 15.5KB | Skills 机制 |
| [09-shell-execution.md](./nanobot/09-shell-execution.md) | 14.9KB | Shell 执行 |
| [analysis-report.md](./nanobot/analysis-report.md) | 15KB | 基础分析 |
| [research-summary.md](./nanobot/research-summary.md) | 24KB | 📝 研究总结 |

**核心发现**：
- ✅ 极简 Agent Loop（~700 行）
- ✅ 双层记忆系统（MEMORY.md + HISTORY.md）
- ✅ 11 个 Channels 开箱即用
- ✅ 工具注册器模式

---

### 3. MarkItDown（文档转换工具）

**项目链接**：https://github.com/qudi17/markitdown  
**研究文档**：[GitHub/markitdown/](./markitdown/)  
**代码规模**：55 个文件，~4,600 行  
**研究深度**：⭐⭐⭐⭐⭐（完整）

| 文档 | 大小 | 说明 |
|------|------|------|
| [01-markitdown-overview.md](./markitdown/01-markitdown-overview.md) | 15KB | 项目概览 |
| [02-converters-detail.md](./markitdown/02-converters-detail.md) | 12KB | 转换器详解 |
| [03-pdf-structure-extraction.md](./markitdown/03-pdf-structure-extraction.md) | 14KB | 📄 PDF 结构识别 |
| [research-summary.md](./markitdown/research-summary.md) | 17KB | 📝 研究总结 |

**核心发现**：
- ✅ 责任链模式 + 策略模式
- ✅ 25+ 个转换器
- ✅ 流式处理（无临时文件）
- ✅ 插件系统

---

### 4. 对比研究

**研究文档**：[GitHub/comparison/](./comparison/)  

| 文档 | 大小 | 说明 |
|------|------|------|
| [MemoryBear-vs-nanobot.md](./comparison/MemoryBear-vs-nanobot.md) | 16KB | 🆚 完整对比 |

**核心发现**：
- MemoryBear 适合企业知识库（完整记忆生命周期）
- nanobot 适合个人助手（轻量 + 多平台）
- 代码量差异：8.9 倍（65k vs 7.3k）
- 响应时间差异：nanobot 快 40%

---

## 🧶 研究方法论

### 毛线团研究法（Yarn Ball Method）

**核心理念**：
> 把 GitHub 项目当作一个**毛线团**：
> - **毛线头** = 入口（CLI/API）
> - **毛线** = 调用链
> - **毛线团** = 完整项目结构

**四步流程**：
1. **找线头**（入口点识别）
2. **顺线走**（调用链追踪）
3. **记路径**（流程图绘制）
4. **理结构**（模块关系图）

**详细文档**：[research-methodology.md](./research-methodology.md)

---

## 📊 研究统计

### 总体统计

| 指标 | 数值 |
|------|------|
| **研究项目数** | 4 个 |
| **总文档数** | 24 篇 |
| **总代码行** | ~77,000 行 |
| **总文档大小** | ~400KB |
| **平均研究深度** | ⭐⭐⭐⭐⭐ |

### 项目对比

| 项目 | 代码行 | 文档数 | 研究时长 | 完成度 |
|------|--------|--------|---------|-------|
| **MemoryBear** | ~65,000 | 9 篇 | ~12 小时 | 100% |
| **nanobot** | ~7,336 | 11 篇 | ~3 天 + 2 小时 | 100% |
| **MarkItDown** | ~4,600 | 3 篇 | ~2 小时 | 100% |
| **对比研究** | - | 1 篇 | ~1 小时 | 100% |

---

## 🔗 快速链接

### 研究方法论
- [毛线团研究法](./research-methodology.md) - 系统性 GitHub 项目研究方法

### 项目研究
- [MemoryBear 研究](./MemoryBear/) - 企业级记忆平台（9 篇）
- [nanobot 研究](./nanobot/) - 轻量 Agent 框架（11 篇）
- [MarkItDown 研究](./markitdown/) - 文档转换工具（3 篇）

### 对比研究
- [MemoryBear vs nanobot](./comparison/MemoryBear-vs-nanobot.md) - 完整对比

---

## 📝 更新日志

| 日期 | 更新内容 | 文档数 |
|------|---------|--------|
| 2026-02-28 | 创建 GitHub 项目研究索引 | 1 篇 |
| 2026-02-28 | 添加 MemoryBear 完整研究 | 9 篇 |
| 2026-02-28 | 添加 nanobot 完整研究 | 11 篇 |
| 2026-02-28 | 添加 MarkItDown 研究 | 3 篇 |
| 2026-02-28 | 添加对比研究 | 1 篇 |
| 2026-02-28 | 添加 MarkItDown PDF 结构研究 | 1 篇 |
| 2026-02-28 | 添加 MarkItDown PDF 图表研究 | 1 篇 |
| 2026-02-28 | 添加 MemoryBear 文件上传流程研究 | 1 篇 |

---

## 🎯 使用指南

### 快速入门

1. **阅读方法论**：[research-methodology.md](./research-methodology.md)
2. **选择项目**：根据兴趣选择 MemoryBear/nanobot/MarkItDown
3. **按顺序阅读**：每个项目的文档按编号顺序阅读（01→02→03...）
4. **查看总结**：最后阅读 research-summary.md 获取完整概览

### 进阶阅读

- **对比研究**：阅读 [MemoryBear-vs-nanobot.md](./comparison/MemoryBear-vs-nanobot.md) 了解架构差异
- **深入技术**：阅读具体技术文档（如 Neo4j 查询、遗忘曲线等）
- **代码参考**：所有文档都有 GitHub 源码链接

---

**研究状态**：✅ **持续更新中**  
**最后更新**：2026-02-28  
**维护者**：Jarvis
