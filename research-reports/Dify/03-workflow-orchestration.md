# Dify - 工作流编排机制分析

**研究阶段**: Phase 3  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 v2.0

---

## 📊 工作流引擎架构

### 核心模块

```
api/core/workflow/
├── workflow_engine.py        # 工作流引擎 ⭐
├── nodes/                    # 节点类型（17+ 种）
│   ├── llm/                  # LLM 节点
│   ├── knowledge_retrieval/  # 知识检索节点
│   ├── tool/                 # 工具节点
│   ├── code/                 # 代码节点
│   ├── http_request/         # HTTP 请求节点
│   ├── if_else/              # 条件节点
│   ├── variable_assigner/    # 变量赋值节点
│   └── ...                   # 17+ 种
├── graph/                    # 图结构
│   ├── graph_engine.py       # 图引擎
│   └── entities.py           # 图实体
└── callbacks/                # 回调
```

---

## 🔍 工作流执行流程

### 执行引擎

**文件**: [`api/core/workflow/workflow_engine.py`](https://github.com/langgenius/dify/blob/main/api/core/workflow/workflow_engine.py)

```python
class WorkflowEngine:
    def execute(self, workflow: Workflow, inputs: dict):
        # 1. 图拓扑排序
        sorted_nodes = workflow.graph.topological_sort()
        
        # 2. 按顺序执行节点
        for node in sorted_nodes:
            # 执行节点
            result = node.execute(inputs)
            
            # 更新输入
            inputs = result.outputs
            
            # 触发回调
            self.callbacks.on_node_end(node, result)
        
        return inputs
```

---

### 节点类型（17+ 种）

| 节点类型 | 说明 | 使用场景 |
|----------|------|---------|
| **LLM 节点** | 调用大语言模型 | 文本生成/对话 |
| **知识检索节点** | RAG 检索 | 知识库问答 |
| **工具节点** | 调用外部工具 | API 调用/搜索 |
| **代码节点** | 执行 Python 代码 | 数据处理 |
| **HTTP 请求节点** | HTTP 请求 | Web API 集成 |
| **条件节点** | if/else 分支 | 流程控制 |
| **变量赋值节点** | 变量操作 | 状态管理 |
| **模板转换节点** | 模板渲染 | 格式化输出 |
| **列表操作节点** | 列表处理 | 数据聚合 |
| **答案节点** | 输出答案 | 最终响应 |

---

## 🎯 设计模式

### 1. 命令模式（Command Pattern）

**实现**: 节点执行
```python
class NodeExecutionCommand:
    def __init__(self, node: Node):
        self.node = node
    
    def execute(self, inputs: dict):
        return self.node.execute(inputs)
```

---

### 2. 责任链模式（Chain of Responsibility）

**实现**: 节点链式执行
```
Input → Node1 → Node2 → Node3 → ... → Output
```

---

### 3. 观察者模式（Observer Pattern）

**实现**: 工作流回调
```python
class WorkflowCallback:
    def on_node_start(self, node: Node): ...
    def on_node_end(self, node: Node, result: Result): ...
    def on_workflow_complete(self, result: Result): ...
```

---

## 📊 工作流图结构

### 图表示

```python
class WorkflowGraph:
    def __init__(self):
        self.nodes: dict[str, Node] = {}
        self.edges: list[Edge] = []
    
    def topological_sort(self) -> list[Node]:
        # 拓扑排序，确定执行顺序
        ...
    
    def get_next_nodes(self, node_id: str) -> list[Node]:
        # 获取下一个节点
        ...
```

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 v2.0
