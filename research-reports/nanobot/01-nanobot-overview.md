# nanobot - 项目概览和架构分析

**研究阶段**: Phase 1  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能

---

## 📊 项目概览

### 核心定位

**nanobot** 是一个超轻量级个人 AI 助手，核心代码仅~4,000 行，比 Clawdbot 的 43 万行小 99%。

**GitHub**: https://github.com/HKUDS/nanobot  
**Stars**: 23,839 ⭐  
**许可证**: MIT  
**Python 版本**: 3.11+

---

### 核心价值主张

**问题**: 现有 Agent 框架（如 OpenClaw）过于复杂（43 万行代码），难以理解和部署

**解决方案**: 
- ✅ 超轻量（~4,000 行核心代码）
- ✅ 研究友好（代码清晰易读）
- ✅ 快速部署（一键启动）
- ✅ 功能完整（11 个 Channels + 多种 Tools）

**类比**: OpenClaw 的轻量级替代方案

---

### 核心功能

| 功能 | 说明 | 示例 |
|------|------|------|
| **24/7 实时市场分析** | 实时搜索和分析市场数据 | 股票分析、趋势发现 |
| **全栈软件工程师** | 代码开发和部署 | 开发、部署、扩展 |
| **智能日程管理** | 日常任务管理 | 日程安排、自动化 |
| **个人知识助手** | 知识库管理 | 学习、记忆、推理 |

---

## 🏗️ 系统架构

### 分层架构

```
┌─────────────────────────────────────┐
│          CLI 层                      │
│  nanobot agent -m "Hello"           │
│  (nanobot/cli/commands.py)          │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│        Channels 层                   │
│  - Feishu/Slack/Discord/Email/...  │
│  (nanobot/channels/*/channel.py)    │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│        MessageBus 层                 │
│  - 消息队列和路由                    │
│  (nanobot/bus/queue.py)             │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│        AgentLoop 层 (核心)           │
│  - 接收消息                          │
│  - 构建上下文                        │
│  - 调用 LLM                          │
│  - 执行工具调用                      │
│  - 发送响应                          │
│  (nanobot/agent/loop.py)            │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│        Tools 层                      │
│  - 11 个内置工具                     │
│  - MCP 工具支持                      │
│  (nanobot/agent/tools/*)            │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│        Providers 层                  │
│  - LLM Provider 抽象                 │
│  - 支持多种模型                      │
│  (nanobot/providers/*)              │
└─────────────────────────────────────┘
```

---

### 核心模块

| 模块 | 目录 | 代码行 | 职责 |
|------|------|--------|------|
| **AgentLoop** | agent/loop.py | ~400 行 | 核心处理引擎 |
| **ContextBuilder** | agent/context.py | ~200 行 | 上下文构建 |
| **MemoryStore** | agent/memory.py | ~150 行 | 记忆存储 |
| **ToolRegistry** | agent/tools/registry.py | ~100 行 | 工具注册 |
| **MessageBus** | bus/queue.py | ~200 行 | 消息队列 |
| **Channels** | channels/ | ~1,000 行 | 11 个 Channels |
| **Providers** | providers/ | ~500 行 | LLM Provider |
| **Skills** | skills/ | ~300 行 | 技能系统 |

**总核心代码**: ~3,932 行

---

## 🧶 入口点分析（毛线团研究法 - 线头识别）

### CLI 入口

**文件**: `nanobot/__main__.py` → `nanobot/cli/commands.py`

**使用方式**:
```bash
# 基本用法
nanobot agent -m "Hello"

# 指定模型
nanobot agent -m "Hello" --model qwen-plus

# 工作空间
nanobot agent -m "Hello" --workspace ./my-project
```

**核心代码**:
```python
# __main__.py
from nanobot.cli.commands import app

if __name__ == "__main__":
    app()
```

```python
# cli/commands.py
@app.command()
def agent(
    message: str = typer.Option(..., "--msg", "-m"),
    model: str | None = None,
    workspace: Path = typer.Option(Path.cwd(), "--workspace", "-w"),
):
    """Run nanobot agent with a message."""
    # 1. 加载配置
    config = load_config()
    
    # 2. 创建 AgentLoop
    loop = AgentLoop(...)
    
    # 3. 运行
    asyncio.run(loop.run(message))
```

---

### Python API 入口

**文件**: `nanobot/agent/loop.py`

**使用方式**:
```python
from nanobot.agent.loop import AgentLoop
from nanobot.bus.queue import MessageBus
from nanobot.providers.base import LLMProvider

# 创建 AgentLoop
loop = AgentLoop(
    bus=MessageBus(),
    provider=LLMProvider(),
    workspace=Path("./workspace"),
    model="qwen-plus",
)

# 运行
await loop.run("Hello")
```

---

## 🔗 完整调用链（毛线团研究法 - 顺线走）

### 消息处理流程

```mermaid
sequenceDiagram
    autonumber
    participant User as 用户
    participant Channel as Channel
    participant Bus as MessageBus
    participant Loop as AgentLoop
    participant LLM as LLM Provider
    participant Tool as Tools
    
    User->>Channel: 发送消息
    Channel->>Bus: publish_inbound(event)
    Bus->>Loop: consume_inbound()
    Loop->>Loop: 1. 获取/创建会话
    Loop->>Loop: 2. 构建上下文
    Loop->>LLM: 3. 调用 LLM
    LLM-->>Loop: 返回响应 (content + tool_calls)
    alt 有工具调用
        Loop->>Loop: 4. 解析工具调用
        Loop->>Tool: 5. 执行工具
        Tool-->>Loop: 返回结果
        Loop->>Loop: 6. 添加结果到上下文
        Loop->>LLM: 7. 继续迭代 (最多 40 次)
        LLM-->>Loop: 返回最终响应
    end
    Loop->>Bus: 8. publish_outbound(response)
    Bus->>Channel: 发送响应
    Channel->>User: 返回结果
```

---

### 关键代码位置

**1. AgentLoop 核心**:
```python
# agent/loop.py:100-200
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
    
    # 3. 调用 LLM
    response = await self.provider.chat(
        model=self.model,
        messages=context.messages,
        tools=self.tools.get_schema(),
        temperature=self.temperature,
        max_tokens=self.max_tokens,
    )
    
    # 4. 解析工具调用
    if response.tool_calls:
        for tool_call in response.tool_calls:
            result = await self.tools.execute(tool_call)
            # 添加结果到上下文，继续迭代
    
    # 5. 发送响应
    await self.bus.publish_outbound(
        channel=event.channel,
        chat_id=event.chat_id,
        message=response.content,
    )
```

**2. Channel 注册**:
```python
# channels/__init__.py
from .feishu.channel import FeishuChannel
from .slack.channel import SlackChannel
from .discord.channel import DiscordChannel
# ... 11 个 Channels

ALL_CHANNELS = {
    "feishu": FeishuChannel,
    "slack": SlackChannel,
    "discord": DiscordChannel,
    # ...
}
```

**3. Tool 注册**:
```python
# agent/loop.py:110-130
def _register_default_tools(self) -> None:
    """注册默认工具"""
    allowed_dir = self.workspace if self.restrict_to_workspace else None
    
    # 文件操作工具
    for cls in (ReadFileTool, WriteFileTool, EditFileTool, ListDirTool):
        self.tools.register(cls(workspace=self.workspace, allowed_dir=allowed_dir))
    
    # 执行工具
    self.tools.register(ExecTool(...))
    
    # Web 工具
    self.tools.register(WebSearchTool(api_key=self.brave_api_key))
    self.tools.register(WebFetchTool())
    
    # 消息工具
    self.tools.register(MessageTool(send_callback=self.bus.publish_outbound))
    
    # 子 Agent 工具
    self.tools.register(SpawnTool(manager=self.subagents))
```

---

## 🎯 设计模式识别（Superpowers - Systematic Analysis）

### 1. 命令模式（Command Pattern）

**实现**:
```python
# agent/tools/base.py
class Tool(ABC):
    @abstractmethod
    def execute(self, **kwargs) -> Any:
        """执行工具"""
        pass
    
    @abstractmethod
    def get_schema(self) -> dict:
        """获取工具 schema"""
        pass

# 每个工具是一个命令
class ReadFileTool(Tool):
    def execute(self, path: str) -> str:
        with open(path) as f:
            return f.read()
```

**优势**:
- ✅ 工具统一接口
- ✅ 易于扩展新工具
- ✅ 工具可组合

---

### 2. 观察者模式（Observer Pattern）

**实现**:
```python
# bus/queue.py
class MessageBus:
    def __init__(self):
        self._inbound_queue = asyncio.Queue()
        self._outbound_queue = asyncio.Queue()
    
    async def publish_inbound(self, event: InboundMessage):
        await self._inbound_queue.put(event)
    
    async def consume_inbound(self) -> InboundMessage:
        return await self._inbound_queue.get()
```

**优势**:
- ✅ 解耦 Channel 和 AgentLoop
- ✅ 支持异步处理
- ✅ 支持多消费者

---

### 3. 策略模式（Strategy Pattern）

**实现**:
```python
# providers/base.py
class LLMProvider(ABC):
    @abstractmethod
    async def chat(self, messages, **kwargs) -> LLMResponse:
        pass

# 每个 Provider 是独立策略
class QwenProvider(LLMProvider):
    async def chat(self, messages, **kwargs):
        # Qwen API 调用

class OpenAIProvider(LLMProvider):
    async def chat(self, messages, **kwargs):
        # OpenAI API 调用
```

**优势**:
- ✅ 支持多种 LLM
- ✅ 易于添加新 Provider
- ✅ 运行时可切换

---

### 4. 单例模式（Singleton Pattern）

**实现**:
```python
# config/manager.py
class ConfigManager:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._load_config()
        return cls._instance
```

**优势**:
- ✅ 配置全局唯一
- ✅ 延迟加载
- ✅ 线程安全

---

## 📊 代码统计

| 指标 | 数值 |
|------|------|
| **核心代码行** | ~3,932 行 |
| **Python 文件数** | ~100 个 |
| **Channels** | 11 个 |
| **Tools** | 11+ 个 |
| **Providers** | 10+ 个 |
| **Skills** | 内置 + 可扩展 |

---

## 🎯 Phase 1 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 理解项目定位 | 完成 | 轻量级 Agent 框架 |
| ✅ 理解核心架构 | 完成 | AgentLoop + Channels + Tools |
| ✅ 识别入口点 | 完成 | CLI + Python API |
| ✅ 追踪调用链 | 完成 | 消息处理流程 |
| ✅ 识别设计模式 | 完成 | 命令 + 观察者 + 策略 + 单例 |
| ✅ 绘制架构图 | 完成 | 见上文 |
| ✅ 代码位置索引 | 完成 | 关键代码位置 |

---

## 📝 研究笔记

### 关键发现

1. **AgentLoop 是核心**（~400 行）- 消息处理引擎
2. **Channels 抽象优秀** - 11 个 Channels 统一接口
3. **Tools 系统灵活** - 命令模式 + 注册机制
4. **Providers 可扩展** - 策略模式支持多种 LLM

### 待深入研究

- [ ] AgentLoop 详细实现（Phase 2）
- [ ] 11 个 Channels 详细分析（Phase 3）
- [ ] Tools 系统深度分析（Phase 3）
- [ ] 与 MemoryBear 对比（Phase 4）

---

## 🔗 下一步：Phase 2

**目标**: 深入分析 AgentLoop 和消息处理流程

**任务**:
- [ ] 分析 AgentLoop 实现细节
- [ ] 追踪消息处理完整流程
- [ ] 分析 Context 构建机制
- [ ] 分析 Memory 系统

**产出**: `02-agent-loop-analysis.md`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能
