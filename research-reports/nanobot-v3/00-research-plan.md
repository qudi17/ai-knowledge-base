# nanobot-v3 - 研究计划书（新流程）

**研究日期**: 2026-03-02  
**研究者**: Jarvis (github-research skill v2.1)  
**项目**: https://github.com/HKUDS/nanobot  
**研究深度**: Level 5（完整性评分≥90%）

---

## 🎯 阶段 0.5: 需求澄清（Superpowers 整合）

### 研究目标确认

**研究目的**: 
- ✅ 验证 github-research skill v2.1 完整流程
- ✅ 深度理解 nanobot 架构设计
- ✅ 提取可复用的 Agent 框架设计模式
- ✅ 与 MemoryBear 对比，理解不同架构选择

**重点关注**:
1. **Agent 核心循环机制** - 如何平衡性能和功能
2. **工具系统设计** - 抽象基类 + 注册表模式
3. **Channel 抽象层** - 多平台统一接口
4. **会话管理** - 轻量级 JSONL vs 数据库

**对比项目**:
- MemoryBear（企业级记忆平台）
- LlamaIndex（待研究）
- Dify（已完成）

---

### Brainstorming 研究重点（Superpowers Brainstorming 技能）

**核心问题**:
1. nanobot 的核心创新是什么？
2. 为什么选择轻量级设计？
3. 如何支持 12+ 个 Channel 平台？
4. 工具系统的设计哲学是什么？

**研究假设**:
- **假设 1**: nanobot 采用"薄核心 + 可扩展"架构
- **假设 2**: 工具系统强调统一接口和类型安全
- **假设 3**: Channel 层采用适配器模式屏蔽平台差异

**验证方法**:
- 代码分析（核心模块完整阅读）
- 调用链追踪（3 个入口点）
- 设计模式识别
- 与 MemoryBear 对比

---

### 研究计划分块（Superpowers Writing Plans 技能）

#### 块 1: 核心架构分析（2 小时）
- [ ] 入口点普查（14 种扫描）
- [ ] 架构层次分析（5 层）
- [ ] 模块依赖图
- **产出**: `02-architecture-analysis.md`

#### 块 2: Agent 核心深度分析（3 小时）
- [ ] AgentLoop 完整代码分析
- [ ] ContextBuilder 流程追踪
- [ ] MemoryStore 机制分析
- [ ] SubagentManager 设计
- **产出**: `modules/agent-core-analysis-v3.md`

#### 块 3: 工具系统深度分析（2 小时）
- [ ] Tool 抽象基类分析
- [ ] ToolRegistry 注册机制
- [ ] 10 个内置工具逐一分析
- [ ] 参数验证系统
- **产出**: `modules/tool-system-analysis-v3.md`

#### 块 4: Channel 系统深度分析（3 小时）
- [ ] BaseChannel 抽象类
- [ ] 3 个典型 Channel 实现（Discord/Feishu/WebChat）
- [ ] 消息总线机制
- [ ] 平台差异处理
- **产出**: `modules/channel-system-analysis-v3.md`

#### 块 5: 调用链追踪（2 小时）
- [ ] CLI 启动流程
- [ ] 消息处理流程
- [ ] 工具执行流程
- **产出**: `04-call-chains.md`

#### 块 6: 对比分析（2 小时）
- [ ] nanobot vs MemoryBear 架构对比
- [ ] 工具系统对比
- [ ] Channel 系统对比
- [ ] 选型建议
- **产出**: `comparison/nanobot-vs-memorybear-v3.md`

#### 块 7: 完整性验证（1 小时）
- [ ] 代码覆盖率验证
- [ ] 完整性评分
- [ ] 文档审查
- **产出**: `07-code-coverage.md`, `08-summary.md`

---

## 📋 完整研究阶段（11+3 阶段）

| 阶段 | 名称 | 新增内容 | 预计时间 |
|------|------|---------|---------|
| **0** | 项目准备 | + 需求澄清 | 30 分钟 |
| **0.5** | Brainstorming | 🔥 Superpowers 技能 | 30 分钟 |
| **1** | 入口点普查 | 14 种扫描 | 30 分钟 |
| **2** | 模块化分析 | 依赖图生成 | 30 分钟 |
| **3** | 多入口点追踪 | 🔥 波次执行（GSD） | 2 小时 |
| **4** | 知识链路检查 | 5 环节分析 | 30 分钟 |
| **5** | 架构层次覆盖 | 5 层分析 | 30 分钟 |
| **6** | 代码覆盖率验证 | 统计 + 验证 | 30 分钟 |
| **7** | 深度分析 | 🔥 完整类定义 | 2 小时 |
| **8** | 完整性评分 | 🔥 两阶段审查 | 30 分钟 |
| **9** | 进度同步 | 🔥 原子提交 | 15 分钟 |
| **10** | 标签对比分析 | 对比汇总 | 1 小时 |

**总预计时间**: ~8 小时

---

## 🎯 验收标准（Level 5）

### 文档质量
- [ ] 所有代码片段完整（50-120 行类定义）
- [ ] 所有引用有 GitHub 链接 + 行号
- [ ] 所有模块有关键特性分析（3-5 个）
- [ ] 所有设计有决策理由（3-5 个"为什么"）
- [ ] 所有选择有权衡分析（优势 + 劣势）

### 研究深度
- [ ] 入口点普查≥3 个活跃
- [ ] 调用链追踪≥3 条完整
- [ ] 核心模块 100% 覆盖
- [ ] 设计模式识别≥5 个
- [ ] 完整性评分≥90%

### 流程规范
- [ ] 需求澄清完成
- [ ] Brainstorming 完成
- [ ] 研究计划分块验证
- [ ] 波次执行记录
- [ ] 两阶段审查记录
- [ ] 原子提交记录

---

## 📁 预期产出

### 主报告（9 篇）
```
research-reports/nanobot-v3/
├── 00-entrance-points-scan.md
├── 01-project-overview.md
├── 02-architecture-analysis.md
├── 03-module-analysis.md
├── 04-call-chains.md
├── 05-knowledge-link.md
├── 06-design-patterns.md
├── 07-code-coverage.md
└── 08-summary.md
```

### 模块深度分析（3 篇）
```
└── modules/
    ├── agent-core-analysis-v3.md
    ├── tool-system-analysis-v3.md
    └── channel-system-analysis-v3.md
```

### 对比报告（2 篇）
```
├── comparison/
│   └── nanobot-vs-memorybear-v3.md
└── final-report-v3.md
```

**总计**: 14 篇文档，预计~60KB

---

## 🏷️ 标签

**一级标签**: `Agent`, `Tool`, `Dev-Tool`
**二级标签**: `Async`, `Prompt-Eng`, `Lightweight`
**三级标签**: `Dev-Tool`, `Production`, `Multi-Platform`

---

## 📝 研究日志

### 2026-03-02 01:00 - 研究启动
- ✅ 需求澄清完成
- ✅ Brainstorming 完成
- ✅ 研究计划分块确认
- ✅ 开始阶段 1：入口点普查

**下一步**: 执行入口点普查（14 种扫描）

---

**研究状态**: 🔄 进行中  
**开始日期**: 2026-03-02  
**预计完成**: 2026-03-02  
**完整性目标**: ≥90% ⭐⭐⭐⭐⭐
