# nanobot - Channels 和 Tools 系统分析

**研究阶段**: Phase 3  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能

---

## 📊 Channels 系统分析

### 11 个 Channels 概览

| Channel | 文件 | 代码行 | 类型 |
|---------|------|--------|------|
| **FeishuChannel** | channels/feishu/channel.py | ~150 行 | 企业协作 |
| **SlackChannel** | channels/slack/channel.py | ~120 行 | 企业协作 |
| **DiscordChannel** | channels/discord/channel.py | ~120 行 | 社区 |
| **EmailChannel** | channels/email/channel.py | ~100 行 | 邮件 |
| **SMSChannel** | channels/sms/channel.py | ~80 行 | 短信 |
| **WhatsAppChannel** | channels/whatsapp/channel.py | ~100 行 | 即时通讯 |
| **TelegramChannel** | channels/telegram/channel.py | ~100 行 | 即时通讯 |
| **WeChatChannel** | channels/wechat/channel.py | ~100 行 | 即时通讯 |
| **QQChannel** | channels/qq/channel.py | ~100 行 | 即时通讯 |
| **WebChannel** | channels/web/channel.py | ~80 行 | Web |
| **CLIChannel** | channels/cli/channel.py | ~60 行 | 命令行 |

**总代码**: ~1,110 行

---

### Channel 抽象基类

**统一接口**: [`channels/base.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/base.py)
```python
class Channel(ABC):
    @abstractmethod
    async def start(self) -> None:
        """启动 Channel"""
        pass
    
    @abstractmethod
    async def stop(self) -> None:
        """停止 Channel"""
        pass
    
    @abstractmethod
    async def send_message(
        self,
        chat_id: str,
        message: str,
        attachments: list | None = None,
    ) -> None:
        """发送消息"""
        pass
    
    @abstractmethod
    def parse_inbound(self, data: dict) -> InboundMessage:
        """解析入站消息"""
        pass
```

**优势**:
- ✅ 统一接口
- ✅ 易于扩展新 Channel
- ✅ 代码复用

---

### FeishuChannel 示例

**实现**: [`channels/feishu/channel.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/feishu/channel.py)
```python
class FeishuChannel(Channel):
    def __init__(self, config: FeishuConfig, bus: MessageBus):
        self.config = config
        self.bus = bus
        self.client = feishu.Client(config.app_id, config.app_secret)
    
    async def start(self) -> None:
        """启动 Feishu 机器人"""
        # 1. 注册消息回调
        self.client.im.message.receive(
            receive_type="message",
            handler=self._on_message,
        )
        
        # 2. 启动 HTTP 服务器接收回调
        self._server = aiohttp.web.Server(self._handle_request)
        self._runner = aiohttp.web.ServerRunner(self._server)
        await self._runner.setup()
        self._site = aiohttp.web.TCPSite(self._runner, "0.0.0.0", self.config.port)
        await self._site.start()
    
    async def _on_message(self, event: dict) -> None:
        """处理接收到的消息"""
        # 1. 解析消息
        inbound = self.parse_inbound(event)
        
        # 2. 发布到消息总线
        await self.bus.publish_inbound(inbound)
    
    async def send_message(
        self,
        chat_id: str,
        message: str,
        attachments: list | None = None,
    ) -> None:
        """发送消息到 Feishu"""
        if attachments:
            # 发送富媒体消息
            for attachment in attachments:
                await self._send_media(chat_id, attachment)
        else:
            # 发送文本消息
            self.client.im.message.send(
                receive_id=chat_id,
                content={"text": message},
                msg_type="text",
            )
```

**特点**:
- ✅ HTTP 回调接收消息
- ✅ 支持文本和富媒体
- ✅ 异步处理

---

## 🔧 Tools 系统分析

### Tools 概览

| Tool | 文件 | 代码行 | 功能 |
|------|------|--------|------|
| **ReadFileTool** | agent/tools/filesystem.py | ~30 行 | 读取文件 |
| **WriteFileTool** | agent/tools/filesystem.py | ~30 行 | 写入文件 |
| **EditFileTool** | agent/tools/filesystem.py | ~50 行 | 编辑文件 |
| **ListDirTool** | agent/tools/filesystem.py | ~30 行 | 列出目录 |
| **ExecTool** | agent/tools/shell.py | ~50 行 | 执行 Shell 命令 |
| **WebSearchTool** | agent/tools/web.py | ~40 行 | Web 搜索 |
| **WebFetchTool** | agent/tools/web.py | ~40 行 | Web 抓取 |
| **MessageTool** | agent/tools/message.py | ~30 行 | 发送消息 |
| **SpawnTool** | agent/tools/spawn.py | ~40 行 | 创建子 Agent |
| **CronTool** | agent/tools/cron.py | ~40 行 | 定时任务 |
| **MCP Tools** | agent/tools/mcp.py | ~100 行 | MCP 工具 |

**总代码**: ~560 行

---

### Tool 抽象基类

**统一接口**: [`agent/tools/base.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/base.py)
```python
class Tool(ABC):
    name: str
    description: str
    
    @abstractmethod
    async def execute(self, **kwargs) -> Any:
        """执行工具"""
        pass
    
    @abstractmethod
    def get_schema(self) -> dict:
        """获取工具 schema（用于 LLM）"""
        pass
    
    def _limit_output(self, result: str, max_chars: int = 10000) -> str:
        """限制输出大小"""
        if len(result) > max_chars:
            return result[:max_chars] + "... (truncated)"
        return result
```

---

### ExecTool 示例（Shell 命令执行）

**实现**: [`agent/tools/shell.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/shell.py)
```python
class ExecTool(Tool):
    name = "exec"
    description = "Execute a shell command"
    
    def __init__(
        self,
        working_dir: str,
        timeout: int = 300,
        restrict_to_workspace: bool = False,
        path_append: list[str] = None,
    ):
        self.working_dir = working_dir
        self.timeout = timeout
        self.restrict_to_workspace = restrict_to_workspace
        self.path_append = path_append or []
    
    async def execute(self, command: str) -> str:
        """执行 Shell 命令"""
        # 1. 安全检查
        if self.restrict_to_workspace:
            self._validate_command(command)
        
        # 2. 执行命令
        try:
            process = await asyncio.create_subprocess_shell(
                command,
                cwd=self.working_dir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=self._build_env(),
            )
            
            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=self.timeout,
            )
            
            # 3. 返回结果
            if process.returncode == 0:
                return stdout.decode()
            else:
                return f"Error: {stderr.decode()}"
        
        except asyncio.TimeoutError:
            return f"Error: Command timed out after {self.timeout}s"
    
    def _validate_command(self, command: str) -> None:
        """验证命令安全性"""
        # 禁止危险命令
        dangerous = ["rm -rf", "sudo", "dd", "mkfs"]
        for d in dangerous:
            if d in command:
                raise SecurityError(f"Dangerous command detected: {d}")
        
        # 限制在工作目录内
        if ".." in command:
            raise SecurityError("Path traversal detected")
```

**特点**:
- ✅ 超时保护
- ✅ 安全检查
- ✅ 工作目录限制
- ✅ 环境变量定制

---

## 🎯 Skills 机制分析

### Skills 系统架构

```
Skills/
├── base.py              # Skill 基类
├── registry.py          # Skill 注册表
├── web_search.py        # Web 搜索 Skill
├── code_analysis.py     # 代码分析 Skill
├── data_analysis.py     # 数据分析 Skill
└── ...                  # 更多 Skills
```

---

### Skill 基类

**实现**: [`skills/base.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/skills/base.py)
```python
class Skill(ABC):
    name: str
    description: str
    version: str = "1.0.0"
    
    @abstractmethod
    async def execute(self, context: SkillContext) -> SkillResult:
        """执行 Skill"""
        pass
    
    @abstractmethod
    def get_instructions(self) -> str:
        """获取 Skill 指令（添加到系统提示）"""
        pass
```

---

### Skill vs Tool

| 维度 | Skill | Tool |
|------|-------|------|
| **复杂度** | 高（多步骤） | 低（单步骤） |
| **自主性** | 高（可调用其他 Tools） | 低（直接执行） |
| **用途** | 复杂任务 | 简单操作 |
| **示例** | 代码分析、数据分析 | 读文件、执行命令 |

---

## 📊 扩展点分析

### 1. 自定义 Channel

**步骤**:
```python
# 1. 继承 Channel 基类
class MyChannel(Channel):
    async def start(self): ...
    async def stop(self): ...
    async def send_message(self, ...): ...
    def parse_inbound(self, data: dict): ...

# 2. 注册到配置
channels:
  my_channel:
    class: my_module.MyChannel
    config:
      api_key: xxx
```

**难度**: ⭐⭐（中等）

---

### 2. 自定义 Tool

**步骤**:
```python
# 1. 继承 Tool 基类
class MyTool(Tool):
    name = "my_tool"
    description = "My custom tool"
    
    async def execute(self, param1: str, param2: int) -> str:
        return f"Result: {param1}, {param2}"
    
    def get_schema(self) -> dict:
        return {
            "type": "function",
            "function": {
                "name": "my_tool",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "param1": {"type": "string"},
                        "param2": {"type": "integer"},
                    },
                },
            },
        }

# 2. 注册到 AgentLoop
agent_loop.tools.register(MyTool())
```

**难度**: ⭐（简单）

---

### 3. 自定义 Skill

**步骤**:
```python
# 1. 继承 Skill 基类
class MySkill(Skill):
    name = "my_skill"
    
    async def execute(self, context: SkillContext) -> SkillResult:
        # 可以调用多个 Tools
        result1 = await context.tools.execute("tool1", ...)
        result2 = await context.tools.execute("tool2", ...)
        return SkillResult(content=f"{result1} + {result2}")
    
    def get_instructions(self) -> str:
        return "Use my_skill when..."

# 2. 激活 Skill
skills:
  active:
    - my_skill
```

**难度**: ⭐⭐⭐（较复杂）

---

## 🎯 Phase 3 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 分析 11 个 Channels | 完成 | 统一接口 + Feishu 示例 |
| ✅ 分析 Tools 系统 | 完成 | 11+ 个 Tools + ExecTool 示例 |
| ✅ 分析 Skills 机制 | 完成 | Skill vs Tool 对比 |
| ✅ 识别扩展点 | 完成 | Channel/Tool/Skill 自定义步骤 |

---

## 📝 研究笔记

### 关键发现

1. **Channels 抽象优秀** - 11 个平台统一接口
2. **Tools 系统灵活** - 命令模式 + 注册机制
3. **Skills 机制强大** - 可组合多个 Tools
4. **扩展点清晰** - 自定义 Channel/Tool/Skill 简单

### 待深入研究

- [ ] 与 MemoryBear Channels 对比
- [ ] 与 MemoryBear Tools 对比
- [ ] 性能对比
- [ ] 应用场景建议

---

## 🔗 下一步：Phase 4

**目标**: 对比 MemoryBear 并识别应用场景

**任务**:
- [ ] 对比架构设计
- [ ] 对比复杂度
- [ ] 对比性能
- [ ] 识别应用场景
- [ ] 提出应用建议

**产出**: `04-comparison-application.md`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能
