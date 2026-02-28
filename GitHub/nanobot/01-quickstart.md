# 快速开始 - 5分钟上手 nanobot

## 🚀 30秒快速安装

### 方法1：从源码安装（推荐开发者）

```bash
git clone https://github.com/HKUDS/nanobot.git
cd nanobot
pip install -e .
```

### 方法2：使用uv安装（快速稳定）

```bash
uv tool install nanobot-ai
```

### 方法3：从PyPI安装

```bash
pip install nanobot-ai
```

---

## ⚙️ 1分钟配置

### 初始化配置

```bash
nanobot onboard
```

这会创建：
- 配置文件：`~/.nanobot/config.json`
- 工作区：`~/.nanobot/workspace/`
- 引导文件：`AGENTS.md`, `SOUL.md`, `USER.md`, `MEMORY.md`

### 获取API密钥

**推荐：OpenRouter（支持所有主流模型）**

1. 访问 https://openrouter.ai/keys
2. 注册并获取API密钥（格式：`sk-or-v1-...`）
3. 编辑配置文件

```bash
vim ~/.nanobot/config.json
```

添加以下内容：

```json
{
  "providers": {
    "openrouter": {
      "apiKey": "sk-or-v1-你的密钥"
    }
  },
  "agents": {
    "defaults": {
      "model": "anthropic/claude-opus-4-5",
      "provider": "openrouter"
    }
  }
}
```

### 可选：配置Brave搜索（增强网络能力）

```bash
# 在config.json中添加
"tools": {
  "web": {
    "search": {
      "apiKey": "你的Brave密钥"
    }
  }
}
```

获取Brave密钥：https://brave.com/search/api

---

## 💬 2分钟测试

### CLI交互模式

```bash
nanobot agent
```

你会看到：

```
🐈 nanobot Interactive mode (type exit or Ctrl+C to quit)

You: 你好
```

输入消息并回车，Agent会响应。

### 单次消息模式

```bash
nanobot agent -m "帮我分析这个项目结构"
```

---

## 📱 连接聊天平台

### Telegram（推荐）

**1. 创建Bot**
```
在Telegram中搜索 @BotFather
发送 /newbot
按提示设置名称和用户名
复制token（格式：123456:ABC-DEF...）
```

**2. 获取User ID**
```
Telegram设置 → 用户名显示为@yourUserId
复制@后面的内容（不含@）
```

**3. 配置nanobot**

编辑 `~/.nanobot/config.json`：

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "你的Bot_Token",
      "allowFrom": ["你的User_ID"]
    }
  }
}
```

**4. 启动Gateway**

```bash
nanobot gateway
```

✅ 现在可以通过Telegram与nanobot对话了！

### Discord

**1. 创建Bot应用**
```
访问 https://discord.com/developers/applications
Create Application → Bot → Add Bot
复制Bot Token（格式：MTI...）
启用 MESSAGE CONTENT INTENT
```

**2. 获取User ID**
```
Discord设置 → Advanced → 开启开发者模式
右键头像 → Copy User ID
```

**3. 配置**

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "你的Bot_Token",
      "allowFrom": ["你的User_ID"]
    }
  }
}
```

### Feishu（飞书）

**1. 创建应用**
```
访问 https://open.feishu.cn/app
创建应用 → 启用Bot能力
添加权限：im:message（发送消息）
添加事件：im.message.receive_v1（接收消息）
选择长连接模式
复制 App ID 和 App Secret
```

**2. 配置**

```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "cli_xxx",
      "appSecret": "xxx",
      "allowFrom": []
    }
  }
}
```

### 其他平台

查看完整配置：[README.md](https://github.com/HKUDS/nanobot#-chat-apps)

---

## 🎯 常用命令

### Agent命令

```bash
# CLI交互
nanobot agent

# 单次查询
nanobot agent -m "你的问题"

# 带日志模式
nanobot agent --logs

# 禁用Markdown渲染
nanobot agent --no-markdown
```

### Gateway命令

```bash
# 启动网关（连接所有配置的聊天平台）
nanobot gateway

# 指定端口
nanobot gateway --port 8080

# 详细输出
nanobot gateway --verbose
```

### 状态查看

```bash
# 查看配置状态
nanobot status
```

输出示例：
```
🐈 nanobot Status

Config: /Users/eddy/.nanobot/config.json ✓
Workspace: /Users/eddy/.nanobot/workspace ✓
Model: anthropic/claude-opus-4-5
OpenRouter: ✓
```

### Cron任务（定时任务）

```bash
# 添加任务
nanobot cron add --name "daily" --message "Good morning!" --cron "0 9 * * *"

# 列出任务
nanobot cron list

# 删除任务
nanobot cron remove <job_id>

# 启用/禁用
nanobot cron enable <job_id>
nanobot cron enable <job_id> --disable

# 手动运行
nanobot cron run <job_id>
```

### Channel管理

```bash
# 查看Channel状态
nanobot channels status

# WhatsApp QR登录
nanobot channels login
```

---

## 📁 Workspace结构

初始化后，`~/.nanobot/workspace/` 结构如下：

```
~/.nanobot/workspace/
├── AGENTS.md          # Agent身份定义
├── SOUL.md            # Agent性格特征
├── USER.md            # 你的使用偏好
├── TOOLS.md           # 工具使用指南
├── HEARTBEAT.md       # 定期任务配置
├── MEMORY.md           # 长期记忆（LLM写入）
├── HISTORY.md          # 历史日志（grep可搜索）
├── skills/            # 自定义技能
│   └── 你的技能/
│       └── SKILL.md
└── sessions/          # 会话历史
    ├── telegram:123456.jsonl
    ├── discord:789.jsonl
    └── cli:direct.jsonl
```

### 自定义配置示例

**定义Agent身份**

编辑 `~/.nanobot/workspace/AGENTS.md`：

```markdown
# Agent定义

你是一位专业的Python开发者助手，擅长：
- 代码审查与重构
- 性能优化
- 测试编写

## 开发原则

- 优先使用类型提示
- 遵循PEP 8规范
- 编写文档字符串
```

**设置使用偏好**

编辑 `~/.nanobot/workspace/USER.md`：

```markdown
# 使用偏好

## 输出格式
- 代码块使用Python语法高亮
- 表格使用Markdown表格

## 交互风格
- 简洁直接
- 避免冗余解释
```

---

## 🔧 进阶配置

### Provider完整配置

```json
{
  "providers": {
    "openrouter": {
      "apiKey": "sk-or-v1-xxx"
    },
    "anthropic": {
      "apiKey": "sk-ant-xxx"
    },
    "openai": {
      "apiKey": "sk-xxx"
    },
    "deepseek": {
      "apiKey": "sk-xxx"
    },
    "groq": {
      "apiKey": "gsk_xxx"
    }
  }
}
```

### Agent参数调优

```json
{
  "agents": {
    "defaults": {
      "model": "anthropic/claude-opus-4-5",
      "temperature": 0.7,        // 创造性（0-1）
      "maxTokens": 4096,          // 最大token数
      "maxToolIterations": 40,     // 最大工具调用次数
      "memoryWindow": 100          // 记忆窗口大小
    }
  }
}
```

### 安全配置

```json
{
  "tools": {
    "restrictToWorkspace": true,   // 限制工具访问workspace
    "exec": {
      "timeout": 60,              // Shell超时（秒）
      "pathAppend": "/usr/sbin"   // 额外PATH目录
    },
    "web": {
      "search": {
        "apiKey": "Brave密钥"
      }
    }
  }
}
```

---

## 🐛 故障排除

### 问题1：API密钥错误

```
Error: No API key configured. Set one in ~/.nanobot/config.json
```

**解决：**
```bash
# 编辑config.json添加provider
vim ~/.nanobot/config.json
```

### 问题2：Channel无法连接

```
Telegram channel not available: ...
```

**解决：**
```bash
# 检查依赖
pip show python-telegram-bot

# 重新安装
pip install --upgrade python-telegram-bot[socks]
```

### 问题3：内存溢出

```
Error: Command blocked by safety guard (path outside working dir)
```

**解决：**
```json
{
  "tools": {
    "restrictToWorkspace": false  // 临时放宽限制
  }
}
```

### 问题4：LLM无响应

```bash
# 启用日志模式
nanobot agent --logs

# 查看详细错误
cat ~/.nanobot/workspace/sessions/*.jsonl
```

---

## 📚 学习资源

- **官方文档**：[README.md](https://github.com/HKUDS/nanobot)
- **项目源码**：/Users/eddy/Workspace/nanobot
- **社区讨论**：[GitHub Discussions](https://github.com/HKUDS/nanobot/discussions)
- **问题反馈**：[GitHub Issues](https://github.com/HKUDS/nanobot/issues)

---

## 🚀 下一步

1. **理解架构** → [01-整体架构.md](./01-整体架构.md)
2. **学习流程** → [02-消息处理流程.md](./02-消息处理流程.md)
3. **掌握工具** → [03-工具系统.md](./03-工具系统.md)
4. **深入学习** → [04-核心模块详解.md](./04-核心模块详解.md)
5. **开始扩展** → [06-扩展开发指南.md](./06-扩展开发指南.md)

---

## ✅ 检查清单

安装完成：
- [ ] nanobot已安装
- [ ] API密钥已配置
- [ ] Workspace已创建
- [ ] CLI模式测试成功
- [ ] 至少一个Channel已配置

进阶功能：
- [ ] 定时任务已设置
- [ ] 自定义技能已创建
- [ ] 安全限制已配置
- [ ] Agent身份已自定义
- [ ] 多Provider已配置

祝使用愉快！🐈
