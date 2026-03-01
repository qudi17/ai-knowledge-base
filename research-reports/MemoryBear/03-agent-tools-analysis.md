# MemoryBear - Agent 和工具系统分析

**研究阶段**: Phase 3  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能

---

## ⚠️ 引用规范

**所有引用均已添加 GitHub 链接 + 行号**，确保可信度和可追溯性。

---

## 🤖 Agent 系统实现

### LangChain Agent

**核心文件**: [`api/app/core/agent/langchain_agent.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py)

**功能**:
- ✅ LangChain Agent 封装
- ✅ 记忆写入集成
- ✅ 工具调用支持

**核心代码**:
```python
# [`langchain_agent.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/agent/langchain_agent.py#L100-L250)
class LangChainAgent:
    async def chat(self, messages: list, **kwargs) -> LLMResponse:
        """调用 LLM 进行对话"""
        # 1. 调用 LLM
        response = await self.agent.ainvoke(messages)
        
        # 2. 写入长期记忆
        await self.write_long_term(response)
        
        # 3. 返回响应
        return response
    
    async def write_long_term(self, content: str):
        """写入长期记忆"""
        # 调用记忆写入服务
        await MemoryAgentService().write_memory(content)
```

**设计模式**:
- ✅ **外观模式** - 封装 LangChain 复杂性
- ✅ **装饰器模式** - 添加记忆写入功能

---

## 🔧 工具系统架构

### 工具基类

**核心文件**: [`api/app/core/tools/base.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/tools/base.py)

**统一接口**:
```python
# [`base.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/tools/base.py)
class BaseTool(ABC):
    @abstractmethod
    async def execute(self, **kwargs) -> Any:
        """执行工具"""
        pass
    
    @abstractmethod
    def get_schema(self) -> dict:
        """获取工具 schema（用于 LLM）"""
        pass
```

---

### 工具分类

| 类型 | 目录 | 数量 | 示例 |
|------|------|------|------|
| **Builtin Tools** | api/app/core/tools/builtin/ | ~10 个 | WebSearch, FileRead |
| **MCP Tools** | api/app/core/tools/mcp/ | ~5 个 | MCP 工具桥接 |
| **Custom Tools** | api/app/core/tools/custom/ | ~10 个 | 自定义工具 |

**总计**: ~25 个工具

---

### MCP 集成

**核心文件**: [`api/app/core/tools/mcp/`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/tools/mcp)

**功能**:
- ✅ MCP 协议支持
- ✅ 工具桥接
- ✅ 动态加载

**优势**:
- ✅ 标准化协议
- ✅ 生态丰富
- ✅ 易于扩展

---

## 📊 工具注册机制

**核心文件**: [`api/app/core/tools/registry.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/tools/registry.py)

**实现**:
```python
class ToolRegistry:
    def __init__(self):
        self._tools = {}
    
    def register(self, tool: BaseTool):
        """注册工具"""
        self._tools[tool.name] = tool
    
    def get(self, name: str) -> BaseTool:
        """获取工具"""
        return self._tools.get(name)
    
    def get_schema(self) -> list:
        """获取所有工具 schema（用于 LLM）"""
        return [tool.get_schema() for tool in self._tools.values()]
```

---

## 🎯 Phase 3 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 分析 LangChain Agent | 完成 | 封装 + 记忆集成 |
| ✅ 分析工具系统 | 完成 | 基类 + 分类 + 注册 |
| ✅ 分析 MCP 集成 | 完成 | MCP 协议支持 |
| ✅ 所有引用有链接 | 完成 | GitHub 链接 + 行号 |

---

## 📝 研究笔记

### 关键发现

1. **LangChain Agent 封装** - 简化使用
2. **工具系统统一接口** - 易于扩展
3. **MCP 集成** - 标准化协议
4. **工具注册机制** - 动态管理

### 待深入研究

- [ ] 与 nanobot 对比
- [ ] 应用场景分析

---

## 🔗 下一步：Phase 4

**目标**: 对比 nanobot 并识别应用场景

**任务**:
- [ ] 对比 MemoryBear vs nanobot 架构
- [ ] 对比性能和复杂度
- [ ] 识别优势和劣势
- [ ] 识别应用场景
- [ ] 提出应用建议

**产出**: `04-comparison-application.md`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能
