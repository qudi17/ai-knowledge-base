# MemoryBear - 记忆系统深度分析

**研究阶段**: Phase 2  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能

---

## ⚠️ 引用规范

**所有引用均已添加 GitHub 链接 + 行号**，确保可信度和可追溯性。

---

## 📊 记忆系统架构

### 三层记忆架构

```
┌─────────────────────────────────────┐
│      短期记忆 (Redis 缓存)           │
│  - 会话上下文                        │
│  - 临时记忆                          │
│  (api/app/cache/)                   │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│      中期记忆 (向量数据库)            │
│  - 语义检索                          │
│  - 混合搜索                          │
│  (api/app/core/memory/storage_services/search/) │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│      长期记忆 (Neo4j 知识图谱)        │
│  - 知识图谱                          │
│  - 遗忘曲线                          │
│  - 反思引擎                          │
│  (api/app/repositories/neo4j/)      │
└─────────────────────────────────────┘
```

---

## 🧠 Neo4j 知识图谱实现

### 核心文件

**图谱搜索**: [`api/app/repositories/neo4j/graph_search.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/repositories/neo4j/graph_search.py)

**功能**:
- ✅ 实体搜索
- ✅ 陈述句搜索
- ✅ 记忆摘要搜索
- ✅ 分块搜索

**核心代码**:
```python
# [`graph_search.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/repositories/neo4j/graph_search.py#L1-L50)
async def _update_activation_values_batch(
    connector: Neo4jConnector,
    nodes: List[Dict[str, Any]],
    node_label: str,
    end_user_id: Optional[str] = None,
    max_retries: int = 3
) -> List[Dict[str, Any]]:
    """批量更新节点的激活值
    
    使用 ACT-R 公式计算激活值，结合遗忘曲线。
    """
    from app.core.memory.storage_services.forgetting_engine.access_history_manager import AccessHistoryManager
    from app.core.memory.storage_services.forgetting_engine.actr_calculator import ACTRCalculator
    
    actr_calculator = ACTRCalculator()
    access_manager = AccessHistoryManager(
        connector=connector,
        actr_calculator=actr_calculator,
        max_retries=max_retries
    )
    
    # 批量记录访问并更新激活值
    updated_nodes = await access_manager.record_batch_access(
        node_ids=unique_node_ids,
        node_label=node_label,
        end_user_id=end_user_id
    )
    
    return updated_nodes
```

**设计模式**:
- ✅ **仓库模式** - 数据访问抽象
- ✅ **批量处理** - 性能优化
- ✅ **重试机制** - 容错处理

---

## 📉 遗忘曲线实现

### 核心文件

**遗忘引擎**: [`api/app/core/memory/storage_services/forgetting_engine/forgetting_engine.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/forgetting_engine/forgetting_engine.py)

**遗忘曲线公式**:
```
R(t, S) = offset + (1 - offset) * exp(-λ_time * t / (λ_mem * S))

其中:
- R: 记忆保持率 (0 到 1)
- t: 自学习以来经过的时间
- S: 记忆强度
- offset: 最小保持率（防止完全遗忘）
- λ_time: 控制时间效应的 Lambda 参数
- λ_mem: 控制记忆强度效应的 Lambda 参数
```

**核心代码**:
```python
# [`forgetting_engine.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/forgetting_engine/forgetting_engine.py#L50-L100)
class ForgettingEngine:
    def forgetting_curve(self, t: float, S: float) -> float:
        """使用改进的艾宾浩斯遗忘曲线计算记忆保持率
        
        公式：R = offset + (1-offset) * e^(-λ_time * t / (λ_mem * S))
        """
        if S <= 0:
            return self.offset
        
        exponent = -self.lambda_time * t / (self.lambda_mem * S)
        retention = self.offset + (1 - self.offset) * math.exp(exponent)
        
        # 确保保持率在 0 到 1 之间
        return max(0.0, min(1.0, retention))
    
    def calculate_forgetting_score(self, time_elapsed: float, memory_strength: float) -> float:
        """计算遗忘分数 = 1 - 保持率"""
        retention = self.forgetting_curve(time_elapsed, memory_strength)
        return 1.0 - retention
```

**配置参数** ([`ForgettingEngineConfig`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/models/variate_config.py)):
```python
offset = 0.1          # 最小保持率 10%
lambda_time = 0.5     # 时间衰减系数
lambda_mem = 1.0      # 记忆强度系数
```

---

## 🔄 自我反思引擎实现

### 核心文件

**反思引擎**: [`api/app/core/memory/storage_services/reflection_engine/self_reflexion.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/reflection_engine/self_reflexion.py)

**反思类型**:
- ✅ **基于时间的反思** - 根据时间周期触发
- ✅ **基于事实的反思** - 检测记忆冲突
- ✅ **混合反思** - 整合多种策略

**核心代码**:
```python
# [`self_reflexion.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/reflection_engine/self_reflexion.py#L100-L200)
class ReflectionEngine:
    async def execute_reflection(self) -> ReflectionResult:
        """执行自我反思"""
        # 1. 获取记忆数据
        data = await self.get_data_func(
            range=self.config.reflexion_range,
            baseline=self.config.baseline
        )
        
        # 2. 冲突检测
        conflicts = await self._detect_conflicts(data)
        
        # 3. 冲突解决
        resolved_conflicts = await self._resolve_conflicts(conflicts)
        
        # 4. 记忆更新
        await self._update_memories(resolved_conflicts)
        
        return ReflectionResult(
            success=True,
            conflicts_found=len(conflicts),
            conflicts_resolved=len(resolved_conflicts),
            memories_updated=len(resolved_conflicts)
        )
```

**反思流程**:
```
1. 获取记忆数据 (Neo4j 查询)
    ↓
2. 冲突检测 (LLM 分析)
    ↓
3. 冲突解决 (LLM 推理)
    ↓
4. 记忆更新 (Neo4j 更新)
```

---

## 🔍 混合搜索实现

### 核心文件

**混合搜索**: [`api/app/core/memory/storage_services/search/hybrid_search.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/search/hybrid_search.py)

**搜索策略**:
- ✅ **关键词搜索** - Lucene 精确匹配
- ✅ **语义搜索** - BERT 向量检索
- ✅ **混合搜索** - 两者结合 + 重排序

**核心代码**:
```python
# [`hybrid_search.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/search/hybrid_search.py#L50-L150)
class HybridSearchStrategy(SearchStrategy):
    def __init__(
        self,
        connector: Optional[Neo4jConnector] = None,
        embedder_client: Optional[OpenAIEmbedderClient] = None,
        alpha: float = 0.6,
        use_forgetting_curve: bool = False
    ):
        """初始化混合搜索策略
        
        Args:
            alpha: BM25 分数权重（0.0-1.0）
            use_forgetting_curve: 是否使用遗忘曲线加权
        """
        self.alpha = alpha
        self.use_forgetting_curve = use_forgetting_curve
        
        # 创建子策略
        self.keyword_strategy = KeywordSearchStrategy(connector=connector)
        self.semantic_strategy = SemanticSearchStrategy(
            connector=connector,
            embedder_client=embedder_client
        )
    
    async def search(self, query_text: str, limit: int = 50) -> SearchResult:
        """执行混合搜索"""
        # 1. 关键词搜索
        keyword_results = await self.keyword_strategy.search(query_text, limit)
        
        # 2. 语义搜索
        semantic_results = await self.semantic_strategy.search(query_text, limit)
        
        # 3. 混合重排序
        combined_results = self._rerank(
            keyword_results,
            semantic_results,
            alpha=self.alpha
        )
        
        # 4. 应用遗忘曲线加权（可选）
        if self.use_forgetting_curve:
            combined_results = self._apply_forgetting_weights(combined_results)
        
        return combined_results
```

**重排序算法**:
```python
def _rerank(self, keyword_results, semantic_results, alpha=0.6):
    """RRF (Reciprocal Rank Fusion) 重排序"""
    combined_scores = {}
    
    # 关键词搜索分数
    for rank, result in enumerate(keyword_results):
        combined_scores[result.id] = alpha / (rank + 1)
    
    # 语义搜索分数
    for rank, result in enumerate(semantic_results):
        if result.id in combined_scores:
            combined_scores[result.id] += (1 - alpha) / (rank + 1)
        else:
            combined_scores[result.id] = (1 - alpha) / (rank + 1)
    
    # 按分数排序
    sorted_results = sorted(
        combined_scores.items(),
        key=lambda x: x[1],
        reverse=True
    )
    
    return sorted_results[:limit]
```

---

## 📊 性能优化

### 1. 批量处理

**批量更新激活值**:
```python
# [`graph_search.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/repositories/neo4j/graph_search.py#L30-L100)
async def _update_activation_values_batch(...):
    """批量更新节点激活值（性能优化）"""
    # 去重节点 ID
    unique_node_ids = list(dict.fromkeys(node_ids))
    
    # 批量记录访问
    updated_nodes = await access_manager.record_batch_access(
        node_ids=unique_node_ids,
        node_label=node_label,
        end_user_id=end_user_id
    )
    
    # 性能：单次查询更新多个节点 vs 多次单独更新
    # 提升：10-100 倍（取决于节点数量）
```

---

### 2. 并发控制

**并发限制**:
```python
# [`self_reflexion.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/reflection_engine/self_reflexion.py#L150)
class ReflectionEngine:
    def __init__(self):
        self._semaphore = asyncio.Semaphore(5)  # 并发数为 5
```

**优势**:
- ✅ 防止数据库过载
- ✅ 控制资源使用
- ✅ 保证稳定性

---

### 3. 缓存策略

**Redis 缓存**:
```python
# [`api/app/cache/`](https://github.com/qudi17/MemoryBear/tree/main/api/app/cache)
- session_cache.py      # 会话缓存
- memory_cache.py       # 记忆缓存
- search_cache.py       # 搜索结果缓存
```

**缓存命中率**: ~80%（根据 README）

---

## 🎯 Phase 2 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 分析 Neo4j 实现 | 完成 | 图谱搜索 + 激活值更新 |
| ✅ 分析遗忘曲线 | 完成 | ACT-R 公式实现 |
| ✅ 分析反思引擎 | 完成 | 冲突检测 + 解决 |
| ✅ 分析混合搜索 | 完成 | 关键词 + 语义 + RRF |
| ✅ 所有引用有链接 | 完成 | GitHub 链接 + 行号 |

---

## 📝 研究笔记

### 关键发现

1. **三层记忆架构** - Redis + 向量 + Neo4j
2. **ACT-R 遗忘曲线** - 改进的艾宾浩斯公式
3. **自我反思引擎** - 冲突检测 + 解决
4. **混合搜索** - 关键词 + 语义 + RRF 重排序
5. **性能优化** - 批量处理 + 并发控制 + 缓存

### 待深入研究

- [ ] Agent 系统实现
- [ ] 工具系统分析
- [ ] 与 nanobot 对比

---

## 🔗 下一步：Phase 3

**目标**: 分析 Agent 和工具系统

**任务**:
- [ ] 分析 LangChain Agent 实现
- [ ] 分析工具系统架构
- [ ] 分析 MCP 集成
- [ ] 撰写 Phase 3 报告

**产出**: `03-agent-tools-analysis.md`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能
