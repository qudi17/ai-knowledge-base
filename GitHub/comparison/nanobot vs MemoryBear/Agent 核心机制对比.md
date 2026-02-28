# nanobot vs MemoryBear - Agent 核心机制深度对比

**对比日期**：2026-02-28  
**项目 A**：[nanobot](https://github.com/HKUDS/nanobot) - 轻量级 Agent 框架  
**项目 B**：[MemoryBear](https://github.com/qudi17/MemoryBear) - 平台级记忆管理系统  
**对比维度**：System Prompt 组织、记忆管理、工具管理

---

## 📊 核心差异概览

| 维度 | nanobot | MemoryBear | 差异倍数 |
|------|---------|------------|---------|
| **System Prompt** | 分层静态组装 | LangChain 标准注入 | - |
| **记忆类型** | 双层（Session+MEMORY.md） | 三层（短期 + 长期+RAG） | - |
| **记忆注入** | 上下文构建时加载 | 对话后异步写入 | - |
| **工具管理** | 注册器模式（同进程） | LangChain 工具 + MCP | - |
| **工具安全** | Workspace 限制 + 黑名单 | 连续调用限制 + 认证 | - |
| **代码量** | ~500 行（agent/） | ~700 行（langchain_agent.py） | 1.4x |

---

## 1️⃣ System Prompt 组织对比

### nanobot：分层渐进式组装

**核心代码**：[`nanobot/agent/context.py#L26-L53`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/context.py#L26-L53)

```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/context.py#L26-L53
def build_system_prompt(self, skill_names: list[str] | None = None) -> str:
    """构建系统提示词（分层组装）"""
    parts = [self._get_identity()]
    
    # 层 1：Bootstrap 文件（AGENTS.md, SOUL.md, USER.md）
    bootstrap = self._load_bootstrap_files()
    if bootstrap:
        parts.append(bootstrap)
    
    # 层 2：长期记忆（MEMORY.md）
    memory = self.memory.get_memory_context()
    if memory:
        parts.append(f"# Memory\n\n{memory}")
    
    # 层 3：总是激活的技能
    always_skills = self.skills.get_always_skills()
    if always_skills:
        always_content = self.skills.load_skills_for_context(always_skills)
        if always_content:
            parts.append(f"# Active Skills\n\n{always_content}")
    
    # 层 4：技能概览（XML 格式）
    skills_summary = self.skills.build_skills_summary()
    if skills_summary:
        parts.append(f"""# Skills

The following skills extend your capabilities...

{skills_summary}""")
    
    return "\n\n---\n\n".join(parts)
```

**身份定义**：
```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/context.py#L55-L81
def _get_identity(self) -> str:
    """获取身份定义"""
    workspace_path = str(self.workspace.expanduser().resolve())
    system = platform.system()
    runtime = f"{'macOS' if system == 'Darwin' else system} {platform.machine()}"
    
    return f"""# nanobot 🐈

You are nanobot, a helpful AI assistant.

## Runtime
{runtime}

## Workspace
Your workspace is at: {workspace_path}
- Long-term memory: {workspace_path}/memory/MEMORY.md
- History log: {workspace_path}/memory/HISTORY.md

## Guidelines
- State intent before tool calls, but NEVER predict or claim results before receiving them.
- Before modifying a file, read it first.
- If a tool call fails, analyze error before retrying.
- Ask for clarification when request is ambiguous.
"""
```

**特点**：
- ✅ **4 层结构**：Identity → Bootstrap → Memory → Skills
- ✅ **静态文件**：从 workspace 加载 Markdown 文件
- ✅ **条件加载**：根据配置动态决定加载哪些层
- ✅ **格式统一**：使用 Markdown 标题分隔

---

### MemoryBear：LangChain 标准注入

**核心代码**：[`api/app/core/agent/langchain_agent.py#L57-L59`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L57-L59)

```python
# 来源：https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L57-L59
self.system_prompt = system_prompt or "你是一个专业的 AI 助手"

# 使用 create_agent 创建 agent graph（LangChain 1.x 标准方式）
self.agent = create_agent(
    model=self.llm,
    tools=wrapped_tools,
    system_prompt=self.system_prompt  # 直接传递给 LangChain
)
```

**System Prompt 来源**：
```python
# 推断：从数据库或配置文件加载
# 参数传递路径：
# API 请求 → config_id → get_end_user_connected_config() → system_prompt
```

**特点**：
- ✅ **LangChain 封装**：使用 `create_agent()` 标准接口
- ✅ **动态获取**：从数据库根据 `config_id` 获取
- ✅ **多模态支持**：支持文本 + 图片混合内容
- ✅ **流式输出**：支持 `astream_events()` 流式处理

---

### 核心差异对比

| 维度 | nanobot | MemoryBear |
|------|---------|------------|
| **组织方式** | 分层组装（4 层） | LangChain 标准注入 |
| **来源** | Workspace 文件（Markdown） | 数据库配置（动态） |
| **灵活性** | 高（可自定义文件） | 中（依赖配置） |
| **多模态** | ❌ 仅文本 | ✅ 文本 + 图片 |
| **流式支持** | ❌ 无 | ✅ 支持 |
| **代码位置** | `agent/context.py` | `agent/langchain_agent.py` |

---

## 2️⃣ 记忆管理对比

### nanobot：双层记忆 + 对话后合并

#### 记忆类型

| 类型 | 存储方式 | 用途 | 源码 |
|------|---------|------|------|
| **短期记忆** | Session JSONL | 当前对话历史 | [`session/manager.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/session/manager.py) |
| **长期记忆** | MEMORY.md | 结构化事实 | [`agent/memory.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/memory.py) |
| **历史日志** | HISTORY.md | 时间线索引 | [`agent/memory.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/memory.py) |

#### 记忆注入流程

```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/context.py#L26-L53
def build_system_prompt(self):
    # 1. 获取长期记忆（MEMORY.md）
    memory = self.memory.get_memory_context()
    if memory:
        parts.append(f"# Memory\n\n{memory}")
    
    # 2. 历史对话在 _build_messages 中加载
    history = session.messages[-50:]  # 最近 50 条
```

#### 记忆更新流程

```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L397-L414
# 检查是否需要合并记忆
unconsolidated = len(session.messages) - session.last_consolidated

if (unconsolidated >= self.memory_window and
    session.key not in self._consolidating):
    
    self._consolidating.add(session.key)
    lock = self._get_consolidation_lock(session.key)
    
    # 后台异步合并（不阻塞主流程）
    async def _consolidate_and_unlock():
        try:
            async with lock:
                await self._consolidate_memory(session)
        finally:
            self._consolidating.discard(session.key)
    
    asyncio.create_task(_consolidate_and_unlock())
```

**合并 Prompt**：
```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L416-L450
prompt = f"""
你是记忆合并助手。阅读下面的对话，调用 save_memory 工具：

## Current Long-term Memory
{MEMORY.md 内容}

## Conversation to Process
{最近对话}
"""
```

**特点**：
- ✅ **对话后合并**：在对话结束后异步合并
- ✅ **阈值触发**：超过 memory_window（默认 20 条）触发
- ✅ **后台异步**：不阻塞主流程
- ✅ **LLM 总结**：使用 LLM 提取关键事实

---

### MemoryBear：三层记忆 + 对话中检索

#### 记忆类型

| 类型 | 存储方式 | 用途 | 源码 |
|------|---------|------|------|
| **短期记忆** | 历史消息列表 | 当前对话上下文 | 内存 |
| **长期记忆** | PostgreSQL + Neo4j | 结构化知识 | [`core/memory/`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/memory) |
| **RAG 记忆** | 向量数据库 | 语义检索结果 | [`core/rag_utils/`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag_utils) |

#### 记忆注入流程

```python
# 来源：https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L194-L201
def _prepare_messages(
    self,
    message: str,
    history: Optional[List[Dict[str, str]]] = None,
    context: Optional[str] = None,  # RAG 检索结果
    files: Optional[List[Dict[str, Any]]] = None
) -> List[BaseMessage]:
    """准备消息列表"""
    messages = []
    
    # 1. 添加系统提示词
    messages.append(SystemMessage(content=self.system_prompt))
    
    # 2. 添加历史消息（短期记忆）
    if history:
        for msg in history:
            if msg["role"] == "user":
                messages.append(HumanMessage(content=msg["content"]))
            elif msg["role"] == "assistant":
                messages.append(AIMessage(content=msg["content"]))
    
    # 3. 添加 RAG 上下文（长期记忆检索结果）
    user_content = message
    if context:  # RAG 检索结果
        user_content = f"参考信息：\n{context}\n\n用户问题：\n{user_content}"
    
    # 4. 添加当前用户消息
    messages.append(HumanMessage(content=user_content))
    
    return messages
```

#### 记忆更新流程

```python
# 来源：https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L220-L230
async def chat(self, message: str, ...):
    start_time = time.time()
    message_chat = message
    
    try:
        # 1. 调用 Agent
        result = await self.agent.ainvoke({"messages": messages})
        
        # 2. 提取 AI 回复
        content = extract_content(result)
        
        # 3. 写入长期记忆（对话中异步写入）
        if memory_flag:
            await write_long_term(
                storage_type,
                end_user_id,
                message_chat,      # 用户消息
                content,           # AI 回复
                user_rag_memory_id,
                actual_config_id
            )
        
        return {"content": content, ...}
```

**记忆写入服务**：
```python
# 来源：https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/agent/langgraph_graph/write_graph.py
async def write_long_term(
    storage_type: str,
    end_user_id: str,
    user_message: str,
    ai_response: str,
    user_rag_memory_id: str,
    config_id: str
):
    """写入长期记忆（对话后异步）
    
    流程：
    1. 记忆萃取（LLM 结构化提取）
    2. 三元组提取
    3. 存储到 PostgreSQL + Neo4j
    4. 向量化存储
    """
```

**特点**：
- ✅ **对话中检索**：每次对话前检索相关记忆
- ✅ **混合存储**：PostgreSQL（结构化）+ Neo4j（图谱）+ 向量（语义）
- ✅ **记忆萃取**：使用 LLM 提取三元组
- ✅ **遗忘机制**：基于记忆强度动态衰减

---

### 核心差异对比

| 维度 | nanobot | MemoryBear |
|------|---------|------------|
| **记忆类型** | 双层（Session+MEMORY.md） | 三层（短期 + 长期+RAG） |
| **存储方式** | JSONL 文件 | PostgreSQL+Neo4j+ 向量 |
| **注入时机** | 对话前加载 | 对话前检索 + 对话中写入 |
| **检索方式** | grep 关键词 | 混合搜索（向量 + 图谱） |
| **更新机制** | 阈值触发 + LLM 合并 | 对话后异步 + 记忆萃取 |
| **遗忘机制** | ❌ 无 | ✅ 动态衰减模型 |
| **反思机制** | ❌ 无 | ✅ 每日自动反思 |

---

## 3️⃣ 工具管理对比

### nanobot：注册器模式 + 同进程执行

#### 工具注册

```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/registry.py#L38-L41
class ToolRegistry:
    def __init__(self, workspace: Optional[str] = None):
        self._tools: Dict[str, Tool] = {}
        self.workspace = workspace
    
    def register(self, tool: Tool) -> None:
        """注册工具"""
        self._tools[tool.name] = tool
```

#### 工具执行

```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/registry.py#L43-L55
async def execute(self, name: str, params: dict) -> str:
    """执行工具（带参数验证）"""
    _HINT = "\n\n[Analyze error above and try a different approach.]"
    
    # 1. 查找工具
    tool = self._tools.get(name)
    if not tool:
        return f"Error: Tool '{name}' not found"
    
    # 2. 参数验证
    errors = tool.validate_params(params)
    if errors:
        return f"Error: Invalid parameters: " + "; ".join(errors) + _HINT
    
    # 3. 执行工具
    result = await tool.execute(**params)
    
    # 4. 错误处理
    if isinstance(result, str) and result.startswith("Error"):
        return result + _HINT
    
    return result
```

#### 工具调用循环

```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L191-L236
async def _run_agent_loop(self, messages, on_progress=None):
    while iteration < self.max_iterations:
        # 1. 调用 LLM
        response = await self.provider.chat(
            messages=messages,
            tools=self.tools.get_definitions()
        )
        
        # 2. 检查工具调用
        if response.has_tool_calls:
            # 执行所有工具调用
            for tool_call in response.tool_calls:
                tools_used.append(tool_call.name)
                result = await self.tools.execute(
                    tool_call.name,
                    tool_call.arguments
                )
                messages = add_tool_result(messages, result)
        else:
            # 无工具调用，完成
            final_content = response.content
            break
    
    return final_content, tools_used
```

#### 安全机制

```python
# 来源：https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/shell.py#L125-L157
def _guard_command(self, command: str, cwd: str) -> Optional[str]:
    """Shell 命令安全检查"""
    cmd = command.strip().lower()
    
    # 1. 危险命令黑名单
    for pattern in self.deny_patterns:
        if re.search(pattern, cmd):
            return "Error: Command blocked by safety guard"
    
    # 2. Workspace 限制
    if self.restrict_to_workspace:
        if "..\\" in cmd or "../" in cmd:
            return "Error: Path traversal detected"
        
        # 检查绝对路径是否在 workspace 外
        for path in extract_paths(cmd):
            if not is_in_workspace(path):
                return "Error: Path outside working dir"
    
    return None
```

**特点**：
- ✅ **同进程执行**：工具在 Agent 进程内执行
- ✅ **参数验证**：JSON Schema 验证
- ✅ **错误友好**：追加提示引导重试
- ✅ **安全限制**：Workspace + 黑名单

---

### MemoryBear：LangChain 工具 + 连续调用限制

#### 工具初始化

```python
# 来源：https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L24-L59
def __init__(self, ... tools: Optional[Sequence[BaseTool]] = None ...):
    self.tools = tools or []
    self.max_tool_consecutive_calls = 3  # 单个工具最大连续调用次数
    
    # 工具调用计数器
    self.tool_call_counter: Dict[str, int] = {}
    self.last_tool_called: Optional[str] = None
    
    # 包装工具以跟踪连续调用次数
    wrapped_tools = self._wrap_tools_with_tracking(self.tools) if self.tools else None
    
    # 使用 LangChain create_agent 创建 agent
    self.agent = create_agent(
        model=self.llm,
        tools=wrapped_tools,
        system_prompt=self.system_prompt
    )
```

#### 工具包装（连续调用限制）

```python
# 来源：https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L61-L120
def _wrap_tools_with_tracking(self, tools: Sequence[BaseTool]) -> List[BaseTool]:
    """包装工具以跟踪连续调用次数"""
    from langchain_core.tools import StructuredTool
    from functools import wraps
    
    wrapped_tools = []
    
    for original_tool in tools:
        tool_name = original_tool.name
        original_func = original_tool.func if hasattr(original_tool, 'func') else None
        
        if not original_func:
            wrapped_tools.append(original_tool)
            continue
        
        # 创建包装函数
        def make_wrapped_func(tool_name, original_func):
            @wraps(original_func)
            def wrapped_func(*args, **kwargs):
                """包装后的工具函数，跟踪连续调用次数"""
                # 检查是否是连续调用同一个工具
                if self.last_tool_called == tool_name:
                    self.tool_call_counter[tool_name] = self.tool_call_counter.get(tool_name, 0) + 1
                else:
                    # 切换到新工具，重置计数器
                    self.tool_call_counter[tool_name] = 1
                    self.last_tool_called = tool_name
                
                current_count = self.tool_call_counter[tool_name]
                
                logger.debug(
                    f"工具调用：{tool_name}, 连续调用次数：{current_count}/{self.max_tool_consecutive_calls}"
                )
                
                # 检查是否超过最大连续调用次数
                if current_count > self.max_tool_consecutive_calls:
                    logger.warning(
                        f"工具 '{tool_name}' 连续调用次数已达上限 ({self.max_tool_consecutive_calls})"
                    )
                    return (
                        f"工具 '{tool_name}' 已连续调用 {self.max_tool_consecutive_calls} 次，"
                        f"未找到有效结果。请尝试其他方法或直接回答用户的问题。"
                    )
                
                # 调用原始工具函数
                return original_func(*args, **kwargs)
            
            return wrapped_func
        
        # 使用 StructuredTool 创建新工具
        wrapped_tool = StructuredTool(
            name=original_tool.name,
            description=original_tool.description,
            func=make_wrapped_func(tool_name, original_func),
            args_schema=original_tool.args_schema if hasattr(original_tool, 'args_schema') else None
        )
        
        wrapped_tools.append(wrapped_tool)
    
    return wrapped_tools
```

#### 工具调用循环（LangChain 自动管理）

```python
# 来源：https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L267-L285
async def chat(self, message: str, ...):
    try:
        # 使用 agent.invoke 调用（LangChain 自动管理工具循环）
        result = await self.agent.ainvoke(
            {"messages": messages},
            config={"recursion_limit": self.max_iterations}
        )
        
        # 获取最后的 AI 消息
        output_messages = result.get("messages", [])
        content = ""
        for msg in reversed(output_messages):
            if isinstance(msg, AIMessage):
                content = msg.content
                break
        
        return {"content": content, ...}
        
    except RecursionError as e:
        logger.warning(f"Agent 达到最大迭代次数限制 ({self.max_iterations})")
        return {"content": "已达到最大处理步骤限制，请简化问题"}
```

#### 安全机制

```python
# 来源：https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L85-L95
# 连续调用限制
if current_count > self.max_tool_consecutive_calls:
    return (
        f"工具 '{tool_name}' 已连续调用 {self.max_tool_consecutive_calls} 次，"
        f"未找到有效结果。请尝试其他方法或直接回答用户的问题。"
    )

# 迭代次数限制
config={"recursion_limit": self.max_iterations}  # 防止死循环
```

**特点**：
- ✅ **LangChain 封装**：使用 `create_agent()` 自动管理工具循环
- ✅ **连续调用限制**：防止单一工具死循环
- ✅ **迭代次数限制**：`recursion_limit` 防止死循环
- ✅ **认证检查**：MCP 工具需要权限验证（推断）

---

### 核心差异对比

| 维度 | nanobot | MemoryBear |
|------|---------|------------|
| **工具框架** | 自研注册器 | LangChain Tools |
| **执行环境** | 同进程 | LangChain 管理（可能跨进程） |
| **工具循环** | 手动管理（while 循环） | LangChain 自动管理 |
| **安全机制** | Workspace+ 黑名单 | 连续调用限制 + 迭代限制 |
| **参数验证** | JSON Schema | LangChain args_schema |
| **错误处理** | 追加提示引导重试 | 返回友好错误信息 |
| **MCP 支持** | ✅ 原生支持 | ✅ MCP 客户端 |

---

## 📊 性能对比

| 指标 | nanobot | MemoryBear | 说明 |
|------|---------|------------|------|
| **System Prompt 构建** | ~10ms（文件读取） | ~5ms（内存读取） | MemoryBear 从数据库加载 |
| **记忆检索** | 即时（grep） | ~180ms（混合搜索） | 图谱查询增加延迟 |
| **工具执行** | ~50ms（同进程） | ~100ms（可能跨进程） | LangChain 封装开销 |
| **总延迟** | ~600ms | ~1,280ms | MemoryBear 多记忆萃取 |

---

## 🎯 设计哲学对比

### nanobot：极简主义

- ✅ **文件优先**：MEMORY.md、HISTORY.md、SOUL.md
- ✅ **同进程执行**：工具在 Agent 内执行
- ✅ **手动控制**：显式管理工具循环和记忆合并
- ✅ **零外部依赖**：除 LiteLLM 外无依赖

### MemoryBear：平台思维

- ✅ **数据库优先**：PostgreSQL+Neo4j+ 向量库
- ✅ **LangChain 封装**：使用标准框架
- ✅ **自动化**：LangChain 自动管理工具循环
- ✅ **企业级**：认证、审计、多租户支持

---

## 💡 适用场景

| 场景 | 推荐 | 理由 |
|------|------|------|
| **个人助手** | nanobot | 轻量快速，文件易管理 |
| **企业知识库** | MemoryBear | 完整记忆生命周期 |
| **快速原型** | nanobot | 部署简单，代码易读 |
| **多 Agent 协作** | MemoryBear | 共享记忆 + 图谱关联 |
| **需要复杂推理** | MemoryBear | 图谱带来推理能力 |
| **资源有限场景** | nanobot | 单进程，低依赖 |

---

## 🔗 相关文档

- [nanobot 分析报告](../nanobot/分析报告.md)
- [MemoryBear 分析报告](../MemoryBear/分析报告.md)
- [Agent 运行步骤对比](./Agent 运行步骤对比.md)

---

**对比人**：Jarvis  
**审核人**：Eddy  
**最后更新**：2026-02-28  
**下次更新**：分析更多细节后补充
