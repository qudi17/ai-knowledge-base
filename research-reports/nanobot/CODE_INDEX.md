# nanobot 研究 - 代码引用索引

**研究日期**: 2026-03-01  
**GitHub 仓库**: https://github.com/HKUDS/nanobot

---

## 📚 核心文件索引

### AgentLoop 核心

| 文件 | GitHub 链接 | 说明 |
|------|-----------|------|
| **agent/loop.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py) | Agent 循环核心（~400 行） |
| **agent/context.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/context.py) | 上下文构建器（~200 行） |
| **agent/memory.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/memory.py) | 记忆存储（~150 行） |
| **agent/session/** | [查看](https://github.com/HKUDS/nanobot/tree/main/nanobot/session) | 会话管理 |

---

### Channels 系统

| Channel | GitHub 链接 | 代码行 |
|---------|-----------|--------|
| **FeishuChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/feishu/channel.py) | ~150 行 |
| **SlackChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/slack/channel.py) | ~120 行 |
| **DiscordChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/discord/channel.py) | ~120 行 |
| **EmailChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/email/channel.py) | ~100 行 |
| **SMSChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/sms/channel.py) | ~80 行 |
| **WhatsAppChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/whatsapp/channel.py) | ~100 行 |
| **TelegramChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/telegram/channel.py) | ~100 行 |
| **WeChatChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/wechat/channel.py) | ~100 行 |
| **QQChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/qq/channel.py) | ~100 行 |
| **WebChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/web/channel.py) | ~80 行 |
| **CLIChannel** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/cli/channel.py) | ~60 行 |

**基类**: [`channels/base.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/channels/base.py)

---

### Tools 系统

| Tool | GitHub 链接 | 代码行 |
|------|-----------|--------|
| **ReadFileTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/filesystem.py#L10-L40) | ~30 行 |
| **WriteFileTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/filesystem.py#L45-L75) | ~30 行 |
| **EditFileTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/filesystem.py#L80-L130) | ~50 行 |
| **ListDirTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/filesystem.py#L135-L165) | ~30 行 |
| **ExecTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/shell.py) | ~50 行 |
| **WebSearchTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/web.py#L10-L50) | ~40 行 |
| **WebFetchTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/web.py#L55-L95) | ~40 行 |
| **MessageTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/message.py) | ~30 行 |
| **SpawnTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/spawn.py) | ~40 行 |
| **CronTool** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/cron.py) | ~40 行 |
| **MCP Tools** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/mcp.py) | ~100 行 |

**基类**: [`agent/tools/base.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/base.py)  
**注册表**: [`agent/tools/registry.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/tools/registry.py)

---

### Providers 系统

| Provider | GitHub 链接 | 说明 |
|----------|-----------|------|
| **LLMProvider** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/providers/base.py) | Provider 抽象基类 |
| **QwenProvider** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/providers/qwen.py) | 通义千问 |
| **OpenAIProvider** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/providers/openai.py) | OpenAI |
| **DeepSeekProvider** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/providers/deepseek.py) | DeepSeek |
| **MoonshotProvider** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/providers/moonshot.py) | Moonshot/Kimi |
| **vLLMProvider** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/providers/vllm.py) | vLLM 本地部署 |

---

### Skills 系统

| 文件 | GitHub 链接 | 说明 |
|------|-----------|------|
| **skills/base.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/skills/base.py) | Skill 基类 |
| **skills/registry.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/skills/registry.py) | Skill 注册表 |
| **skills/web_search/** | [查看](https://github.com/HKUDS/nanobot/tree/main/nanobot/skills/web_search) | Web 搜索 Skill |
| **skills/code_analysis/** | [查看](https://github.com/HKUDS/nanobot/tree/main/nanobot/skills/code_analysis) | 代码分析 Skill |
| **skills/data_analysis/** | [查看](https://github.com/HKUDS/nanobot/tree/main/nanobot/skills/data_analysis) | 数据分析 Skill |

---

### 消息总线

| 文件 | GitHub 链接 | 说明 |
|------|-----------|------|
| **bus/queue.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/bus/queue.py) | 消息队列实现 |
| **bus/events.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/bus/events.py) | 事件定义 |

---

### CLI 入口

| 文件 | GitHub 链接 | 说明 |
|------|-----------|------|
| **__main__.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/__main__.py) | 模块入口 |
| **cli/commands.py** | [查看](https://github.com/HKUDS/nanobot/blob/main/nanobot/cli/commands.py) | CLI 命令定义 |

---

## 🔗 研究报告链接

| 报告 | 链接 |
|------|------|
| **Phase 1: 项目概览** | [01-nanobot-overview.md](./01-nanobot-overview.md) |
| **Phase 2: Agent 循环** | [02-agent-loop-analysis.md](./02-agent-loop-analysis.md) |
| **Phase 3: Channels/Tools** | [03-channels-tools-analysis.md](./03-channels-tools-analysis.md) |
| **Phase 4: 对比应用** | [04-comparison-application.md](./04-comparison-application.md) |

---

**创建日期**: 2026-03-01  
**维护者**: Jarvis
