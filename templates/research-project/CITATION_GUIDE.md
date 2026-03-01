# 研究引用规范

**版本**: v1.0  
**创建日期**: 2026-03-01  
**重要性**: ⭐⭐⭐⭐⭐（核心要求）

---

## 🎯 核心原则

**所有引用必须注明来源，确保可信度和可追溯性**

---

## 📋 引用格式

### 1. 代码引用

**格式**: [`文件名`](GitHub 链接#L 起始-L 结束)

**示例**:
```markdown
[`agent/loop.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L200-L250)
```

**要求**:
- ✅ 必须包含完整 GitHub URL
- ✅ 必须标注具体行号范围
- ✅ 文件名使用反引号
- ✅ 链接使用 Markdown 格式

---

### 2. 文档引用

**格式**: [文档名](URL)

**示例**:
```markdown
[README.md](https://github.com/HKUDS/nanobot/blob/main/README.md)
```

**要求**:
- ✅ 必须包含完整 URL
- ✅ 文档名清晰描述内容

---

### 3. 外部引用

**格式**: [标题](URL) - 来源

**示例**:
```markdown
[OpenClaw](https://github.com/openclaw/openclaw) - nanobot 灵感来源
```

**要求**:
- ✅ 必须标注来源
- ✅ 说明引用目的

---

## ✅ 验证清单

### 每个文档必须满足

- [ ] 所有代码引用有 GitHub 链接
- [ ] 所有代码引用有行号
- [ ] 所有外部引用有来源标注
- [ ] 所有数据有来源
- [ ] 无推断内容
- [ ] 所有结论可追溯

---

## ❌ 禁止行为

### 不可接受的引用

**❌ 无链接**:
```markdown
# 错误示例
在 agent/loop.py 中定义了 AgentLoop 类
```

**✅ 正确做法**:
```markdown
# 正确示例
在 [`agent/loop.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L50-L100) 中定义了 AgentLoop 类
```

---

**❌ 无行号**:
```markdown
# 错误示例
[`agent/loop.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py)
```

**✅ 正确做法**:
```markdown
# 正确示例
[`agent/loop.py`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L200-L350)
```

---

**❌ 推断内容**:
```markdown
# 错误示例
这个设计可能是为了...
```

**✅ 正确做法**:
```markdown
# 正确示例
根据代码注释（[`agent/loop.py`](...#L55)），这个设计是为了...
```

---

## 🔍 验证流程

### 研究完成后自检

1. **搜索无链接引用**:
   ```bash
   grep -n "\.py" 研究报告.md | grep -v "http"
   ```

2. **搜索无行号链接**:
   ```bash
   grep -n "\.py\](https" 研究报告.md | grep -v "#L"
   ```

3. **搜索推断词汇**:
   ```bash
   grep -n "可能\|也许\|大概\|应该" 研究报告.md
   ```

---

## 📊 质量评分

| 标准 | 权重 | 评分 |
|------|------|------|
| **代码引用完整** | 40% | ⬜⬜⬜⬜⬜ |
| **行号标注准确** | 30% | ⬜⬜⬜⬜⬜ |
| **外部引用来源** | 20% | ⬜⬜⬜⬜⬜ |
| **无推断内容** | 10% | ⬜⬜⬜⬜⬜ |

**总分**: ⬜⬜⬜⬜⬜ (0/100)

**合格标准**: ≥80 分

---

## 🎯 最佳实践

### 1. 边研究边标注

**推荐工作流**:
```
1. 读取代码
2. 复制 GitHub 链接
3. 标注行号
4. 撰写分析
5. 验证链接
```

**避免**:
```
❌ 研究完成后补链接
❌ 凭记忆写链接
❌ 使用模糊引用
```

---

### 2. 使用工具辅助

**GitHub 链接获取**:
1. 打开 GitHub 文件
2. 点击行号（选择行范围）
3. 点击"..." → "Copy permalink"
4. 粘贴到研究报告

**VS Code 插件**:
- GitHub Linker - 自动生成链接
- Code Linker - 代码引用管理

---

### 3. 创建引用索引

**示例**: [`CODE_INDEX.md`](../research-reports/nanobot/CODE_INDEX.md)

**内容**:
- 所有引用文件列表
- 对应 GitHub 链接
- 说明和用途

---

## 📝 示例对比

### 差的研究

```markdown
## AgentLoop 分析

AgentLoop 是核心类，在 agent/loop.py 中定义。

它有以下方法：
- _process_message() - 处理消息
- _build_context() - 构建上下文
```

**问题**:
- ❌ 无 GitHub 链接
- ❌ 无行号
- ❌ 无法验证

---

### 好的研究

```markdown
## AgentLoop 分析

[`AgentLoop`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L50-L100) 是核心处理引擎（~400 行）。

**核心方法**:
- [`_process_message()`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/loop.py#L200-L350) - 处理单条消息（150 行）
- [`_build_context()`](https://github.com/HKUDS/nanobot/blob/main/nanobot/agent/context.py#L50-L150) - 构建上下文（100 行）
```

**优点**:
- ✅ 所有引用有链接
- ✅ 所有引用有行号
- ✅ 可验证可追溯

---

## 🔗 相关文档

- [研究模板](./research-report-template.md)
- [快速指南](./QUICKSTART.md)
- [nanobot CODE_INDEX](../research-reports/nanobot/CODE_INDEX.md)

---

**版本**: v1.0  
**最后更新**: 2026-03-01  
**维护者**: Jarvis
