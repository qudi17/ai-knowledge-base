# Superpowers - Agentic Skills Framework 研究

**研究日期**: 2026-03-01  
**项目**: [obra/superpowers](https://github.com/obra/superpowers)  
**Stars**: 63,466 ⭐  
**分类**: 基础设施 / Agent / 开发者工具

---

## 📊 项目概览

### 核心定位

**Superpowers** 是一个完整的软件开发工作流，专为编码 Agent 设计，基于可组合的"技能"（skills）系统构建。

**核心理念**: 
> "你的编码 Agent  просто 拥有 Superpowers"

---

### 解决的问题

**传统 Agent 开发的问题**:
- ❌ 直接开始写代码，不理解真实需求
- ❌ 缺少系统设计阶段
- ❌ 没有清晰的实现计划
- ❌ 测试覆盖率低
- ❌ 缺少代码审查流程
- ❌ 无法长时间自主工作

**Superpowers 的解决方案**:
- ✅ 先理解需求，再设计方案
- ✅ 分块展示设计，便于消化
- ✅ 生成详细的实现计划（适合初级工程师跟随）
- ✅ 强调 TDD（红/绿/重构）
- ✅ 两阶段代码审查
- ✅ 支持数小时自主工作

---

## 🏗️ 核心架构

### 工作流程

```
1. 启动 Agent
   ↓
2. 需求澄清（Agent 询问真实目标）
   ↓
3. 设计阶段（Brainstorming Skill）
   - 通过问题细化需求
   - 探索替代方案
   - 分块展示设计供验证
   ↓
4. 计划阶段（Writing Plans Skill）
   - 分解为小任务（每个 2-5 分钟）
   - 包含精确文件路径
   - 包含完整代码示例
   - 包含验证步骤
   ↓
5. 实现阶段（Subagent-Driven Development）
   - 为每个任务启动子 Agent
   - 两阶段审查（规范合规性 → 代码质量）
   - 或批量执行 + 人工检查点
   ↓
6. 审查阶段（Requesting Code Review）
   - 对照计划审查
   - 按严重程度报告问题
   - 关键问题阻止进度
   ↓
7. 完成阶段（Finishing a Development Branch）
   - 验证测试
   - 提供选项（合并/PR/保留/丢弃）
   - 清理工作树
```

---

## 🎯 核心技能（Skills）

### 设计阶段

#### 1. Brainstorming
**触发时机**: 写代码之前  
**功能**: 
- 通过苏格拉底式提问细化粗糙想法
- 探索替代方案
- 分块展示设计供验证
- 保存设计文档

**示例触发**:
```
"help me plan this feature"
```

---

### 协作阶段

#### 2. Using Git Worktrees
**触发时机**: 设计批准后  
**功能**:
- 在新分支创建隔离工作区
- 运行项目设置
- 验证干净的测试基线

---

#### 3. Writing Plans
**触发时机**: 设计批准后  
**功能**:
- 将工作分解为小任务（每个 2-5 分钟）
- 每个任务包含：
  - 精确文件路径
  - 完整代码示例
  - 验证步骤
- 强调 YAGNI（你不会需要它）和 DRY

---

#### 4. Subagent-Driven Development
**触发时机**: 计划批准后  
**功能**:
- 为每个任务启动新鲜子 Agent
- 两阶段审查：
  1. 规范合规性审查
  2. 代码质量审查
- 支持批量执行 + 人工检查点

**示例触发**:
```
"let's debug this issue"
```

---

### 实现阶段

#### 5. Test-Driven Development
**触发时机**: 实现过程中  
**功能**:
- 强制执行 **RED-GREEN-REFACTOR** 循环：
  1. 写失败测试
  2. 观察失败
  3. 写最少代码
  4. 观察通过
  5. 提交
- 删除测试前写的代码

**核心原则**:
- 总是先写测试
- 测试驱动开发

---

#### 6. Requesting Code Review
**触发时机**: 任务之间  
**功能**:
- 对照计划审查代码
- 按严重程度报告问题
- 关键问题阻止进度

---

#### 7. Finishing a Development Branch
**触发时机**: 任务完成后  
**功能**:
- 验证测试
- 提供选项：
  - 合并到主分支
  - 创建 PR
  - 保留分支
  - 丢弃工作
- 清理工作树

---

## 🔧 技能分类

### 测试相关
- **test-driven-development** - RED-GREEN-REFACTOR 循环

### 调试相关
- **systematic-debugging** - 4 阶段根因分析流程
  - 根因追踪
  - 深度防御
  - 条件等待技术
- **verification-before-completion** - 确保真正修复

### 协作相关
- **brainstorming** - 苏格拉底式设计细化
- **writing-plans** - 详细实现计划
- **executing-plans** - 批量执行 + 检查点
- **dispatching-parallel-agents** - 并发子 Agent 工作流
- **requesting-code-review** - 预审查清单
- **receiving-code-review** - 响应反馈
- **using-git-worktrees** - 并行开发分支
- **finishing-a-development-branch** - 合并/PR 决策工作流
- **subagent-driven-development** - 快速迭代 + 两阶段审查

### 元技能
- **writing-skills** - 创建新技能的最佳实践
- **using-superpowers** - 技能系统介绍

---

## 💡 核心原则

### 1. Test-Driven Development
**写测试优先，总是**

- RED-GREEN-REFACTOR 循环
- 测试驱动开发
- 包含测试反模式参考

---

### 2. Systematic over Ad-hoc
**流程胜过猜测**

- 4 阶段根因分析
- 系统性调试
- 证据胜过声明

---

### 3. Complexity Reduction
**简单性作为首要目标**

- YAGNI（你不会需要它）
- DRY（不要重复自己）
- 简化复杂度

---

### 4. Evidence over Claims
**在声明成功前验证**

- 验证 before 完成
- 证据驱动
- 避免过早优化

---

## 🚀 安装与使用

### Claude Code

**步骤 1**: 注册市场
```bash
/plugin marketplace add obra/superpowers-marketplace
```

**步骤 2**: 安装插件
```bash
/plugin install superpowers@superpowers-marketplace
```

**步骤 3**: 更新插件
```bash
/plugin update superpowers
```

---

### Cursor Agent

**安装**:
```bash
/plugin-add superpowers
```

---

### Codex

**安装**:
```bash
Fetch and follow instructions from 
https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md
```

**详细文档**: [docs/README.codex.md](https://github.com/obra/superpowers/blob/main/docs/README.codex.md)

---

### OpenCode

**安装**:
```bash
Fetch and follow instructions from 
https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

**详细文档**: [docs/README.opencode.md](https://github.com/obra/superpowers/blob/main/docs/README.opencode.md)

---

## 📋 使用示例

### 示例 1: 新功能规划

**触发**:
```
"help me plan this feature"
```

**流程**:
1. ✅ Brainstorming Skill 激活
2. ✅ Agent 通过提问细化需求
3. ✅ 分块展示设计供验证
4. ✅ Writing Plans Skill 激活
5. ✅ 生成详细实现计划
6. ✅ Subagent-Driven Development 执行

---

### 示例 2: 问题调试

**触发**:
```
"let's debug this issue"
```

**流程**:
1. ✅ Systematic Debugging Skill 激活
2. ✅ 4 阶段根因分析
3. ✅ 验证修复
4. ✅ 添加测试防止回归

---

### 示例 3: 代码审查

**触发**: 任务完成后自动触发

**流程**:
1. ✅ Requesting Code Review Skill 激活
2. ✅ 对照计划审查
3. ✅ 按严重程度报告问题
4. ✅ 关键问题阻止进度

---

## 🎯 与 nanobot 对比

| 维度 | Superpowers | nanobot |
|------|------------|---------|
| **定位** | Agent 技能框架 | 轻量 Agent 框架 |
| **核心** | 可组合技能系统 | Agent 循环 + Channels |
| **适用** | 编码 Agent 工作流 | 个人助手 |
| **技能** | 15+ 预定义技能 | Skills 系统（自定义） |
| **测试** | 强制 TDD | 可选 |
| **审查** | 两阶段审查 | 无内置 |
| **自主性** | 数小时自主工作 | 交互式 |

---

## 💡 对 100 万研报场景的启示

### 可借鉴的设计

#### 1. 技能系统

**应用**: 为研报处理创建技能

```yaml
skills:
  - document-parsing: 解析 PDF/Word
  - chunking: 智能分块
  - contextual-embedding: 添加上下文
  - deduplication: 去重消歧
  - quality-verification: 质量验证
```

---

#### 2. 两阶段审查

**应用**: 研报质量保障

```
阶段 1: 规范合规性
- 检查是否包含公司名
- 检查是否包含时间
- 检查是否包含指标

阶段 2: 内容质量
- 数据准确性
- 格式一致性
- 上下文完整性
```

---

#### 3. TDD 思想

**应用**: 研报处理测试

```python
def test_report_parsing():
    # RED: 写失败测试
    assert parse_report(pdf).company == "贵州茅台"
    
    # GREEN: 写最少代码通过测试
    # REFACTOR: 重构优化
```

---

#### 4. 子 Agent 驱动

**应用**: 并行处理研报

```
主 Agent
    ↓
子 Agent 1: 解析 PDF
子 Agent 2: 提取表格
子 Agent 3: 生成上下文
子 Agent 4: 质量验证
    ↓
合并结果
```

---

## 📊 项目统计

| 指标 | 数值 |
|------|------|
| **Stars** | 63,466 ⭐ |
| **分类** | 基础设施 / Agent / 开发者工具 |
| **技能数** | 15+ |
| **许可证** | MIT |
| **作者** | Jesse (@obra) |
| **博客** | https://blog.fsck.com/2025/10/09/superpowers/ |

---

## 🔗 相关资源

### 官方资源
- **GitHub**: https://github.com/obra/superpowers
- **Marketplace**: https://github.com/obra/superpowers-marketplace
- **博客**: https://blog.fsck.com/2025/10/09/superpowers/

### 技能文档
- **Writing Skills**: skills/writing-skills/SKILL.md
- **TDD**: skills/test-driven-development/SKILL.md
- **Systematic Debugging**: skills/systematic-debugging/SKILL.md

---

## 🎯 研究状态

**状态**: 📝 待深入研究  
**优先级**: ⭐⭐⭐⭐⭐  
**下一步**: 
- [ ] 克隆项目到本地
- [ ] 分析技能实现代码
- [ ] 测试安装和使用
- [ ] 创建技能实现指南

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法（Yarn Ball Method）
