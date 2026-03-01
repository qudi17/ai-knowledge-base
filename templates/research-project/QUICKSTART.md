# 研究项目快速启动指南

**版本**: v1.0  
**日期**: 2026-03-01

---

## 🚀 5 分钟启动研究项目

### 步骤 1: 复制模板（1 分钟）

```bash
# 创建项目目录
mkdir -p /Users/eddy/.openclaw/workspace/ai-knowledge-base/.planning/{{项目名称}}

# 复制模板
cp templates/research-project/PROJECT.md .planning/{{项目名称}}/
cp templates/research-project/REQUIREMENTS.md .planning/{{项目名称}}/
cp templates/research-project/ROADMAP.md .planning/{{项目名称}}/
cp templates/research-project/STATE.md .planning/{{项目名称}}/
```

---

### 步骤 2: 填写 PROJECT.md（2 分钟）

**编辑** `.planning/{{项目名称}}/PROJECT.md`:

```markdown
# {{项目名称}} - 研究项目

**研究日期**: 2026-03-01  
**研究者**: {{你的名字}}  
**方法**: GSD + Superpowers + 毛线团研究法

---

## 🎯 项目目标

**核心目标**: 深度分析{{项目}}，理解{{核心问题}}

**具体问题**:
1. {{问题 1}}
2. {{问题 2}}
3. {{问题 3}}
```

---

### 步骤 3: 填写 REQUIREMENTS.md（1 分钟）

**编辑** `.planning/{{项目名称}}/REQUIREMENTS.md`:

```markdown
## 📋 研究范围

### v1 范围（本次研究）

**必须包含**:
- [ ] 项目概览和定位
- [ ] 核心架构分析
- [ ] 入口点识别
- [ ] 关键模块分析

**必须产出**:
- [ ] 架构图
- [ ] 调用链流程图
- [ ] 代码位置索引
- [ ] 研究总结文档
```

---

### 步骤 4: 填写 ROADMAP.md（1 分钟）

**编辑** `.planning/{{项目名称}}/ROADMAP.md`:

```markdown
## 🗺️ 研究路线图

### Phase 1: 项目概览和架构分析

**目标**: 理解项目定位和核心架构

**任务**:
- [ ] 获取项目 README 和文档
- [ ] 分析项目结构
- [ ] 识别入口点
- [ ] 绘制架构图

**产出**: `01-{{项目}}-overview.md`

**预计时间**: 30 分钟

**状态**: ⬜ 未开始
```

---

### 步骤 5: 开始研究（立即）

**复制研究报告模板**:
```bash
cp templates/research-project/research-report-template.md \
   research-reports/{{项目}}/01-{{项目}}-overview.md
```

**开始 Phase 1 研究**!

---

## 📊 研究流程

```
1. PROJECT.md (目标)
   ↓
2. REQUIREMENTS.md (范围)
   ↓
3. ROADMAP.md (计划)
   ↓
4. 执行研究 (按阶段)
   ↓
5. STATE.md (状态追踪)
   ↓
6. 研究报告 (产出)
```

---

## 🎯 最佳实践

### 1. 明确验收标准

**Level 1-5 理解层次**:
- Level 1: 能解释项目定位
- Level 2: 能解释核心架构
- Level 3: 能追踪调用链
- Level 4: 能分析设计模式
- Level 5: 能应用到实际场景

**目标**: 达到 Level 4 或 Level 5

---

### 2. 任务分解

**原则**: 每个任务 30-60 分钟可完成

**示例**:
```
❌ 太大："分析项目"
✅ 合适："识别入口点（CLI + API）"
```

---

### 3. 状态更新

**每次研究会话后更新 STATE.md**:
```markdown
## 📝 研究日志

### 2026-03-01 11:00

- Phase 1 完成
- 识别 2 个入口点
- 绘制架构图

**下一步**: 开始 Phase 2
```

---

### 4. Git 提交

**每个阶段完成后提交**:
```bash
git add .
git commit -m "{{项目名称}} Phase N: {{阶段名称}}

- 完成{{任务 1}}
- 完成{{任务 2}}
- 产出{{文档}}"
git push
```

---

## 📋 模板变量说明

| 变量 | 说明 | 示例 |
|------|------|------|
| `{{项目名称}}` | 研究项目名称 | MarkItDown |
| `{{日期}}` | 研究日期 | 2026-03-01 |
| `{{研究者}}` | 研究者姓名 | Jarvis |
| `{{方法}}` | 研究方法 | GSD + Superpowers + 毛线团 |
| `{{Phase N}}` | 阶段编号 | Phase 1 |
| `{{产出文档}}` | 产出文档名 | 01-markitdown-overview.md |

---

## 🔗 示例项目

**参考**: MarkItDown 研究项目

**位置**:
- `.planning/markitdown-research/` - 规划文档
- `research-reports/markitdown/` - 研究报告

**学习路径**:
1. 查看 `PROJECT.md` 了解目标
2. 查看 `REQUIREMENTS.md` 了解范围
3. 查看 `ROADMAP.md` 了解计划
4. 查看 `01-markitdown-overview.md` 了解产出

---

## 🎯 成功指标

**研究项目成功**:
- ✅ 按计划完成所有阶段
- ✅ 达到预定理解层次（Level 4-5）
- ✅ 产出结构化研究报告
- ✅ 可应用到实际场景

**流程成功**:
- ✅ 使用模板创建项目
- ✅ 每个阶段更新 STATE.md
- ✅ Git 提交记录进度
- ✅ 复用模板到新项目

---

## 📝 检查清单

### 项目启动

- [ ] 创建项目目录
- [ ] 复制 4 个规划模板
- [ ] 填写 PROJECT.md
- [ ] 填写 REQUIREMENTS.md
- [ ] 填写 ROADMAP.md
- [ ] 复制研究报告模板
- [ ] Git 提交初始版本

### 每个阶段

- [ ] 更新 STATE.md（阶段开始）
- [ ] 执行研究任务
- [ ] 撰写研究报告
- [ ] 更新 STATE.md（阶段完成）
- [ ] Git 提交阶段成果

### 项目完成

- [ ] 所有阶段完成
- [ ] 所有验收标准通过
- [ ] 研究报告完整
- [ ] STATE.md 标记完成
- [ ] Git 提交最终版本
- [ ] 总结经验和教训

---

**快速启动指南版本**: v1.0  
**最后更新**: 2026-03-01  
**维护者**: Jarvis
