---
tags: [研究, Agent, AI分类]
created: 2026-02-26
---

# Anthropic Agentic Workflows

## 概述
Anthropic 提出了两种 Agentic 架构模式：Workflows（工作流）和 Agents（智能体）。Workflows 通过预定义的代码路径编排 LLM 和工具，流程固定可预测；Agents 则让 LLM 动态指导自身流程和工具使用，保持对任务完成方式的控制。

## 核心要点

### 两种类型对比

#### Workflows（工作流）
- **特点**：
  - 通过预定义的代码路径编排 LLM 和工具
  - 流程固定、可预测
  - 适合结构化、可预测任务

#### Agents（智能体）
- **特点**：
  - LLM 动态指导自身流程和工具使用
  - 保持对任务完成方式的控制
  - 适合灵活决策、模型驱动任务

### 选择建议
| 任务复杂度 | 推荐方案 | 说明 |
|-----------|---------|------|
| 简单任务 | 单个 LLM 调用 + RAG | 直接调用即可 |
| 复杂但明确 | Workflows | 流程固定，可预测 |
| 灵活决策 | Agents | 需要动态调整 |

### 推荐框架

#### Workflows（工作流）
- **LangChain LangGraph**：工作流编排
- **Rivet / Vellum**：GUI 工具

#### Agents（智能体）
- **Amazon Bedrock AI Agent**：智能体托管

## 参考资料
- 来源：MEMORY.md - 2026-02-22 会话记忆
- 相关文档：[[Agent相关]]
