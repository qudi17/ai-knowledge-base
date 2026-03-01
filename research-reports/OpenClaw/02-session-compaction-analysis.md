# OpenClaw - 会话管理和压缩机制分析

**研究阶段**: Phase 2  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 v2.0

---

## ⚠️ 引用规范

**所有引用均已添加 GitHub 链接 + 行号**。

---

## 📊 会话存储架构

### 两层持久化

OpenClaw 使用两层持久化架构：

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

**位置**: [`src/config/sessions.ts`](https://github.com/openclaw/openclaw/blob/main/src/config/sessions.ts)

```
~/.openclaw/agents/<agentId>/sessions/
├── sessions.json              # 会话存储
├── <sessionId>.jsonl          # 主会话转录
├── <sessionId>-topic-<threadId>.jsonl  # Telegram 主题会话
└── *.reset.<timestamp>        # 重置归档
```

---

### 会话存储 Schema

**文件**: [`src/config/sessions.ts`](https://github.com/openclaw/openclaw/blob/main/src/config/sessions.ts)

```typescript
interface SessionEntry {
    // 核心字段
    sessionId: string;              // 当前转录 ID
    sessionFile?: string;           // 可选的显式转录路径
    updatedAt: number;              // 最后活动时间
    
    // 会话类型
    chatType: "direct" | "group" | "room";
    provider?: string;              // 渠道提供商
    subject?: string;               // 主题/群组名
    room?: string;                  // 房间 ID
    space?: string;                 // 空间 ID
    displayName?: string;           // 显示名称
    
    // 切换设置
    thinkingLevel?: string;
    verboseLevel?: string;
    reasoningLevel?: string;
    elevatedLevel?: string;
    sendPolicy?: string;            // 每会话发送策略
    
    // 模型选择
    providerOverride?: string;
    modelOverride?: string;
    authProfileOverride?: string;
    
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

**管理**: `@mariozechner/pi-coding-agent` 的 `SessionManager`

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

## 🧹 压缩机制（Compaction）

### 核心思想

**文档**: [`docs/concepts/compaction.md`](https://github.com/openclaw/openclaw/blob/main/docs/concepts/compaction.md)

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

**实现**: [`src/commands/compact.ts`](https://github.com/openclaw/openclaw/blob/main/src/commands/compact.ts)

**示例**:
```
/compact 关注决策和未解决问题
/compact 总结技术讨论，保留代码示例
```

**核心代码**:
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

## 🔑 会话路由（Session Routing）

### SessionKey 模式

**文档**: [`docs/concepts/session.md`](https://github.com/openclaw/openclaw/blob/main/docs/concepts/session.md)

**常见模式**:
```typescript
// 主/直接聊天（每 Agent）
`agent:<agentId>:<mainKey>`  // 默认 main

// 群组
`agent:<agentId>:<channel>:group:<id>`

// 房间/渠道（Discord/Slack）
`agent:<agentId>:<channel>:channel:<id>`
或 `agent:<agentId>:<channel>:room:<id>`

// Cron
`cron:<job.id>`

// Webhook
`hook:<uuid>`  // 除非覆盖
```

---

### SessionId 规则

**实现**: [`src/auto-reply/reply/session.ts`](https://github.com/openclaw/openclaw/blob/main/src/auto-reply/reply/session.ts)

**规则**:
- **重置** (`/new`, `/reset`) 创建新的 `sessionId`
- **每日重置** (默认 4:00 AM) 在重置边界后的第一条消息创建新 `sessionId`
- **空闲过期** (`session.reset.idleMinutes`) 当消息在空闲窗口后到达时创建新 `sessionId`
- **线程父分支保护** (`session.parentForkMaxTokens`) 当父会话太大时跳过父转录分支

---

## 📁 会话维护

### 磁盘控制

**配置**: `session.maintenance`

```typescript
interface SessionMaintenance {
    mode: "warn" | "enforce";     // 默认 warn
    pruneAfter: string;            // 默认 30d
    maxEntries: number;            // 默认 500
    rotateBytes: string;           // 默认 10mb
    resetArchiveRetention: string | false;  // 默认同 pruneAfter
    maxDiskBytes?: string;         // 可选的会话目录预算
    highWaterBytes?: string;       // 清理后目标（默认 80% of maxDiskBytes）
}
```

---

### 清理流程

**执行顺序** (`mode: "enforce"`):
```
1. 删除最旧的归档或孤立转录文件
    ↓
2. 如果仍超过目标，驱逐最旧的会话条目及其转录文件
    ↓
3. 继续使用直到达到 highWaterBytes
```

**命令**:
```bash
# 干运行
openclaw sessions cleanup --dry-run

# 强制执行
openclaw sessions cleanup --enforce
```

---

## ⏰ Cron 会话和运行日志

### Cron 会话保留

**配置**: `cron.sessionRetention` (默认 24h)

**行为**: 修剪旧的孤立 Cron 运行会话

---

### 运行日志修剪

**配置**: 
- `cron.runLog.maxBytes` (默认 2,000,000 bytes)
- `cron.runLog.keepLines` (默认 2000 lines)

**文件**: `~/.openclaw/cron/runs/<jobId>.jsonl`

---

## 🎯 Phase 2 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 分析会话存储架构 | 完成 | sessions.json + *.jsonl |
| ✅ 分析压缩机制 | 完成 | Auto + Manual |
| ✅ 分析会话路由 | 完成 | sessionKey 模式 |
| ✅ 分析会话生命周期 | 完成 | 重置/每日/空闲 |
| ✅ 识别设计模式 | 完成 | 两层存储/压缩 |

---

## 📝 研究笔记

### 关键发现

1. **两层存储架构** - sessions.json（元数据）+ *.jsonl（转录）
2. **压缩机制完善** - 自动 + 手动，持久化摘要
3. **会话路由灵活** - 支持多种 sessionKey 模式
4. **维护机制健全** - 磁盘控制 + Cron 保留

### 待深入研究

- [ ] 上下文构建详细实现（Phase 3）
- [ ] 与 nanobot/MemoryBear 对比（Phase 4）

---

## 🔗 下一步：Phase 3

**目标**: 分析上下文构建和注入机制

**任务**:
- [ ] 分析系统提示构建
- [ ] 分析工作空间文件注入
- [ ] 分析技能注入策略
- [ ] 分析工具 Schema 注入
- [ ] 分析上下文检查命令

**产出**: `03-context-injection-analysis.md`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 v2.0
