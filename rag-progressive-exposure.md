# RAG 渐进式暴露实现方案

## 核心思想

参照 Agent Skills 的分层加载和门控机制，实现 RAG 知识源的渐进式暴露。

---

## 方案一：基于 Skill 模式扩展

### 架构设计

```
知识源分层
├── Layer 1: 核心知识 (高频访问，始终加载)
│   ├── SKILL.md: 核心文档（常问问题、关键概念）
│   └── metadata: { always: true }
├── Layer 2: 项目知识 (项目相关，按需加载)
│   ├── SKILL.md: 项目文档、代码规范
│   └── metadata: { requires.config: ["project.active"] }
└── Layer 3: 扩展知识 (低频访问，延迟加载)
    ├── SKILL.md: 历史记录、临时笔记
    └── metadata: { requires.env: ["RAG_EXTENDED"] }
```

### 实现步骤

#### 1. 知识源 Skill 定义

**核心知识 (always: true)**

```markdown
---
name: rag-core
description: 核心知识库 - 常见问题和关键概念
metadata:
  {
    "openclaw": {
      "always": true,
      "user-invocable": false,
      "disable-model-invocation": false
    }
  }
---

# 核心知识库

{baseDir}/docs/core/

包含：
- 系统配置说明
- 常用命令速查
- API 接口文档
- 故障排查指南

**使用方式**：
查询时自动搜索核心知识库
```

**项目知识 (条件加载)**

```markdown
---
name: rag-project
description: 项目知识库 - 当前项目相关文档
metadata:
  {
    "openclaw": {
      "requires": {
        "config": ["project.active"]
      },
      "user-invocable": false
    }
  }
---

# 项目知识库

{baseDir}/docs/project/

包含：
- 项目架构文档
- 代码规范
- 开发流程
- 团队约定

**激活方式**：
在 openclaw.json 中设置 project.active = true
```

#### 2. 配置层控制

**openclaw.json**

```json5
{
  skills: {
    entries: {
      "rag-core": { enabled: true },
      "rag-project": {
        enabled: false,  // 默认禁用，按需启用
        config: {
          indexPath: "./.rag/project-index",
          chunks: 500,
          embeddingModel: "text-embedding-3-small"
        }
      },
      "rag-extended": {
        enabled: false,
        env: {
          RAG_EXTENDED: "1"  // 通过环境变量激活
        },
        config: {
          indexPath: "./.rag/extended-index",
          chunks: 1000
        }
      }
    }
  },
  project: {
    active: true  // 激活项目知识层
  }
}
```

#### 3. 动态切换层

**切换到项目模式**：
```json
{
  "project": { "active": true },
  "skills": {
    "entries": {
      "rag-project": { "enabled": true }
    }
  }
}
```

**切换到扩展模式**：
```json
{
  "skills": {
    "entries": {
      "rag-extended": { "enabled": true }
    }
  }
}
```

#### 4. RAG 查询逻辑

```python
# 伪代码
def query_rag(question, context):
    eligible_skills = get_eligible_skills()

    # 按层查询（从高优先级开始）
    results = []
    for skill in sorted(eligible_skills, key=skill_priority):
        skill_index = skill.config.indexPath
        skill_results = search_index(skill_index, question, top_k=5)
        results.extend(skill_results)

        # 早期终止：如果核心层已找到高置信度结果
        if skill.metadata.always and has_high_confidence(results):
            break

    return rerank(results, context)
```

---

## 方案二：独立 RAG 管理器

### 架构设计

```
RAG Manager
├── KnowledgeLayer (抽象基类)
│   ├── name: 层名称
│   ├── priority: 优先级
│   ├── metadata: 门控条件
│   ├── index: 向量索引
│   └── query(): 查询方法
├── layers[]: 知识层列表
├── load(): 加载符合条件的层
├── query(): 跨层查询
└── switch_layer(): 动态切换层
```

### 实现代码结构

**knowledge_layer.py**

```python
from typing import List, Optional, Dict, Any
from abc import ABC, abstractmethod
import os
import json

class KnowledgeLayer(ABC):
    """知识层抽象基类"""

    def __init__(self, name: str, priority: int, metadata: Dict[str, Any]):
        self.name = name
        self.priority = priority  # 越小越优先
        self.metadata = metadata
        self.index = None
        self.enabled = False

    @abstractmethod
    def check_eligible(self, config: Dict, env: Dict) -> bool:
        """检查层是否符合加载条件"""
        pass

    @abstractmethod
    def load_index(self, index_path: str):
        """加载索引"""
        pass

    @abstractmethod
    def query(self, question: str, top_k: int = 5) -> List[Dict]:
        """查询当前层"""
        pass


class CoreKnowledgeLayer(KnowledgeLayer):
    """核心知识层 - 始终加载"""

    def __init__(self, index_path: str):
        super().__init__(
            name="core",
            priority=1,
            metadata={"always": True}
        )
        self.index_path = index_path

    def check_eligible(self, config: Dict, env: Dict) -> bool:
        return True

    def load_index(self, index_path: str = None):
        # 实现索引加载逻辑
        self.index = load_vector_index(index_path or self.index_path)

    def query(self, question: str, top_k: int = 5) -> List[Dict]:
        return search_vector_index(self.index, question, top_k)


class ProjectKnowledgeLayer(KnowledgeLayer):
    """项目知识层 - 条件加载"""

    def __init__(self, index_path: str, project_name: str):
        super().__init__(
            name="project",
            priority=2,
            metadata={"requires_config": ["project.active"]}
        )
        self.index_path = index_path
        self.project_name = project_name

    def check_eligible(self, config: Dict, env: Dict) -> bool:
        # 检查项目是否激活
        return config.get("project", {}).get("active") == True

    def load_index(self, index_path: str = None):
        self.index = load_vector_index(index_path or self.index_path)

    def query(self, question: str, top_k: int = 5) -> List[Dict]:
        return search_vector_index(self.index, question, top_k)


class ExtendedKnowledgeLayer(KnowledgeLayer):
    """扩展知识层 - 环境变量控制"""

    def __init__(self, index_path: str):
        super().__init__(
            name="extended",
            priority=3,
            metadata={"requires_env": ["RAG_EXTENDED"]}
        )
        self.index_path = index_path

    def check_eligible(self, config: Dict, env: Dict) -> bool:
        return env.get("RAG_EXTENDED") == "1"

    def load_index(self, index_path: str = None):
        self.index = load_vector_index(index_path or self.index_path)

    def query(self, question: str, top_k: int = 5) -> List[Dict]:
        return search_vector_index(self.index, question, top_k)
```

**rag_manager.py**

```python
from typing import List, Dict, Optional
import json
from pathlib import Path

class RAGManager:
    """RAG 渐进式暴露管理器"""

    def __init__(self, config_path: str = "~/.openclaw/openclaw.json"):
        self.config_path = Path(config_path).expanduser()
        self.layers: List[KnowledgeLayer] = []
        self.active_layers: List[KnowledgeLayer] = []
        self.config = self._load_config()
        self.env = dict(os.environ)

    def register_layer(self, layer: KnowledgeLayer):
        """注册知识层"""
        self.layers.append(layer)

    def load(self):
        """加载符合条件的知识层"""
        self.config = self._load_config()

        for layer in sorted(self.layers, key=lambda l: l.priority):
            if layer.check_eligible(self.config, self.env):
                layer.load_index()
                layer.enabled = True
                self.active_layers.append(layer)

        print(f"✓ 加载 {len(self.active_layers)} 个知识层: {[l.name for l in self.active_layers]}")

    def query(
        self,
        question: str,
        top_k: int = 5,
        early_stop: bool = True,
        min_score: float = 0.8
    ) -> List[Dict]:
        """跨层查询（渐进式）"""
        all_results = []

        for layer in self.active_layers:
            layer_results = layer.query(question, top_k)
            all_results.extend(layer_results)

            # 早期终止：核心层找到高置信度结果
            if early_stop and layer.metadata.get("always"):
                if max(r["score"] for r in layer_results) >= min_score:
                    print(f"✓ 核心层找到高置信度结果，停止搜索")
                    break

        # 重新排序
        return self._rerank(all_results, question)

    def switch_layer(self, layer_name: str, enabled: bool):
        """动态切换知识层"""
        # 更新配置
        if layer_name == "project":
            self.config.setdefault("project", {})["active"] = enabled
        elif layer_name == "extended":
            if enabled:
                self.env["RAG_EXTENDED"] = "1"
            else:
                self.env.pop("RAG_EXTENDED", None)

        # 重载
        self.load()
        self._save_config()

    def _load_config(self) -> Dict:
        """加载配置"""
        with open(self.config_path) as f:
            return json.load(f)

    def _save_config(self):
        """保存配置"""
        with open(self.config_path, "w") as f:
            json.dump(self.config, f, indent=2)

    def _rerank(self, results: List[Dict], question: str) -> List[Dict]:
        """重排序结果"""
        # 实现重排序逻辑（如：基于语义相似度、时间衰减等）
        return sorted(results, key=lambda r: r["score"], reverse=True)


# 使用示例
def main():
    manager = RAGManager()

    # 注册知识层
    manager.register_layer(CoreKnowledgeLayer("./.rag/core-index"))
    manager.register_layer(ProjectKnowledgeLayer("./.rag/project-index", "my-project"))
    manager.register_layer(ExtendedKnowledgeLayer("./.rag/extended-index"))

    # 加载符合条件的层
    manager.load()

    # 查询
    results = manager.query("如何配置 OpenClaw?")
    for r in results[:3]:
        print(f"[{r['score']:.2f}] {r['text'][:100]}...")

    # 动态切换层
    manager.switch_layer("project", True)
    results = manager.query("项目架构是什么?")
```

---

## 方案三：Hybrid (Skill + Manager)

结合两种方案的优势：

1. **Skill 负责暴露**：使用 Skills 的门控机制，让 AI 能感知知识源
2. **Manager 负责执行**：RAG Manager 实际执行查询，支持渐进式加载

**Skill 定义 (仅暴露，不执行)**

```markdown
---
name: rag
description: 渐进式 RAG 查询 - 支持分层知识库
metadata:
  {
    "openclaw": {
      "always": true,
      "user-invocable": true
    }
  }
---

# 渐进式 RAG 查询

使用方式：
1. 正常提问：自动搜索所有活跃层
2. 切换层：告诉 AI "启用项目知识层" 或 "启用扩展知识层"
3. 查看当前层：问 "当前启用了哪些知识层?"

知识层：
- 核心层 (always): 常见问题、系统配置
- 项目层 (条件): 项目文档、代码规范（需要 project.active=true）
- 扩展层 (环境): 历史记录、临时笔记（需要 RAG_EXTENDED=1）

实现：由 RAG Manager 后端执行
```

**Manager 作为后端服务**

```python
# 独立运行的服务
class RAGBackend:
    def query(self, question: str, active_layers: List[str]) -> Dict:
        """执行 RAG 查询"""
        # 返回结果给 AI
        pass

    def get_active_layers(self) -> List[str]:
        """获取当前活跃层"""
        pass
```

---

## 关键设计决策

### 1. 分层策略

| 层 | 优先级 | 触发条件 | 典型内容 |
|---|---|---|---|
| Core | 1 | always | 常见问题、系统文档 |
| Project | 2 | config.project.active | 项目文档、代码规范 |
| Extended | 3 | env.RAG_EXTENDED | 历史记录、临时笔记 |

### 2. 早期终止

- **目的**：减少延迟和 Token 消耗
- **条件**：核心层找到高置信度结果（score > 0.8）
- **可配置**：通过参数控制是否启用

### 3. 缓存策略

```python
class RAGCache:
    """RAG 结果缓存"""
    def __init__(self, ttl: int = 3600):
        self.cache = {}
        self.ttl = ttl

    def get(self, question: str) -> Optional[List[Dict]]:
        entry = self.cache.get(question)
        if entry and time.time() - entry["timestamp"] < self.ttl:
            return entry["results"]

    def set(self, question: str, results: List[Dict]):
        self.cache[question] = {
            "results": results,
            "timestamp": time.time()
        }
```

### 4. 增量索引

```python
def watch_docs(folder: str, manager: RAGManager):
    """监听文档变化，增量更新索引"""
    observer = watchdog.Observer()
    observer.schedule(DocHandler(manager), folder, recursive=True)
    observer.start()
```

---

## 推荐方案

**快速原型**：方案一（基于 Skill）
- 最小改动
- 复用现有基础设施
- 适合小规模知识库

**生产环境**：方案三（Hybrid）
- 灵活性高
- Skill 暴露 + Manager 执行
- 支持复杂查询逻辑

**独立服务**：方案二（Manager）
- 完全独立
- 可作为微服务部署
- 适合大规模知识库

---

## 下一步

1. 选择方案并实现 MVP
2. 创建测试知识层
3. 集成到 OpenClaw
4. 性能测试和优化
