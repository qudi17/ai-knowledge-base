# 文档管理规范

**生效日期**：2026-02-28  
**版本**：1.0

---

## 📋 核心原则

### 1. GitHub 是唯一写入点

```
✅ 正确流程：
创建/修改文档 → Git 提交 → 推送到 GitHub → 自动同步到 Obsidian

❌ 错误流程：
在 Obsidian 中修改 → 推送到 GitHub
```

### 2. 自动化 Git 操作

- ✅ 所有 Git 操作由 AI 助手自动完成
- ✅ 用户无需手动执行 git 命令
- ✅ 每次文档修改后自动推送

### 3. Obsidian 只读使用

- ✅ 手机查看（GitHub App 或 Obsidian Mobile）
- ✅ 搜索和浏览
- ❌ 不在 Obsidian 中编辑

---

## 🔄 工作流程

### 创建新文档

```
1. AI 助手创建文档到 ai-knowledge-base/
2. 自动 git add + commit + push
3. 推送到 GitHub
4. 自动同步到 Obsidian（只读副本）
```

### 更新现有文档

```
1. AI 助手修改文档
2. 自动 git add + commit + push
3. 推送到 GitHub
4. 自动同步到 Obsidian
```

### 查看文档

```
方式 1：GitHub App（推荐）
- 手机打开 GitHub App
- 进入仓库浏览

方式 2：GitHub Pages
- 浏览器访问 https://qudi17.github.io/ai-knowledge-base/

方式 3：Obsidian Mobile
- 作为只读 Vault 打开
```

---

## 📁 目录结构

```
ai-knowledge-base/
├── 📰 技术博客追踪/
│   ├── 工作流.md
│   ├── 学习看板.md
│   ├── 文章笔记模板.md
│   ├── Anthropic Engineering/
│   │   └── YYYY-MM-DD-文章标题.md
│   ├── 阅读笔记/
│   │   └── YYYY-MM-DD-主题.md
│   └── 实践记录/
│       └── YYYY-MM-DD-实践主题.md
├── 🔧 技术专项/
│   ├── YYYY-MM-DD-专题名称.md
│   └── ...
├── 📚 学习资料/
│   └── ...
├── README.md
├── SETUP.md
└── DOCUMENTATION.md (本文档)
```

---

## 📝 命名规范

### 文件名

| 类型 | 格式 | 示例 |
|------|------|------|
| 文章解读 | `YYYY-MM-DD-文章标题.md` | `2026-02-28-Prompt Caching 解读.md` |
| 技术专项 | `YYYY-MM-DD-专题名称.md` | `2026-02-28-LiteLLM 缓存指南.md` |
| 实践记录 | `YYYY-MM-DD-实践主题.md` | `2026-03-01-RAG 缓存 POC.md` |

### 提交信息

| 类型 | 格式 | 示例 |
|------|------|------|
| 新增文档 | `新增：文档标题` | `新增：LiteLLM 缓存实施指南` |
| 更新文档 | `更新：修改内容` | `更新：Provider 对比表添加新模型` |
| 删除文档 | `删除：文档标题` | `删除：过时的技术对比` |
| 格式修复 | `修复：问题描述` | `修复：错别字和格式问题` |

---

## 🤖 AI 助手职责

### 自动执行

1. **文档创建后**
   ```bash
   ./manage-docs.sh push "新增：文档标题"
   ```

2. **文档修改后**
   ```bash
   ./manage-docs.sh push "更新：修改内容"
   ```

3. **定期同步**
   ```bash
   ./manage-docs.sh sync
   ```

### 无需用户操作

- ❌ 不需要用户执行 git 命令
- ❌ 不需要用户手动推送
- ❌ 不需要用户管理分支

### 用户只需

- ✅ 告诉 AI 助手创建/修改什么文档
- ✅ 在 GitHub 或 Obsidian 中查看结果

---

## 📊 质量保证

### 推送前检查

- [ ] Markdown 格式正确
- [ ] 文件路径包含中文无问题
- [ ] Frontmatter 元数据完整
- [ ] 无敏感信息（API Keys、密码等）

### 推送后验证

- [ ] GitHub 仓库可访问
- [ ] Markdown 渲染正常
- [ ] 目录结构正确
- [ ] 提交历史更新

---

## 🔐 安全规范

### 禁止内容

- ❌ API Keys
- ❌ 密码和凭证
- ❌ 公司内部敏感信息
- ❌ 个人隐私数据

### 检查方法

```bash
# 推送前检查
git diff --cached | grep -i "api_key\|password\|secret\|token"

# 如果找到，立即删除
```

---

## 📱 查看方式

### GitHub App（推荐）

1. 下载：https://github.com/mobile
2. 登录账号
3. 打开 `qudi17/ai-knowledge-base`
4. 浏览文档（Markdown 自动渲染）

**优点**：
- ✅ 实时同步
- ✅ 支持搜索
- ✅ 离线缓存
- ✅ 评论和标注

### GitHub Pages

访问：https://qudi17.github.io/ai-knowledge-base/

**优点**：
- ✅ 网站形式
- ✅ 更好的阅读体验
- ✅ 可自定义主题

### Obsidian Mobile

1. 克隆仓库到手机
2. 作为 Obsidian Vault 打开
3. 只读浏览

**优点**：
- ✅ 支持双向链接查看
- ✅ 支持图谱视图
- ✅ 离线访问

---

## 📈 统计指标

### 每周统计

| 指标 | 目标 | 实际 |
|------|------|------|
| 新增文档 | 2 篇 | - |
| 更新文档 | 5 篇 | - |
| 推送次数 | 7 次 | - |

### 每月统计

| 指标 | 目标 | 实际 |
|------|------|------|
| 新增文档 | 10 篇 | - |
| 技术专项 | 2 个 | - |
| 文章解读 | 8 篇 | - |

---

## 🛠️ 工具脚本

### manage-docs.sh

```bash
# 推送文档
./manage-docs.sh push "提交信息"

# 同步到 Obsidian
./manage-docs.sh sync

# 查看状态
./manage-docs.sh status
```

### 自动执行

AI 助手会在每次文档修改后自动执行：

```bash
./manage-docs.sh push "自动更新：$(date +%Y-%m-%d)"
```

---

## 📝 更新日志

### 2026-02-28

- ✅ 创建文档管理规范
- ✅ 确定 GitHub 为主仓库
- ✅ Obsidian 设为只读副本
- ✅ 实现自动化脚本

---

**维护者**：Eddy  
**AI 助手**：Jarvis  
**仓库**：https://github.com/qudi17/ai-knowledge-base
