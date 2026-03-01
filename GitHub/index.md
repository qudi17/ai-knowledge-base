# GitHub 项目研究 - Obsidian 索引

> 从优秀 GitHub 项目中提炼通用 RAG 和 Agent 方案

**创建日期**：2026-02-28  
**研究计划**：4 周完成 8 个项目分析  
**目标**：通用架构 + 可复用组件（<2,000 行）

---

## 📚 项目清单

### ✅ 已完成

| 项目 | 分析文档 | GitHub 链接 | 提炼组件 |
|------|---------|-----------|---------|
| **nanobot** | [[nanobot/分析报告\|分析报告]] | [GitHub](https://github.com/HKUDS/nanobot) | Agent Core, Tool System |

### ⏳ 进行中

| 项目 | 分析文档 | GitHub 链接 | 预计完成 |
|------|---------|-----------|---------|
| **langchain** | 待创建 | [GitHub](https://github.com/langchain-ai/langchain) | 2026-03-03 |
| **llama_index** | 待创建 | [GitHub](https://github.com/run-llama/llama_index) | 2026-03-05 |
| **dify** | 待创建 | [GitHub](https://github.com/langgenius/dify) | 2026-03-07 |

### 📋 计划中

| 项目 | 类型 | Stars | 优先级 |
|------|------|-------|-------|
| **auto-gen** | Multi-Agent | 25k+ | ⭐⭐ |
| **crewAI** | Role-Agent | 15k+ | ⭐⭐ |
| **openclaw** | Agent | - | ⭐⭐⭐ |

---

## 🎯 研究目标

### 产出物

1. **项目分析报告**（8 份）
   - [[nanobot/分析报告\|nanobot 分析]] ✅
   - langchain 分析 ⏳
   - llama_index 分析 ⏳
   - ...

2. **通用架构设计**
   - [[通用架构设计\|架构蓝图]]
   - Agent Core
   - RAG Pipeline
   - Tool System
   - Memory System

3. **可复用代码库**
   - [[../../🔧 技术专项/LiteLLM 缓存实施指南\|universal_agent]]

---

## 📊 进度追踪

```dataview
TABLE file.ctime as "创建日期", file.mtime as "最后更新"
FROM "GitHub"
WHERE file.name != "README"
SORT file.ctime DESC
```

### Week 1-2：核心项目

- [x] nanobot 分析（2/28 完成）
- [ ] langchain 分析（3/1-3/3）
- [ ] llama_index 分析（3/4-3/5）

### Week 3：应用类项目

- [ ] dify 分析（3/6-3/7）
- [ ] auto-gen 分析（3/8-3/9）
- [ ] crewAI 分析（3/10）

### Week 4：总结提炼

- [ ] openclaw 分析（3/11-3/12）
- [ ] 通用架构设计（3/13-3/14）
- [ ] 场景验证（3/15）

---

## 🔗 快速链接

### 研究文档

- [[项目分析模板]] - 标准化分析框架
- [[研究计划]] - 详细时间安排
- [[通用架构设计]] - 目标架构蓝图

### 相关笔记

- [[../../📰 技术博客追踪/工作流\|技术博客学习工作流]]
- [[../../🔧 技术专项/LiteLLM 缓存实施指南\|LiteLLM 缓存指南]]
- [[../../🔧 技术专项/Provider 特定功能对比\|Provider 功能对比]]

### 外部链接

- [nanobot GitHub](https://github.com/HKUDS/nanobot)
- [langchain GitHub](https://github.com/langchain-ai/langchain)
- [llama_index GitHub](https://github.com/run-llama/llama_index)
- [ai-knowledge-base GitHub 仓库](https://github.com/qudi17/ai-knowledge-base)

---

## 📝 文档规范

### 文件位置

```
GitHub/
├── README.md              # 总览（同步到 GitHub）
├── 项目分析模板.md         # 分析模板
├── 研究计划.md            # 时间安排
├── 通用架构设计.md         # 架构蓝图
└── <项目名>/
    ├── 分析报告.md         # 完整分析
    ├── 核心流程.md         # 流程图
    └── 可复用组件.md       # 提炼清单
```

### 代码引用格式

**行内代码**：
```markdown
使用 [`Agent.process_message()`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L123) 处理消息
```

**代码块**：
```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L191-L236
async def _run_agent_loop(self, messages):
    while iteration < max_iterations:
        response = await provider.chat(messages, tools)
```

### 双向链接

使用 `[[链接]]` 语法：
- [[nanobot/分析报告\|nanobot 分析]]
- [[通用架构设计\|架构设计]]

---

## 💡 使用技巧

### 在 Obsidian 中查看

1. **图谱视图**：查看所有研究的关联
2. **反向链接**：查看哪些笔记引用了当前项目
3. **搜索**：`path:GitHub/` 搜索所有研究文档

### 同步到 GitHub

```bash
cd /Users/eddy/.openclaw/workspace/ai-knowledge-base
git add .
git commit -m "更新：XXX"
git push
```

### 日常更新流程

1. 分析项目 → 更新 `GitHub/<项目名>/分析报告.md`
2. 提炼组件 → 更新 `universal_agent/`
3. 提交 GitHub → 自动同步到 Obsidian

---

## 📋 检查清单

### 每个项目分析前

- [ ] 克隆项目到本地
- [ ] 安装依赖并运行示例
- [ ] 复制 [[项目分析模板]] 到 `GitHub/<项目名>/`

### 每个项目分析后

- [ ] 完成分析文档
- [ ] 添加源码链接（GitHub URL）
- [ ] 提炼可复用组件
- [ ] 更新 [[研究计划\|进度追踪]]
- [ ] 提交到 GitHub

### 每周检查

- [ ] 完成本周计划
- [ ] 更新 [[研究计划\|研究计划]]
- [ ] 准备下周计划
- [ ] 同步到 GitHub

---

**最后更新**：2026-02-28  
**维护者**：Eddy  
**AI 助手**：Jarvis  
**同步状态**：✅ GitHub + Obsidian 已同步
