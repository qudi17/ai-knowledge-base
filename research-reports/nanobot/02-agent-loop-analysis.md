# nanobot - Agent 循环和消息处理分析

**研究阶段**: Phase 2  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能

---

## 📊 AgentLoop 核心分析

### 核心定位

**AgentLoop** 是 nanobot 的核心处理引擎（~400 行），负责：
1. 接收消息
2. 构建上下文
3. 调用 LLM
4. 执行工具调用
5. 发送响应

**文件位置**: `nanobot/agent/loop.py`

---

### 初始化流程

**核心代码**:
```python
# agent/loop.py:50-100
class AgentLoop:
    def __init__(
        self,
        bus: MessageBus,
        provider: LLMProvider,
        workspace: Path,
        model: str | None = None,
        max_iterations: int = 40,
        temperature: float = 0.1,
        max_tokens: int = 4096,
        memory_window: int = 100,
        brave_api_key: str | None = None,
        exec_config: ExecToolConfig | None = None,
        cron_service: CronService | None = None,
        restrict_to_workspace: bool = False,
        session_manager: SessionManager | None = None,
        mcp_servers: dict | None = None,
        channels_config: ChannelsConfig | None = None,
    ):
        self.bus = bus
        self.provider = provider
        self.workspace = workspace
        self.model = model or provider.get_default_model()
        self.max_iterations = max_iterations
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.memory_window = memory_window
        
        # 上下文构建器
        self.context = ContextBuilder(workspace)
        
        # 会话管理
        self.sessions = session_manager or SessionManager(workspace)
        
        # 工具注册
        self.tools = ToolRegistry()
        
        # 子 Agent 管理
        self.subagents = SubagentManager(...)
        
        # 注册默认工具
        self._register_default_tools()
```

**关键组件**:
- `ContextBuilder` - 上下文构建
- `SessionManager` - 会话管理
- `ToolRegistry` - 工具注册
- `SubagentManager` - 子 Agent 管理

---

### 消息处理流程

**核心方法**: `_process_message()`

**完整流程**:
```python
# agent/loop.py:200-350
async def _process_message(self, event: InboundMessage) -> None:
    """处理单条消息"""
    session_key = self._get_session_key(event)
    
    # 1. 获取或创建会话
    session = self.sessions.get_or_create(session_key)
    
    # 2. 构建上下文
    context = await self.context.build(
        session=session,
        message=event.message,
        memory_window=self.memory_window,
    )
    
    # 3. 迭代处理（最多 40 次）
    for iteration in range(self.max_iterations):
        # 4. 调用 LLM
        response = await self.provider.chat(
            model=self.model,
            messages=context.messages,
            tools=self.tools.get_schema(),
            temperature=self.temperature,
            max_tokens=self.max_tokens,
        )
        
        # 5. 检查是否完成
        if not response.tool_calls:
            # 无工具调用，发送响应
            await self.bus.publish_outbound(
                channel=event.channel,
                chat_id=event.chat_id,
                message=response.content,
            )
            break
        
        # 6. 执行工具调用
        for tool_call in response.tool_calls:
            result = await self.tools.execute(tool_call)
            
            # 7. 添加结果到上下文
            context.messages.append({
                "role": "assistant",
                "content": None,
                "tool_calls": [tool_call],
            })
            context.messages.append({
                "role": "tool",
                "content": truncate(result, TOOL_RESULT_MAX_CHARS),
                "tool_call_id": tool_call.id,
            })
    
    # 8. 清理
    session.cleanup_if_needed()
```

---

### 上下文构建机制

**ContextBuilder** 负责构建 LLM 上下文：

```python
# agent/context.py:50-150
class ContextBuilder:
    async def build(
        self,
        session: Session,
        message: str,
        memory_window: int = 100,
    ) -> Context:
        """构建上下文"""
        messages = []
        
        # 1. 系统提示
        messages.append({
            "role": "system",
            "content": self._build_system_prompt(),
        })
        
        # 2. 历史消息（最近 N 条）
        history = session.get_history(limit=memory_window)
        messages.extend(history)
        
        # 3. 当前消息
        messages.append({
            "role": "user",
            "content": message,
        })
        
        # 4. 记忆检索
        memories = await self.memory.search(message, limit=5)
        if memories:
            memory_context = self._format_memories(memories)
            messages.append({
                "role": "system",
                "content": f"Relevant memories:\n{memory_context}",
            })
        
        # 5. 技能上下文
        skills_context = self.skills.get_active_skills()
        if skills_context:
            messages.append({
                "role": "system",
                "content": f"Active skills:\n{skills_context}",
            })
        
        return Context(messages=messages)
```

**关键特性**:
- ✅ 系统提示（角色定义）
- ✅ 历史消息（记忆窗口）
- ✅ 记忆检索（向量搜索）
- ✅ 技能上下文（活跃技能）

---

### 记忆系统

**MemoryStore** 实现轻量级记忆：

```python
# agent/memory.py:20-100
class MemoryStore:
    def __init__(self, workspace: Path):
        self.workspace = workspace
        self.memory_file = workspace / "MEMORY.md"
        self.history_file = workspace / "HISTORY.md"
    
    async def search(self, query: str, limit: int = 5) -> list[Memory]:
        """搜索相关记忆"""
        # 1. 加载记忆
        memories = self._load_memories()
        
        # 2. 简单关键词匹配
        # TODO: 升级为向量搜索
        query_words = set(query.lower().split())
        scored = []
        for mem in memories:
            score = len(query_words & set(mem.content.lower().split()))
            if score > 0:
                scored.append((score, mem))
        
        # 3. 按分数排序
        scored.sort(reverse=True, key=lambda x: x[0])
        
        return [mem for _, mem in scored[:limit]]
    
    def add(self, content: str, tags: list[str] = None) -> None:
        """添加记忆"""
        memory = Memory(
            id=uuid.uuid4().hex[:8],
            content=content,
            tags=tags or [],
            created_at=datetime.now(),
        )
        self._save_memory(memory)
```

**特点**:
- ✅ 基于文件（MEMORY.md + HISTORY.md）
- ✅ 简单关键词匹配（待升级为向量搜索）
- ✅ 标签系统
- ✅ 时间戳

---

## 📊 性能优化点

### 1. 迭代限制

**防止无限循环**:
```python
for iteration in range(self.max_iterations):  # 默认 40 次
    ...
```

**优势**:
- ✅ 防止死循环
- ✅ 控制成本
- ✅ 保证响应时间

---

### 2. 工具结果截断

**防止上下文爆炸**:
```python
TOOL_RESULT_MAX_CHARS = 500

def truncate(result: str, max_chars: int) -> str:
    if len(result) > max_chars:
        return result[:max_chars] + "..."
    return result
```

**优势**:
- ✅ 控制上下文大小
- ✅ 减少 token 消耗
- ✅ 提高响应速度

---

### 3. 会话隔离

**多用户支持**:
```python
session_key = self._get_session_key(event)
# 格式："{channel}:{chat_id}"
# 示例："feishu:ou_dd1f1883275c10de8220c37760b39d4a"

session = self.sessions.get_or_create(session_key)
```

**优势**:
- ✅ 多用户隔离
- ✅ 独立会话历史
- ✅ 独立记忆

---

## 🎯 Phase 2 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 分析 AgentLoop 实现 | 完成 | ~400 行核心代码 |
| ✅ 追踪消息处理流程 | 完成 | 8 步完整流程 |
| ✅ 分析 Context 构建 | 完成 | 系统提示 + 历史 + 记忆 + 技能 |
| ✅ 分析 Memory 系统 | 完成 | 文件存储 + 关键词匹配 |
| ✅ 识别性能优化点 | 完成 | 迭代限制 + 截断 + 隔离 |

---

## 📝 研究笔记

### 关键发现

1. **AgentLoop 设计简洁** - ~400 行实现核心功能
2. **上下文构建灵活** - 系统提示 + 历史 + 记忆 + 技能
3. **记忆系统轻量** - 文件存储，待升级向量搜索
4. **会话隔离完善** - 多用户支持

### 待深入研究

- [ ] 11 个 Channels 详细实现
- [ ] Tools 系统深度分析
- [ ] Skills 机制分析
- [ ] 与 MemoryBear 对比

---

## 🔗 下一步：Phase 3

**目标**: 分析 Channels 和 Tools 系统

**任务**:
- [ ] 分析 11 个 Channels 实现
- [ ] 分析 Tools 系统架构
- [ ] 分析 Skills 机制
- [ ] 分析 Shell 命令执行机制

**产出**: `03-channels-tools-analysis.md`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能
