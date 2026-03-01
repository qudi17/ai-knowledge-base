# OpenClaw 上下文管理深度研究

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**研究对象**: OpenClaw Gateway (https://github.com/openclaw/openclaw)

---

## 📊 OpenClaw 架构概览

### 核心定位

**OpenClaw** 是一个个人 AI 助手，运行在用户自己的设备上，支持多频道（WhatsApp、Telegram、Slack、Discord 等）。

**GitHub**: https://github.com/openclaw/openclaw  
**核心组件**: Gateway（控制平面）+ Channels（通信渠道）+ Skills（技能系统）

---

## 🧠 上下文管理架构

### 核心概念

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

## 🧹 压缩机制（Compaction）

### 核心思想

```
压缩前:
[消息 1][消息 2]...[消息 50][消息 51]...[消息 100]
(100 条消息，超出上下文窗口)

压缩后:
[压缩摘要：消息 1-80][消息 81]...[消息 100]
(摘要 + 最近 20 条，符合上下文窗口)
```

---

### 压缩类型

#### 1. 自动压缩（Auto-Compaction）

**触发条件**:
```typescript
// 当会话接近或超过模型上下文窗口时
if (sessionTokens > contextWindow * 0.9) {
    triggerAutoCompaction();
}
```

**行为**:
- ✅ 压缩旧对话为摘要
- ✅ 保留最近消息完整
- ✅ 摘要持久化到 JSONL 历史
- ✅ 可能重试原始请求

**用户可见**:
- 详细模式：`🧹 Auto-compaction complete`
- `/status` 显示：`🧹 Compactions: <count>`

---

#### 2. 手动压缩（Manual Compaction）

**命令**: `/compact [instructions]`

**示例**:
```
/compact 关注决策和未解决问题
/compact 总结技术讨论，保留代码示例
```

**实现**:
```typescript
// src/commands/compact.ts
async function compact(sessionId: string, instructions?: string) {
    const transcript = await loadTranscript(sessionId);
    
    // 调用 LLM 生成摘要
    const summary = await llm.summarize(transcript, {
        instructions: instructions || "总结关键信息"
    });
    
    // 插入压缩条目
    await insertCompactionEntry(sessionId, {
        type: "compaction",
        summary: summary,
        firstKeptEntryId: transcript.recent[0].id,
        tokensBefore: transcript.oldTokens
    });
}
```

---

### 压缩 vs 修剪

| 维度 | 压缩（Compaction） | 修剪（Pruning） |
|------|-----------------|---------------|
| **持久化** | ✅ 持久化到 JSONL | ❌ 仅内存中 |
| **内容** | 摘要旧对话 | 删除旧工具结果 |
| **触发** | 接近上下文窗口 | 每次请求前 |
| **可逆** | ❌ 不可逆 | ✅ 下次请求恢复 |

---

## 📁 会话存储架构

### 两层持久化

```
1. 会话存储（sessions.json）
   - Key/Value 映射：sessionKey → SessionEntry
   - 小型、可变、安全编辑
   - 跟踪会话元数据

2. 转录文件（*.jsonl）
   - 追加式转录（树状结构）
   - 存储实际对话 + 工具调用 + 压缩摘要
   - 用于重建模型上下文
```

---

### 磁盘位置

```
~/.openclaw/agents/<agentId>/sessions/
├── sessions.json              # 会话存储
├── <sessionId>.jsonl          # 主会话转录
├── <sessionId>-topic-<threadId>.jsonl  # Telegram 主题会话
└── *.reset.<timestamp>        # 重置归档
```

---

### 会话存储 Schema

```typescript
interface SessionEntry {
    sessionId: string;              // 当前转录 ID
    updatedAt: number;              // 最后活动时间
    chatType: "direct" | "group" | "room";
    
    // 切换设置
    thinkingLevel?: string;
    verboseLevel?: string;
    
    // 模型选择
    providerOverride?: string;
    modelOverride?: string;
    
    // Token 计数器
    inputTokens: number;
    outputTokens: number;
    totalTokens: number;
    contextTokens: number;
    
    // 压缩计数
    compactionCount: number;
    
    // 内存刷新
    memoryFlushAt?: number;
    memoryFlushCompactionCount?: number;
}
```

---

### 转录结构（JSONL）

```jsonl
# 第一行：会话头
{"type":"session","id":"abc123","cwd":"/workspace","timestamp":1234567890}

# 消息条目
{"type":"message","id":"m1","parentId":"abc123","role":"user","content":"Hello"}
{"type":"message","id":"m2","parentId":"abc123","role":"assistant","content":"Hi!"}

# 工具调用
{"type":"message","id":"m3","parentId":"abc123","role":"tool","toolCall":{"name":"read","args":{"path":"file.txt"}}}

# 压缩摘要
{"type":"compaction","id":"c1","summary":"用户讨论了项目架构...","firstKeptEntryId":"m80","tokensBefore":15000}

# 分支摘要
{"type":"branch_summary","id":"b1","summary":"分支讨论总结..."}
```

---

## 🔧 上下文构建流程

### 系统提示构建

```typescript
// src/prompts/system-prompt.ts
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
    const projectContext = await injectWorkspaceFiles([
        "AGENTS.md", "SOUL.md", "TOOLS.md",
        "IDENTITY.md", "USER.md", "HEARTBEAT.md"
    ]);
    parts.push(`## Project Context\n${projectContext}`);
    
    return parts.join("\n\n");
}
```

---

### 工作空间文件注入

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

### 技能注入策略

**默认**: 仅注入技能列表（元数据）

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

### 工具成本分析

**两种成本**:
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

## 🔍 当前实现分析

### 优势

| 维度 | 评分 | 说明 |
|------|------|------|
| **压缩机制** | ⭐⭐⭐⭐ | 自动 + 手动，持久化摘要 |
| **会话存储** | ⭐⭐⭐⭐ | 两层架构，清晰分离 |
| **上下文检查** | ⭐⭐⭐⭐⭐ | `/status`, `/context` 详细 |
| **文件注入** | ⭐⭐⭐⭐ | 截断策略，总上限控制 |
| **技能注入** | ⭐⭐⭐⭐ | 元数据 + 按需加载 |

---

### 不足

| 维度 | 评分 | 说明 |
|------|------|------|
| **相关性过滤** | ⭐⭐ | 无语义检索，全部塞入 |
| **跨会话记忆** | ⭐⭐ | 会话隔离，无长期记忆 |
| **摘要质量** | ⭐⭐⭐ | 依赖 LLM，无结构化 |
| **工具 Schema** | ⭐⭐⭐ | 过大（~8K tokens） |
| **动态上下文** | ⭐⭐ | 固定注入，无动态调整 |

---

## 🎯 优化建议

### 短期优化（1-2 周）

#### 1. RAG 增强压缩

**当前**:
```typescript
// 简单摘要
const summary = await llm.summarize(transcript);
```

**优化**:
```typescript
// RAG 增强：提取关键信息
const keyInfo = await extractKeyInfo(transcript, [
    "用户目标",
    "技术决策",
    "待解决问题",
    "代码示例"
]);

const summary = await llm.summarize(transcript, {
    instructions: "关注关键信息",
    structuredOutput: keyInfo
});
```

**收益**:
- ✅ 摘要质量提升
- ✅ 保留关键信息
- ✅ 实现简单

---

#### 2. 工具 Schema 优化

**当前**: 所有工具 schema 全部注入（~8K tokens）

**优化**:
```typescript
// 按需注入工具 schema
const usedTools = getRecentlyUsedTools(session);
const contextTools = getContextRelevantTools(query);

const toolsToInject = [...usedTools, ...contextTools];
const toolSchemas = toolsToInject.map(t => t.schema);
```

**收益**:
- ✅ 减少 50-80% 工具 schema tokens
- ✅ 动态适配场景
- ✅ 实现中等难度

---

#### 3. 工作空间文件动态注入

**当前**: 固定注入所有文件

**优化**:
```typescript
// 基于查询相关性注入
const relevantFiles = await searchWorkspaceFiles(query, topK=3);

const injectedFiles = [
    "AGENTS.md", "SOUL.md",  // 始终注入
    ...relevantFiles          // 动态注入
];
```

**收益**:
- ✅ 减少无关文件注入
- ✅ 提升上下文相关性
- ✅ 实现简单

---

### 中期优化（1-2 月）

#### 4. 跨会话记忆（RAG 检索）

**当前**: 会话隔离，无长期记忆

**优化**:
```typescript
class CrossSessionMemory {
    private vectorStore = new ChromaDB();
    
    async store(sessionId: string, content: string) {
        const embedding = await embed(content);
        await this.vectorStore.add({
            id: `${sessionId}_${Date.now()}`,
            embedding,
            metadata: { sessionId, timestamp: Date.now() }
        });
    }
    
    async retrieve(query: string, topK=5) {
        const queryEmbedding = await embed(query);
        const results = await this.vectorStore.search(queryEmbedding, topK);
        return results.map(r => r.metadata);
    }
}

// 在系统提示中注入
const memoryContext = await memory.retrieve(currentQuery);
systemPrompt += `\n\n## Relevant Memory\n${formatMemory(memoryContext)}`;
```

**收益**:
- ✅ 跨会话记忆
- ✅ 个性化对话
- ✅ 用户粘性提升

---

#### 5. 分层压缩（Hierarchical Compaction）

**当前**: 单一压缩级别

**优化**:
```typescript
class HierarchicalCompaction {
    // L1: 最近 5 轮完整保留
    l1_recent = [];
    
    // L2: 最近 50 轮摘要
    l2_short_term = [];
    
    // L3: 所有历史向量检索
    l3_long_term = new VectorStore();
    
    async compact(transcript: Transcript) {
        // 压缩到 L2
        if (transcript.length > 50) {
            const summary = await summarize(transcript.slice(0, -50));
            this.l2_short_term.push(summary);
        }
        
        // 压缩到 L3
        if (this.l2_short_term.length > 10) {
            const oldSummary = this.l2_short_term.shift();
            await this.l3_long_term.add(oldSummary);
        }
    }
    
    async getContext(query: string) {
        const l3_relevant = await this.l3_long_term.search(query, topK=3);
        return [...this.l1_recent, ...this.l2_short_term, ...l3_relevant];
    }
}
```

**收益**:
- ✅ 完整 + 摘要 + 检索
- ✅ 超长对话支持
- ✅ 实现复杂度高

---

### 长期优化（3-6 月）

#### 6. 完整 RAG 上下文管理

**架构**:
```
应用层：RAG 检索
    ↓
检索相关历史（Top-5）
检索相关工作空间文件
检索跨会话记忆
    ↓
模型层：稀疏注意力（StreamingLLM）
    ↓
处理长上下文（初始 token + 滑动窗口）
    ↓
生成回答
```

**收益**:
- ✅ RAG 过滤无关内容
- ✅ 稀疏注意力处理长序列
- ✅ 综合性能最优

---

## 📊 优化效果预估

| 优化 | 实现难度 | 上下文减少 | 质量提升 | 推荐度 |
|------|---------|----------|---------|-------|
| **RAG 增强压缩** | ⭐⭐⭐ | -10% | +20% | ⭐⭐⭐⭐⭐ |
| **工具 Schema 优化** | ⭐⭐⭐ | -50% | 0% | ⭐⭐⭐⭐⭐ |
| **动态文件注入** | ⭐⭐ | -20% | +10% | ⭐⭐⭐⭐ |
| **跨会话记忆** | ⭐⭐⭐⭐ | +5% | +50% | ⭐⭐⭐⭐⭐ |
| **分层压缩** | ⭐⭐⭐⭐⭐ | -30% | +30% | ⭐⭐⭐⭐ |
| **完整 RAG** | ⭐⭐⭐⭐⭐ | -60% | +80% | ⭐⭐⭐⭐⭐ |

---

## 🎯 推荐实施路线

### 阶段 1: 快速验证（本周）

**实施**: 工具 Schema 优化 + 动态文件注入

```typescript
// 1. 工具 Schema 按需注入
const usedTools = getRecentlyUsedTools(session);
const toolSchemas = usedTools.map(t => t.schema);

// 2. 动态文件注入
const relevantFiles = await searchWorkspaceFiles(query, topK=3);
const injectedFiles = ["AGENTS.md", "SOUL.md", ...relevantFiles];
```

**预期收益**:
- ✅ 上下文减少 30-50%
- ✅ 实现简单（<100 行代码）
- ✅ 一个周末完成

---

### 阶段 2: RAG 增强压缩（1-2 周）

**实施**: 结构化摘要提取

```typescript
const keyInfo = await extractKeyInfo(transcript, [
    "用户目标",
    "技术决策",
    "待解决问题"
]);
```

**预期收益**:
- ✅ 摘要质量提升 20%
- ✅ 关键信息保留

---

### 阶段 3: 跨会话记忆（1-2 月）

**实施**: 向量存储 + 检索

```typescript
const memoryContext = await memory.retrieve(currentQuery);
systemPrompt += `\n\n## Relevant Memory\n${formatMemory(memoryContext)}`;
```

**预期收益**:
- ✅ 跨会话记忆
- ✅ 个性化对话

---

## 🔗 相关资源

### OpenClaw 文档
- [Compaction](https://github.com/openclaw/openclaw/blob/main/docs/concepts/compaction.md)
- [Context](https://github.com/openclaw/openclaw/blob/main/docs/concepts/context.md)
- [Session Management](https://github.com/openclaw/openclaw/blob/main/docs/reference/session-management-compaction.md)

### 代码位置
- 会话管理：`src/config/sessions/`
- 压缩实现：`src/commands/compact.ts`
- 上下文构建：`src/prompts/system-prompt.ts`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**状态**: ✅ 完成
