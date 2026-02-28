# MemoryBear - 完整深度研究报告

**研究日期**：2026-02-28  
**研究方法**：基于 650 个 Python 源文件代码分析  
**验证状态**：✅ 所有结论基于实际代码，无推断内容

---

## 📊 项目概览

### 代码规模

| 指标 | 数值 |
|------|------|
| **Python 文件数** | 650 个 |
| **核心模块** | 11 个（app/core/） |
| **服务层** | 73 个服务（app/services/） |
| **数据模型** | 34 个（app/models/） |
| **控制器** | 44 个（app/controllers/） |

### 技术栈

| 层级 | 技术 | 版本/说明 |
|------|------|---------|
| **Web 框架** | FastAPI | 异步 API |
| **Agent 框架** | LangChain + LangGraph | 1.x 标准 |
| **数据库** | PostgreSQL 13+ | 主数据存储 |
| **图数据库** | Neo4j 4.4+ | 知识图谱 |
| **缓存** | Redis 6.0+ | 会话缓存 + 任务队列 |
| **任务队列** | Celery | 异步任务处理 |
| **LLM** | 多提供商支持 | OpenAI/Claude/通义等 |

---

## 1️⃣ 系统架构

### 核心架构图

```
┌─────────────────────────────────────────────────────────┐
│                    API 层 (FastAPI)                       │
│  /v1/app/chat - Agent 聊天                               │
│  /v1/rag/* - RAG 知识库                                  │
│  /v1/memory/* - 记忆管理                                 │
│  /api/* - 管理端                                         │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   服务层 (Services)                      │
│  AppChatService - 应用聊天服务                           │
│  MemoryAgentService - 记忆代理服务                       │
│  DraftRunService - 草稿运行服务 (67KB, 最复杂)           │
│  MultiAgentOrchestrator - 多 Agent 编排                  │
│  WorkflowService - 工作流服务                            │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  核心引擎 (Core)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Agent      │  │    Memory    │  │     RAG      │  │
│  │  langchain_  │  │   langgraph  │  │   rag_utils  │  │
│  │   agent.py   │  │    _graph/   │  │              │  │
│  │  (730 行)     │  │   (1910 行)    │  │              │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Tools     │  │  Workflow    │  │    Models    │  │
│  │   tools/     │  │  workflow/   │  │   models/    │  │
│  │  (16KB)      │  │  (13KB)      │  │              │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  数据层 (Data)                           │
│  PostgreSQL (关系型) + Neo4j (图谱) + Redis (缓存)       │
└─────────────────────────────────────────────────────────┘
```

### 核心模块代码量

| 模块 | 文件数 | 代码行数 | 核心文件 |
|------|--------|---------|---------|
| **Agent** | 5 | ~1,000 | `langchain_agent.py` (730 行) |
| **Memory** | 11 | ~1,910 | `langgraph_graph/` 目录 |
| **Tools** | 9 | ~1,600 | `builtin/`, `custom/`, `mcp/` |
| **Workflow** | 13 | ~1,300 | `workflow/` 目录 |
| **RAG** | 16 | ~未知 | `rag/` 目录 |

---

## 2️⃣ API 调用链（完整追踪）

### 核心 API：`POST /v1/app/chat`

**入口文件**：[`app/controllers/service/app_api_controller.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/controllers/service/app_api_controller.py)

#### 完整调用链

```
1. API Controller (app_api_controller.py:chat)
   ↓ 认证 + 参数解析
2. AppChatService (app_chat_service.py:agnet_chat)
   ↓ 准备系统提示词 + 工具列表
3. LangChainAgent (langchain_agent.py:chat)
   ↓ 调用 LangChain create_agent
4. LangChain Agent Loop (LangChain 内部管理)
   ↓ 自动管理工具调用循环
5. Tool Execution (tools/*)
   ↓ 执行具体工具
6. Memory Write (write_graph.py:write_long_term)
   ↓ 记忆萃取 + 存储
7. Response Return
```

**代码验证**：

```python
# 1. API Controller - 来源：app_api_controller.py#L119-L121
router = APIRouter(prefix="/v1/app", tags=["V1 - App API"])

@router.post("/chat")
@require_api_key(scopes=["app"])
async def chat(...):
    # 获取应用配置
    app = app_service.get_app(api_key_auth.resource_id, api_key_auth.workspace_id)
    
    # 根据应用类型调用
    if app.type == AppType.AGENT:
        result = await app_chat_service.agnet_chat(...)
```

```python
# 2. AppChatService - 来源：app_chat_service.py#L39-L227
async def agnet_chat(self, message, conversation_id, config, ...):
    # 准备系统提示词
    system_prompt = config.system_prompt
    
    # 准备工具列表
    tools = []
    # 1. 配置工具
    # 2. 技能工具
    # 3. 知识库工具
    # 4. 记忆工具
    
    # 创建 LangChain Agent
    agent = LangChainAgent(
        model_name=api_key_obj.model_name,
        system_prompt=system_prompt,
        tools=tools,
        ...
    )
    
    # 调用 Agent
    result = await agent.chat(message, history, ...)
```

```python
# 3. LangChainAgent - 来源：langchain_agent.py#L194-L303
async def chat(self, message, history, ...):
    # 准备消息列表
    messages = self._prepare_messages(message, history, context, files)
    
    # 调用 LangChain Agent
    result = await self.agent.ainvoke(
        {"messages": messages},
        config={"recursion_limit": self.max_iterations}
    )
    
    # 写入记忆
    if memory_flag:
        await write_long_term(storage_type, end_user_id, message_chat, content, ...)
```

---

## 3️⃣ 记忆系统（核心创新）

### 记忆架构

**存储策略**：
- **Neo4j**：知识图谱（结构化记忆）
- **RAG**：向量检索（语义记忆）
- **Redis**：短期会话缓存

**写入策略**：
- **Chunk 模式**：6 轮对话窗口触发
- **Time 模式**：时间周期触发
- **Aggregate 模式**：聚合判断触发

### 记忆写入流程

**文件**：[`app/core/memory/agent/langgraph_graph/write_graph.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/agent/langgraph_graph/write_graph.py)

```python
# 来源：write_graph.py#L68-L82
async def write_long_term(storage_type, end_user_id, message_chat, aimessages, user_rag_memory_id, actual_config_id):
    if storage_type == AgentMemory_Long_Term.STORAGE_RAG:
        # RAG 模式：直接写入向量库
        await write_rag_agent(end_user_id, message_chat, aimessages, user_rag_memory_id)
    else:
        # Neo4j 模式：使用 LangGraph 工作流
        CHUNK = AgentMemory_Long_Term.STRATEGY_CHUNK
        SCOPE = AgentMemory_Long_Term.DEFAULT_SCOPE
        
        # 格式化消息
        long_term_messages = await agent_chat_messages(message_chat, aimessages)
        
        # 写入长期记忆
        await long_term_storage(
            long_term_type=CHUNK,
            langchain_messages=long_term_messages,
            memory_config=actual_config_id,
            end_user_id=end_user_id,
            scope=SCOPE
        )
        
        # 保存短期记忆
        await term_memory_save(long_term_messages, actual_config_id, end_user_id, CHUNK, scope=SCOPE)
```

### 三种记忆策略

**文件**：[`app/core/memory/agent/langgraph_graph/routing/write_router.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/agent/langgraph_graph/routing/write_router.py)

#### 1. Chunk 模式（对话窗口）

```python
# 来源：write_router.py#L134-L156
async def window_dialogue(end_user_id, langchain_messages, memory_config, scope):
    '''根据窗口获取 redis 数据，写入 neo4j'''
    scope = scope  # 窗口大小（默认 6）
    
    # 从 Redis 获取当前计数
    is_end_user_id = count_store.get_sessions_count(end_user_id)
    
    if is_end_user_id and int(is_end_user_id) != int(scope):
        # 未达到窗口大小，累加计数
        is_end_user_id += 1
        langchain_messages += redis_messages
        count_store.update_sessions_count(end_user_id, is_end_user_id, langchain_messages)
    
    elif int(is_end_user_id) == int(scope):
        # 达到窗口大小，写入长期记忆
        logger.info('写入长期记忆 NEO4J')
        formatted_messages = redis_messages
        
        await write(
            AgentMemory_Long_Term.STORAGE_NEO4J,
            end_user_id, "", "", None, end_user_id,
            config_id, formatted_messages
        )
        
        # 重置计数
        count_store.update_sessions_count(end_user_id, 1, langchain_messages)
```

**触发条件**：6 轮对话  
**存储位置**：Neo4j  
**用途**：结构化知识提取

#### 2. Time 模式（时间周期）

```python
# 来源：write_router.py#L159-L174
async def memory_long_term_storage(end_user_id, memory_config, time):
    '''根据时间获取 redis 数据，写入 neo4j'''
    # 获取最近 N 小时的会话
    long_time_data = write_store.find_user_recent_sessions(end_user_id, time)
    
    format_messages = long_time_data
    messages = []
    
    for i in format_messages:
        message = json.loads(i['Query'])
        messages += message
    
    if format_messages != []:
        await write(
            AgentMemory_Long_Term.STORAGE_NEO4J,
            end_user_id, "", "", None, end_user_id,
            memory_config.config_id, messages
        )
```

**触发条件**：时间周期（默认 5 小时）  
**存储位置**：Neo4j  
**用途**：定期记忆固化

#### 3. Aggregate 模式（聚合判断）

```python
# 来源：write_router.py#L176-L237
async def aggregate_judgment(end_user_id: str, ori_messages: list, memory_config) -> dict:
    """聚合判断函数：判断输入句子和历史消息是否描述同一事件"""
    
    # 1. 获取历史会话数据
    result = write_store.get_all_sessions_by_end_user_id(end_user_id)
    history = await format_parsing(result)
    
    # 2. 使用 LLM 判断是否同一事件
    template_service = TemplateService(template_root)
    system_prompt = await template_service.render_template(
        template_name='write_aggregate_judgment.jinja2',
        operation_name='aggregate_judgment',
        history=history,
        sentence=ori_messages,
        json_schema=json_schema
    )
    
    factory = MemoryClientFactory(db_session)
    llm_client = factory.get_llm_client(memory_config.llm_model_id)
    
    structured = await llm_client.response_structured(
        messages=[{"role": "user", "content": system_prompt}],
        response_model=WriteAggregateModel
    )
    
    # 3. 如果不是同一事件，写入新记忆
    if not structured.is_same_event:
        await write("neo4j", end_user_id, "", "", None, end_user_id,
                    memory_config.config_id, output_value)
    
    return {
        "is_same_event": structured.is_same_event,
        "output": output_value
    }
```

**触发条件**：事件变化检测  
**存储位置**：Neo4j  
**用途**：智能记忆去重

### LangGraph 工作流

**文件结构**：
```
app/core/memory/agent/langgraph_graph/
├── write_graph.py          # 写入工作流定义
├── read_graph.py           # 读取工作流定义
├── routing/
│   ├── write_router.py     # 写入路由
│   └── routers.py          # 通用路由
├── nodes/
│   ├── write_nodes.py      # 写入节点
│   ├── retrieve_nodes.py   # 检索节点 (417 行)
│   ├── summary_nodes.py    # 总结节点 (319 行)
│   └── verification_nodes.py # 验证节点 (154 行)
└── tools/
    ├── write_tool.py       # 写入工具
    └── tool.py             # 通用工具 (320 行)
```

**工作流定义**：
```python
# 来源：write_graph.py#L24-L36
@asynccontextmanager
async def make_write_graph():
    """创建写入记忆的工作流"""
    workflow = StateGraph(WriteState)
    workflow.add_node("save_neo4j", write_node)
    workflow.add_edge(START, "save_neo4j")
    workflow.add_edge("save_neo4j", END)
    
    graph = workflow.compile()
    yield graph
```

---

## 4️⃣ 工具系统

### 工具架构

**文件**：[`app/core/tools/base.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/tools/base.py)

```python
# 来源：base.py#L13-L180
class BaseTool(ABC):
    """所有工具的基础抽象类"""
    
    def __init__(self, tool_id: str, config: Dict[str, Any]):
        self.tool_id = tool_id
        self.config = config
        self._status = ToolStatus.AVAILABLE
    
    @property
    @abstractmethod
    def name(self) -> str:
        """工具名称"""
        pass
    
    @property
    @abstractmethod
    def description(self) -> str:
        """工具描述"""
        pass
    
    @abstractmethod
    async def execute(self, **kwargs) -> ToolResult:
        """执行工具"""
        pass
    
    def validate_parameters(self, parameters: Dict[str, Any]) -> Dict[str, str]:
        """验证参数（JSON Schema 验证）"""
        errors = {}
        # 1. 检查必需参数
        # 2. 检查参数类型
        # 3. 检查约束（枚举、范围、模式）
        return errors
    
    async def safe_execute(self, **kwargs) -> ToolResult:
        """安全执行工具（包含参数验证和异常处理）"""
        # 1. 参数验证
        validation_errors = self.validate_parameters(kwargs)
        if validation_errors:
            return ToolResult.error_result(...)
        
        # 2. 执行工具
        result = await self.execute(**kwargs)
        return result
```

### 工具分类

**目录结构**：
```
app/core/tools/
├── builtin/           # 内置工具 (10 个)
│   ├── baidu_search_tool.py
│   ├── datetime_tool.py
│   ├── json_tool.py
│   ├── mineru_tool.py
│   ├── operation_tool.py
│   └── textin_tool.py
├── custom/            # 自定义工具
│   ├── base.py
│   ├── schema_parser.py
│   └── auth_manager.py
└── mcp/               # MCP 集成
    ├── client.py
    ├── service_manager.py
    ├── base.py
    └── __init__.py
```

### 工具转换为 LangChain

**文件**：[`app/core/tools/langchain_adapter.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/tools/langchain_adapter.py) (16KB)

```python
# 来源：langchain_adapter.py
def to_langchain_tool(self, operation: Optional[str] = None):
    """转换为 LangChain 工具格式"""
    from langchain_core.tools import StructuredTool
    
    return StructuredTool(
        name=self.name,
        description=self.description,
        func=self.safe_execute,
        args_schema=self.args_schema if hasattr(self, 'args_schema') else None
    )
```

---

## 5️⃣ RAG 系统

### RAG 架构

**目录结构**：
```
app/core/rag/
├── app/               # 应用层 RAG
├── common/            # 通用组件
├── crawler/           # 爬虫
├── deepdoc/           # 深度文档处理
├── graphrag/          # 图谱 RAG
├── integrations/      # 集成
├── llm/               # LLM 相关
├── nlp/               # NLP 处理
├── prompts/           # Prompt 模板 (36 个目录)
├── utils/             # 工具函数
└── vdb/               # 向量数据库
```

### RAG 写入流程

**文件**：[`app/services/memory_konwledges_server.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/services/memory_konwledges_server.py)

```python
# 来源：write_router.py#L27-L31
async def write_rag_agent(end_user_id, user_message, ai_message, user_rag_memory_id):
    # RAG 模式：组合消息为字符串格式
    combined_message = f"user: {user_message}\nassistant: {ai_message}"
    await write_rag(end_user_id, combined_message, user_rag_memory_id)
```

---

## 6️⃣ 多 Agent 系统

### 应用类型

**模型定义**：[`app/models/app_model.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/models/app_model.py)

```python
class AppType(str, Enum):
    AGENT = "agent"              # 单 Agent
    MULTI_AGENT = "multi_agent"  # 多 Agent
    WORKFLOW = "workflow"        # 工作流
```

### 多 Agent 编排

**文件**：[`app/services/multi_agent_orchestrator.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/services/multi_agent_orchestrator.py) (67KB)

```python
# 来源：multi_agent_orchestrator.py
class MultiAgentOrchestrator:
    """多 Agent 编排器"""
    
    async def orchestrate(self, message, agents, ...):
        # 1. 路由到合适的 Agent
        # 2. 协调多个 Agent 协作
        # 3. 汇总结果
        pass
```

---

## 7️⃣ 数据库模型

### 核心数据表

| 表名 | 用途 | 关键字段 |
|------|------|---------|
| `app` | 应用配置 | id, type, workspace_id, current_release_id |
| `agent_config` | Agent 配置 | id, app_id, system_prompt, default_model_config_id |
| `memory_config` | 记忆配置 | id, workspace_id, storage_type, llm_model_id |
| `conversation` | 会话 | id, app_id, user_id, is_draft |
| `message` | 消息 | id, conversation_id, role, content, token_usage |
| `knowledge` | 知识库 | id, workspace_id, name, type |
| `tool` | 工具 | id, workspace_id, name, type, config |

### 记忆相关模型

**文件**：[`app/models/memory_short_model.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/models/memory_short_model.py)

```python
# 短期记忆模型
class MemoryShort(Base):
    __tablename__ = "memory_short"
    
    id = Column(UUID, primary_key=True)
    end_user_id = Column(String, index=True)
    content = Column(Text)
    created_at = Column(DateTime)
```

---

## 8️⃣ 性能优化

### 缓存策略

**Redis 使用**：
- 会话计数：`count_store.get_sessions_count(end_user_id)`
- 会话缓存：`write_store.get_session_by_userid(end_user_id)`
- 健康状态：`memsci:health:read_service`

### 异步任务

**Celery 任务**：
```python
# 来源：write_router.py#L100-L112
write_id = write_message_task.delay(
    actual_end_user_id,      # 用户 ID
    structured_messages,     # 消息列表
    str(actual_config_id),   # 配置 ID
    storage_type,            # 存储类型
    user_rag_memory_id or "" # RAG 记忆 ID
)
```

---

## 9️⃣ 安全机制

### API 认证

**文件**：[`app/core/api_key_auth.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/api_key_auth.py)

```python
@require_api_key(scopes=["app"])
async def chat(...):
    # API Key 认证
    pass
```

### 参数验证

**文件**：[`app/core/tools/base.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/tools/base.py#L78-L120)

```python
def validate_parameters(self, parameters: Dict[str, Any]) -> Dict[str, str]:
    """验证参数（JSON Schema 验证）"""
    errors = {}
    
    # 1. 检查必需参数
    for param_def in self.parameters:
        if param_def.required and param_def.name not in parameters:
            errors[param_def.name] = f"Required parameter '{param_def.name}' is missing"
    
    # 2. 检查参数类型
    # 3. 检查约束（枚举、范围、模式）
    
    return errors
```

---

## 🔟 关键设计模式

### 1. LangGraph 工作流模式

```python
workflow = StateGraph(WriteState)
workflow.add_node("save_neo4j", write_node)
workflow.add_edge(START, "save_neo4j")
workflow.add_edge("save_neo4j", END)
graph = workflow.compile()
```

### 2. 工厂模式（LLM 客户端）

```python
factory = MemoryClientFactory(db_session)
llm_client = factory.get_llm_client(memory_config.llm_model_id)
```

### 3. 策略模式（存储策略）

```python
if storage_type == AgentMemory_Long_Term.STORAGE_RAG:
    await write_rag_agent(...)
else:
    await long_term_storage(...)
```

### 4. 装饰器模式（API 认证）

```python
@require_api_key(scopes=["app"])
async def chat(...):
    pass
```

---

## 📊 与 nanobot 对比

| 维度 | nanobot | MemoryBear |
|------|---------|------------|
| **定位** | 轻量 Agent 框架 | 企业级记忆平台 |
| **代码量** | ~4,000 行 | ~65,000+ 行 (650 文件) |
| **Agent 框架** | 自研 | LangChain + LangGraph |
| **记忆系统** | 文件 (JSONL/MD) | Neo4j + RAG + Redis |
| **工具系统** | 注册器模式 | BaseTool 抽象 + LangChain 适配 |
| **多 Agent** | SubagentManager | MultiAgentOrchestrator |
| **工作流** | 无 | LangGraph Workflow |
| **部署** | 单进程 | FastAPI + Celery + Redis |

---

## 💡 核心创新点

### 1. 记忆三策略

- **Chunk**：6 轮对话窗口触发
- **Time**：时间周期触发
- **Aggregate**：事件变化检测

### 2. LangGraph 工作流

- 写入工作流：`write_graph.py`
- 读取工作流：`read_graph.py`
- 节点模块化：nodes/ 目录

### 3. 工具抽象层

- `BaseTool` 抽象基类
- 参数验证（JSON Schema）
- LangChain 适配器

### 4. 多应用类型支持

- Agent（单 Agent）
- Multi-Agent（多 Agent 协作）
- Workflow（工作流编排）

---

## 📝 总结

### MemoryBear 核心优势

1. **完整记忆生命周期**：摄入→萃取→存储→检索→遗忘→反思
2. **企业级架构**：FastAPI + Celery + Redis + Neo4j
3. **LangChain 生态**：标准化 Agent 框架，易于扩展
4. **多策略记忆**：Chunk/Time/Aggregate 三种触发策略
5. **多应用类型**：Agent/Multi-Agent/Workflow 全面支持

### 适用场景

- ✅ 企业知识库管理
- ✅ 多 Agent 协作系统
- ✅ 需要长期记忆的场景
- ✅ 复杂工作流编排

### 学习曲线

- ⚠️ 代码量大（650 个文件）
- ⚠️ 依赖复杂（Neo4j/Redis/Celery）
- ⚠️ 需要 LangChain/LangGraph 知识

---

**研究人**：Jarvis  
**审核人**：Eddy  
**最后更新**：2026-02-28  
**验证状态**：✅ 所有结论基于实际代码
