# GitHub 仓库设置指南

## 📋 创建步骤

### 1. 在 GitHub 创建仓库

1. 访问 https://github.com/new
2. 仓库名称：`ai-knowledge-base`
3. 描述：`AI 技术知识库 - Eddy 的技术学习与实践经验总结`
4. 可见性：**Public**（公开）或 **Private**（私有）
5. ❌ 不要勾选 "Add a README file"
6. 点击 **Create repository**

### 2. 关联本地仓库

```bash
cd /Users/eddy/.openclaw/workspace/ai-knowledge-base

# 添加远程仓库（替换 YOUR_USERNAME 为你的 GitHub 用户名）
git remote add origin https://github.com/YOUR_USERNAME/ai-knowledge-base.git

# 或者使用 SSH（推荐）
git remote add origin git@github.com:YOUR_USERNAME/ai-knowledge-base.git

# 推送到 GitHub
git branch -M main
git push -u origin main
```

### 3. 验证推送

```bash
# 查看远程仓库
git remote -v

# 查看提交历史
git log --oneline
```

---

## 📱 手机查看

### 方式 1：GitHub App（推荐）

1. **下载 App**
   - iOS: [GitHub App](https://apps.apple.com/app/github/id1477376905)
   - Android: [GitHub App](https://play.google.com/store/apps/details?id=com.github.android)

2. **登录账号**
   - 使用 GitHub 账号登录

3. **打开仓库**
   - 搜索 `YOUR_USERNAME/ai-knowledge-base`
   - 或从仓库列表中找到

4. **浏览文档**
   - 点击文件即可查看（自动渲染 Markdown）
   - 支持目录导航
   - 支持搜索

### 方式 2：手机浏览器

1. 访问 https://github.com/YOUR_USERNAME/ai-knowledge-base
2. 浏览文件（Markdown 自动渲染）
3. 可添加到主屏幕（Safari: 分享 → 添加到主屏幕）

### 方式 3：Obsidian Mobile

1. 下载 [Obsidian Mobile](https://obsidian.md/mobile)
2. 克隆仓库到手机：
   ```bash
   git clone https://github.com/YOUR_USERNAME/ai-knowledge-base.git
   ```
3. 在 Obsidian 中打开文件夹
4. 作为 Obsidian Vault 使用

---

## 🔄 同步机制

### 自动同步（推荐）

使用 GitHub Actions 实现自动同步：

1. **Obsidian 修改后自动推送**
   - 安装 Obsidian 插件：**Obsidian Git**
   - 配置自动备份间隔（如每 30 分钟）
   - 设置推送远程仓库

2. **配置步骤**：
   ```
   Obsidian → 设置 → 社区插件 → 浏览 → 搜索 "Git" → 安装 "Obsidian Git"
   → 设置 → Obsidian Git → 配置：
     - Auto backup interval: 30 (分钟)
     - Pull updates on startup: true
     - Sync method: GitHub
   ```

### 手动同步

使用提供的同步脚本：

```bash
# 查看状态
./sync.sh status

# 推送到 GitHub
./sync.sh push

# 从 GitHub 拉取
./sync.sh pull
```

---

## 📊 GitHub Pages（可选）

部署为静态网站，支持搜索和更好的阅读体验：

### 1. 启用 GitHub Pages

1. 访问仓库 **Settings** → **Pages**
2. Source: **Deploy from a branch**
3. Branch: **main** / **/(root)**
4. 点击 **Save**

### 2. 访问网站

```
https://YOUR_USERNAME.github.io/ai-knowledge-base/
```

### 3. 自定义主题（可选）

添加 `_config.yml`：

```yaml
title: AI 技术知识库
description: Eddy 的技术学习与实践经验总结
theme: jekyll-theme-cayman
show_downloads: false
```

---

## 🔐 安全建议

### 公开仓库

- ✅ 技术笔记、学习心得
- ✅ 代码示例、实施指南
- ❌ 不要包含 API Keys、密码
- ❌ 不要包含公司内部信息

### 私有仓库

- ✅ 包含敏感信息
- ✅ 公司内部文档
- ✅ 个人私密笔记

### 检查敏感信息

```bash
# 推送前检查
git diff --cached | grep -i "api_key\|password\|secret"

# 如果已推送，立即删除
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch -r .env" \
  --prune-empty --tag-name-filter cat -- --all
```

---

## 📝 日常使用流程

### 添加新文档

```bash
# 1. 在 Obsidian 中创建/编辑文档

# 2. 同步到 GitHub
./sync.sh push

# 3. 输入提交信息
# 例如："新增：RAG 评估体系建设指南"
```

### 更新现有文档

```bash
# 1. 在 Obsidian 中修改文档

# 2. 查看变更
./sync.sh status

# 3. 推送
./sync.sh push
```

### 在手机查看

1. 打开 GitHub App
2. 进入仓库
3. 浏览文档
4. 可离线查看（已缓存的文档）

---

## 🎯 最佳实践

### 文档组织

- ✅ 使用清晰的目录结构
- ✅ 文件名包含日期（如 `2026-02-28-标题.md`）
- ✅ 添加 Frontmatter 元数据
- ✅ 使用双向链接（Obsidian）

### 提交信息

- ✅ 使用有意义的提交信息
- ✅ 格式：`类型：描述`
- ✅ 例如：
  - `新增：LiteLLM 缓存实施指南`
  - `更新：Provider 功能对比表`
  - `修复：错别字和格式问题`

### 版本控制

- ✅ 定期提交（每天/每周）
- ✅ 重要修改使用标签
- ✅ 保留历史记录

---

## 🔗 相关资源

| 资源 | 链接 |
|------|------|
| GitHub App | https://github.com/mobile |
| Obsidian Git 插件 | https://github.com/denolehov/obsidian-git |
| GitHub Pages | https://pages.github.com |
| Markdown 语法 | https://docs.github.com/en/get-started/writing-on-github |

---

## ✅ 检查清单

### 初次设置

- [ ] 创建 GitHub 账号
- [ ] 创建仓库 `ai-knowledge-base`
- [ ] 配置 Git 凭证
- [ ] 推送初始提交
- [ ] 安装 GitHub App
- [ ] 测试手机查看

### 日常使用

- [ ] Obsidian Git 插件已安装
- [ ] 自动备份已启用
- [ ] 定期推送到 GitHub
- [ ] 定期检查同步状态

---

**最后更新**：2026-02-28  
**维护者**：Eddy
