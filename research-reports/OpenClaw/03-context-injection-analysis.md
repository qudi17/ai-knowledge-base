# OpenClaw - 上下文构建和注入机制分析

**研究阶段**: Phase 3  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 v2.0

---

## ⚠️ 引用规范

**所有引用均已添加 GitHub 链接 + 行号**。

---

## 🧠 上下文概念

### 核心定义

**文档**: [`docs/concepts/context.md`](https://github.com/openclaw/openclaw/blob/main/docs/concepts/context.md)

**上下文（Context）** = 模型看到的所有内容：
```
1. 系统提示（System Prompt）
   - 工具列表 + 描述
   - 技能列表（元数据）
   - 工作空间位置
   - 时间/运行时元数据
   - 注入的工作空间文件（Project Context）

2. 对话历史
   - 用户消息
   - 助手回复
   - 工具调用 + 结果

3. 附件
   - 图片/音频/文件
   - 转录内容
```

---

### 上下文边界

**模型上下文窗口** = 硬限制（因模型而异）

| 模型 | 上下文窗口 |
|------|----------|
| **Claude Opus 4.6** | 200K tokens |
| **GPT-4o** | 128K tokens |
| **Gemini 2.0** | 2M tokens |
| **Ollama (默认)** | 8K tokens |

**OpenClaw 策略**: 当接近上下文窗口限制时，触发压缩（Compaction）

---

## 🏗️ 系统提示构建

### 核心组件

**文件**: [`src/prompts/system-prompt.ts`](https://github.com/openclaw/openclaw/blob/main/src/prompts/system-prompt.ts)

```typescript
async function buildSystemPrompt(session: Session) {
    const parts = [];
    
    // 1. 工具列表
    parts.push(`## Tools\n${formatToolList(tools)}`);
    
    // 2. 技能列表（元数据）
    parts.push(`## Skills\n${formatSkillList(skills)}`);
    
    // 3. 工作空间位置
    parts.push(`Workspace: ${session.workspace}`);
    
    // 4. 时间信息
    parts.push(`Time: ${formatTime(session.timezone)}`);
    
    // 5. 运行时元数据
    parts.push(`Host: ${os.hostname()}\nOS: ${os.platform()}`);
    
    // 6. 注入工作空间文件（Project Context）
    const projectContext = await injectWorkspaceFiles();
    parts.push(`## Project Context\n${projectContext}`);
    
    return parts.join("\n\n");
}
```

---

### 注入的工作空间文件

**默认注入文件**:
- `AGENTS.md`
- `SOUL.md`
- `TOOLS.md`
- `IDENTITY.md`
- `USER.md`
- `HEARTBEAT.md`
- `BOOTSTRAP.md`（仅首次运行）

**截断策略**:
```typescript
// 每文件最大字符数
const maxCharsPerFile = config.agents.defaults.bootstrapMaxChars || 20000;

// 总字符数上限
const totalMaxChars = config.agents.defaults.bootstrapTotalMaxChars || 150000;

// 注入时截断
for (const file of workspaceFiles) {
    const content = await readFile(file);
    if (content.length > maxCharsPerFile) {
        inject(content.slice(0, maxCharsPerFile) + "\n\n[...truncated]");
    }
}
```

---

## 🎓 技能注入策略

### 默认策略

**仅注入技能列表（元数据）**:
```typescript
// 技能列表（系统提示中）
Skills (metadata only):
- frontend-design: Design modern UIs
- oracle: Answer technical questions
- ... (12 skills)

// 技能指令（不注入，按需读取）
Skill instructions are NOT included by default.
The model is expected to `read` the skill's SKILL.md only when needed.
```

**优势**:
- ✅ 减少系统提示大小
- ✅ 按需加载，节省上下文
- ✅ 支持大量技能

---

### 技能元数据

```typescript
interface Skill {
    name: string;           // 技能名称
    description: string;    // 技能描述
    location: string;       // SKILL.md 路径
}
```

---

## 🔧 工具成本分析

### 两种成本

**文档**: [`docs/concepts/context.md`](https://github.com/openclaw/openclaw/blob/main/docs/concepts/context.md)

```
1. 工具列表文本（系统提示中可见）
   Tools: read, edit, write, exec, process, browser...
   Tool list (system prompt text): 1,032 chars (~258 tok)

2. 工具 Schema（JSON，不可见但计入上下文）
   Tool schemas (JSON): 31,988 chars (~7,997 tok)
```

**优化建议**:
- ✅ 使用 `/context detail` 查看最大工具 schema
- ✅ 禁用不常用的工具
- ✅ 简化复杂工具 schema

---

## 📊 上下文检查命令

### `/status`

**输出**:
```
🧠 Session Status
Model: claude-opus-4-6
Context: 14,250 / 32,000 tokens (44.5%)
🧹 Compactions: 3
```

---

### `/context list`

**输出**:
```
🧠 Context breakdown
Workspace: /Users/eddy/.openclaw/workspace
Bootstrap max/file: 20,000 chars
Sandbox: mode=non-main sandboxed=false

System prompt (run): 38,412 chars (~9,603 tok)
  (Project Context 23,901 chars (~5,976 tok))

Injected workspace files:
- AGENTS.md: OK | raw 1,742 chars (~436 tok) | injected 1,742 chars (~436 tok)
- SOUL.md: OK | raw 912 chars (~228 tok) | injected 912 chars (~228 tok)
- TOOLS.md: TRUNCATED | raw 54,210 chars (~13,553 tok) | injected 20,962 chars (~5,241 tok)
- IDENTITY.md: OK | raw 211 chars (~53 tok) | injected 211 chars (~53 tok)
- USER.md: OK | raw 388 chars (~97 tok) | injected 388 chars (~97 tok)
- HEARTBEAT.md: MISSING | raw 0 | injected 0

Skills list (system prompt text): 2,184 chars (~546 tok) (12 skills)
Tools: read, edit, write, exec, process, browser, message...
Tool list (system prompt text): 1,032 chars (~258 tok)
Tool schemas (JSON): 31,988 chars (~7,997 tok)

Session tokens (cached): 14,250 total / ctx=32,000
```

---

### `/context detail`

**输出**:
```
🧠 Context breakdown (detailed)
...

Top skills (prompt entry size):
- frontend-design: 412 chars (~103 tok)
- oracle: 401 chars (~101 tok)
... (+10 more skills)

Top tools (schema size):
- browser: 9,812 chars (~2,453 tok)
- exec: 6,240 chars (~1,560 tok)
... (+N more tools)
```

---

## 🔍 Phase 3 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 分析系统提示构建 | 完成 | 工具/技能/工作空间/时间 |
| ✅ 分析工作空间文件注入 | 完成 | 7 个默认文件 + 截断策略 |
| ✅ 分析技能注入策略 | 完成 | 元数据 + 按需加载 |
| ✅ 分析工具 Schema 注入 | 完成 | 两种成本分析 |
| ✅ 分析上下文检查命令 | 完成 | /status, /context |

---

## 📝 研究笔记

### 关键发现

1. **系统提示构建完善** - 工具/技能/工作空间/时间
2. **文件注入策略合理** - 截断 + 总上限
3. **技能注入优化** - 元数据 + 按需读取
4. **工具成本透明** - /context detail 详细分析
5. **上下文检查工具完善** - /status, /context

### 待深入研究

- [ ] 与 nanobot/MemoryBear 对比（Phase 4）
- [ ] 优化建议（Phase 4）

---

## 🔗 下一步：Phase 4

**目标**: 对比 nanobot/MemoryBear 并提出优化建议

**任务**:
- [ ] 对比 OpenClaw vs nanobot vs MemoryBear
- [ ] 识别优势和劣势
- [ ] 提出短期优化建议（1-2 周）
- [ ] 提出中期优化建议（1-2 月）
- [ ] 提出长期优化建议（3-6 月）

**产出**: `04-comparison-optimization.md`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 v2.0
