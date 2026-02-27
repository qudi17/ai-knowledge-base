# AI 技术知识库 🤖

> Eddy 的 AI 技术学习与实践经验总结

**最后更新**：2026-02-28  
**维护者**：Eddy（系统架构师）

---

## 📚 知识库结构

```
📂 ai-knowledge-base/
├── 📰 技术博客追踪/
│   ├── 工作流.md              # 学习工作流程
│   ├── 学习看板.md            # 进度追踪
│   ├── 文章笔记模板.md        # 笔记模板
│   ├── Anthropic Engineering/ # Anthropic 文章解读
│   ├── 阅读笔记/              # 深度阅读笔记
│   └── 实践记录/              # 实践总结
├── 🔧 技术专项/
│   ├── Provider 特定功能对比.md    # Anthropic vs OpenAI
│   ├── LiteLLM 缓存实施指南.md     # 缓存实施完整指南
│   └── ...
└── README.md
```

---

## 📰 技术博客追踪

### 学习工作流程

```
阅读 📖 → 笔记 📝 → 实践 🔧 → 分享 📢
```

详细说明：[工作流.md](./📰 技术博客追踪/工作流.md)

### 学习进度

查看当前进度和待办事项：[学习看板.md](./📰 技术博客追踪/学习看板.md)

### 文章解读

| 日期 | 文章 | 状态 |
|------|------|------|
| 2026-02-27 | [Prompt Caching 深度解读](./📰 技术博客追踪/阅读笔记/2026-02-27-Prompt%20Caching%20深度解读.md) | ✅ 已完成 |
| 2026-02-27 | [Anthropic Engineering 创刊号](./📰 技术博客追踪/Anthropic%20Engineering/) | ✅ 已完成 |

---

## 🔧 技术专项

### 已完成的专题

| 专题 | 说明 | 状态 |
|------|------|------|
| [Provider 特定功能对比](./🔧 技术专项/Provider 特定功能对比.md) | Anthropic vs OpenAI 平台功能对比 | ✅ 完成 |
| [LiteLLM 缓存实施指南](./🔧 技术专项/LiteLLM 缓存实施指南.md) | RAG 系统缓存完整实施指南 | ✅ 完成 |

### 规划中的专题

- [ ] RAG 评估体系建设
- [ ] Agent 架构模式
- [ ] 成本优化实践
- [ ] 性能调优指南

---

## 📅 定期推送

### 定时任务

| 任务 | 时间 | 说明 |
|------|------|------|
| 📰 AI 新闻 | 每天 09:00 | AI 行业动态 |
| 🐙 GitHub 项目 | 每天 13:00 | 热门 AI 项目 |
| 🧠 LLM 知识 | 每天 19:00 | LLM 实用知识 |
| 📚 Anthropic 周报 | 每周一 09:00 | 深度文章解读 |

---

## 📱 手机查看

### 方式 1：GitHub App（推荐）

1. 下载 [GitHub App](https://github.com/mobile)
2. 打开此仓库
3. 浏览 Markdown 文件（自动渲染）

### 方式 2：GitHub Pages（开发中）

部署为静态网站，支持搜索和目录导航

### 方式 3：Obsidian Mobile

1. 下载 Obsidian Mobile
2. 将此仓库克隆到手机
3. 作为 Obsidian Vault 打开

---

## 🔄 同步机制

### 自动同步（开发中）

使用 GitHub Actions 实现：
- Obsidian 修改 → 自动推送到 GitHub
- GitHub 修改 → 自动拉取到本地

### 手动同步

```bash
# 本地修改后
cd /path/to/ai-knowledge-base
git add .
git commit -m "更新内容"
git push
```

---

## 📊 学习统计

| 指标 | 目标 | 当前 | 完成率 |
|------|------|------|-------|
| 文章阅读 | 48 篇/年 | 2 篇 | 4% |
| 实践项目 | 24 个/年 | 0 个 | 0% |
| 团队分享 | 12 次/年 | 0 次 | 0% |
| 生产应用 | 4 个/年 | 0 个 | 0% |

---

## 💡 使用建议

### 手机查看

- ✅ 通勤时间阅读文章解读
- ✅ 会议间隙查看实施指南
- ✅ 随时记录想法和笔记

### 电脑编辑

- ✅ 使用 Obsidian 编辑和链接
- ✅ 使用 VS Code 批量修改
- ✅ Git 提交和推送

### 团队协作

- ✅ 邀请团队成员查看
- ✅ 通过 PR 贡献内容
- ✅ 使用 Issues 讨论话题

---

## 📝 更新日志

### 2026-02-28

- ✅ 创建 GitHub 仓库
- ✅ 同步现有文档
- ✅ 添加 README
- ✅ 设置目录结构

### 2026-02-27

- ✅ 创建技术博客学习工作流
- ✅ 完成 Prompt Caching 深度解读
- ✅ 完成 Provider 功能对比
- ✅ 完成 LiteLLM 缓存实施指南
- ✅ 设置 Anthropic 周报定时任务

---

## 🔗 相关链接

| 资源 | 链接 |
|------|------|
| Obsidian Vault | 本地路径 |
| GitHub 仓库 | https://github.com/eddy/ai-knowledge-base |
| Anthropic Engineering | https://www.anthropic.com/engineering |
| LiteLLM 文档 | https://docs.litellm.ai |

---

**Created with ❤️ by Eddy**
