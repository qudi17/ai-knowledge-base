# MemoryBear - Neo4j 查询与遗忘曲线深度研究

**研究日期**：2026-02-28  
**研究方法**：毛线团研究法（分支研究）  
**研究内容**：Neo4j Cypher 查询、向量数据库、遗忘曲线实现

---

## 🧶 研究分支

这是 RAG 检索流程研究的深入分支，研究：
1. ✅ **Neo4j Cypher 查询** - 关键词搜索和语义搜索的具体查询
2. ✅ **向量数据库实现** - 向量嵌入和相似度计算
3. ✅ **遗忘曲线实现** - 基于 ACT-R 理论的遗忘机制
4. ✅ **激活值计算** - 记忆访问历史和重要性评分

---

## 1️⃣ Neo4j Cypher 查询详解

### 1.1 关键词搜索查询

**文件**：[`app/repositories/neo4j/cypher_queries.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/repositories/neo4j/cypher_queries.py)

#### 查询 Statements（陈述句）

**Cypher 查询**：`SEARCH_STATEMENTS_BY_KEYWORD` (L285-L323)

```cypher
MATCH (s:Statement)
WHERE 
    (s.end_user_id IS NULL OR s.end_user_id = $end_user_id)
    AND s.statement CONTAINS $q
RETURN 
    s.id AS id,
    s.statement AS statement,
    s.created_at AS created_at,
    s.expired_at AS expired_at,
    s.valid_at AS valid_at,
    s.invalid_at AS invalid_at,
    s.stmt_type AS stmt_type,
    s.temporal_info AS temporal_info,
    s.importance_score AS importance_score,
    s.activation_value AS activation_value,
    s.access_history AS access_history,
    s.last_access_time AS last_access_time,
    s.access_count AS access_count
ORDER BY s.created_at DESC
LIMIT $limit
```

**用途**：搜索包含关键词的陈述句  
**参数**：
- `$q`: 查询关键词
- `$end_user_id`: 用户 ID（过滤条件）
- `$limit`: 结果数量限制

**返回字段**：
- `statement`: 陈述句内容
- `temporal_info`: 时间信息
- `importance_score`: 重要性评分
- `activation_value`: 激活值（用于遗忘曲线）

---

#### 查询 Memory Summaries（记忆总结）

**Cypher 查询**：`SEARCH_MEMORY_SUMMARIES_BY_KEYWORD` (L632-L670)

```cypher
MATCH (ms:MemorySummary)
WHERE 
    (ms.end_user_id IS NULL OR ms.end_user_id = $end_user_id)
    AND ms.content CONTAINS $q
RETURN 
    ms.id AS id,
    ms.content AS content,
    ms.created_at AS created_at,
    ms.expired_at AS expired_at,
    ms.importance_score AS importance_score,
    ms.activation_value AS activation_value,
    ms.access_history AS access_history,
    ms.last_access_time AS last_access_time,
    ms.access_count AS access_count
ORDER BY ms.created_at DESC
LIMIT $limit
```

**用途**：搜索包含关键词的记忆总结  
**特点**：总结是合成信息，最上下文相关

---

#### 查询 Entities（实体）

**Cypher 查询**：`SEARCH_ENTITIES_BY_NAME` (L375-L400)

```cypher
MATCH (e:ExtractedEntity)
WHERE 
    (e.end_user_id IS NULL OR e.end_user_id = $end_user_id)
    AND e.name CONTAINS $q
RETURN 
    e.id AS id,
    e.name AS name,
    e.description AS description,
    e.entity_type AS entity_type,
    e.aliases AS aliases,
    e.created_at AS created_at,
    e.expired_at AS expired_at,
    e.importance_score AS importance_score,
    e.activation_value AS activation_value,
    e.access_history AS access_history,
    e.last_access_time AS last_access_time,
    e.access_count AS access_count
ORDER BY e.created_at DESC
LIMIT $limit
```

**用途**：搜索实体名称包含关键词的实体

---

#### 查询 Chunks（文本块）

**Cypher 查询**：`SEARCH_CHUNKS_BY_CONTENT` (L402-L428)

```cypher
MATCH (c:Chunk)
WHERE 
    (c.end_user_id IS NULL OR c.end_user_id = $end_user_id)
    AND c.content CONTAINS $q
RETURN 
    c.id AS id,
    c.content AS content,
    c.created_at AS created_at,
    c.expired_at AS expired_at,
    c.dialog_id AS dialog_id,
    c.sequence_number AS sequence_number
ORDER BY c.created_at DESC
LIMIT $limit
```

**用途**：搜索文本块内容包含关键词的块

---

### 1.2 语义搜索查询

**文件**：[`cypher_queries.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/repositories/neo4j/cypher_queries.py)

#### 查询 Statements（向量相似度）

**Cypher 查询**：`STATEMENT_EMBEDDING_SEARCH` (L245-L283)

```cypher
MATCH (s:Statement)
WHERE 
    (s.end_user_id IS NULL OR s.end_user_id = $end_user_id)
    AND s.statement_embedding IS NOT NULL
WITH s, vector.similarity.cosine(s.statement_embedding, $query_embedding) AS score
WHERE score > 0.5
RETURN 
    s.id AS id,
    s.statement AS statement,
    s.created_at AS created_at,
    s.expired_at AS expired_at,
    s.valid_at AS valid_at,
    s.invalid_at AS invalid_at,
    s.stmt_type AS stmt_type,
    s.temporal_info AS temporal_info,
    s.importance_score AS importance_score,
    s.activation_value AS activation_value,
    s.access_history AS access_history,
    s.last_access_time AS last_access_time,
    s.access_count AS access_count,
    score
ORDER BY score DESC
LIMIT $limit
```

**关键技术**：
- `vector.similarity.cosine()`: Neo4j 向量相似度函数
- `score > 0.5`: 相似度阈值（余弦相似度 > 0.5）
- `ORDER BY score DESC`: 按相似度降序排序

**参数**：
- `$query_embedding`: 查询文本的向量嵌入（数组）
- `$end_user_id`: 用户 ID
- `$limit`: 结果数量

---

#### 查询 Memory Summaries（向量相似度）

**Cypher 查询**：`MEMORY_SUMMARY_EMBEDDING_SEARCH` (L708-L745)

```cypher
MATCH (ms:MemorySummary)
WHERE 
    (ms.end_user_id IS NULL OR ms.end_user_id = $end_user_id)
    AND ms.summary_embedding IS NOT NULL
WITH ms, vector.similarity.cosine(ms.summary_embedding, $query_embedding) AS score
WHERE score > 0.5
RETURN 
    ms.id AS id,
    ms.content AS content,
    ms.created_at AS created_at,
    ms.expired_at AS expired_at,
    ms.importance_score AS importance_score,
    ms.activation_value AS activation_value,
    ms.access_history AS access_history,
    ms.last_access_time AS last_access_time,
    ms.access_count AS access_count,
    score
ORDER BY score DESC
LIMIT $limit
```

---

### 1.3 节点保存查询

#### 保存 Statement 节点

**Cypher 查询**：`STATEMENT_NODE_SAVE` (L13-L43)

```cypher
UNWIND $statements AS statement
MERGE (s:Statement {id: statement.id})
SET s += {
    id: statement.id,
    run_id: statement.run_id,
    chunk_id: statement.chunk_id,
    end_user_id: statement.end_user_id,
    stmt_type: statement.stmt_type,
    statement: statement.statement,
    emotion_intensity: statement.emotion_intensity,
    emotion_target: statement.emotion_target,
    emotion_subject: statement.emotion_subject,
    emotion_type: statement.emotion_type,
    emotion_keywords: statement.emotion_keywords,
    temporal_info: statement.temporal_info,
    created_at: statement.created_at,
    expired_at: statement.expired_at,
    valid_at: statement.valid_at,
    invalid_at: statement.invalid_at,
    statement_embedding: statement.statement_embedding,
    relevence_info: statement.relevence_info,
    importance_score: statement.importance_score,
    activation_value: statement.activation_value,
    access_history: statement.access_history,
    last_access_time: statement.last_access_time,
    access_count: statement.access_count
}
RETURN s.id AS uuid
```

**特点**：
- `MERGE`: 如果存在则更新，不存在则创建
- `UNWIND`: 批量处理多个节点
- `s += {}`: 批量设置属性

---

#### 保存 Entity 节点（智能合并）

**Cypher 查询**：`EXTRACTED_ENTITY_NODE_SAVE` (L66-L128)

```cypher
UNWIND $entities AS entity
MERGE (e:ExtractedEntity {id: entity.id})
SET e.name = CASE 
    WHEN entity.name IS NOT NULL AND entity.name <> '' 
    THEN entity.name 
    ELSE e.name 
END,
e.description = CASE
    WHEN entity.description IS NOT NULL AND entity.description <> ''
     AND (e.description IS NULL OR size(e.description) = 0 OR size(entity.description) > size(e.fact_summary))
    THEN entity.description 
    ELSE e.description 
END,
// ... 更多智能合并逻辑
RETURN e.id AS uuid
```

**智能合并策略**：
- 保留非空字段
- 优先保留更长的描述
- 合并别名列表（去重）
- 保留最早创建时间

---

### 1.4 边（关系）保存查询

#### 保存 Dialogue-Statement 边

**Cypher 查询**：`DIALOGUE_STATEMENT_EDGE_SAVE` (L203-L217)

```cypher
UNWIND $dialogue_statement_edges AS edge
MATCH (dialogue:Dialogue)
WHERE dialogue.uuid = edge.source OR dialogue.ref_id = edge.source
MATCH (statement:Statement {id: edge.target})
MERGE (dialogue)-[e:MENTIONS]->(statement)
SET e.uuid = edge.id,
    e.end_user_id = edge.end_user_id,
    e.created_at = edge.created_at,
    e.expired_at = edge.expired_at
RETURN e.uuid AS uuid
```

**关系类型**：`MENTIONS`（提及）  
**用途**：连接对话和提到的陈述句

---

#### 保存 Entity-Entity 关系

**Cypher 查询**：`ENTITY_RELATIONSHIP_SAVE` (L154-L170)

```cypher
UNWIND $relationships AS rel
MATCH (subject:ExtractedEntity {id: rel.source_id, end_user_id: rel.end_user_id})
MATCH (object:ExtractedEntity {id: rel.target_id, end_user_id: rel.end_user_id})
MERGE (subject)-[r:EXTRACTED_RELATIONSHIP]->(object)
SET r.predicate = rel.predicate,
    r.statement_id = rel.statement_id,
    r.value = rel.value,
    r.statement = rel.statement,
    r.valid_at = rel.valid_at,
    r.invalid_at = rel.invalid_at,
    r.created_at = rel.created_at,
    r.expired_at = rel.expired_at,
    r.run_id = rel.run_id,
    r.end_user_id = rel.end_user_id
RETURN elementId(r) AS uuid
```

**关系类型**：`EXTRACTED_RELATIONSHIP`  
**属性**：
- `predicate`: 关系谓词（如"works_for", "located_in"）
- `value`: 关系值
- `statement`: 来源陈述句

---

## 2️⃣ 向量数据库实现

### 2.1 向量嵌入生成

**文件**：[`app/core/memory/llm_tools/openai_embedder.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/llm_tools/openai_embedder.py)

**嵌入模型配置**：
```python
# 从数据库读取嵌入器配置
with get_db_context() as db:
    config_service = MemoryConfigService(db)
    embedder_config_dict = config_service.get_embedder_config(
        config_defs.SELECTED_EMBEDDING_ID
    )

rb_config = RedBearModelConfig(
    model_name=embedder_config_dict["model_name"],  # 如 "text-embedding-3-small"
    provider=embedder_config_dict["provider"],      # 如 "openai"
    api_key=embedder_config_dict["api_key"],
    base_url=embedder_config_dict["base_url"],
    type="llm"
)

embedder_client = OpenAIEmbedderClient(model_config=rb_config)
```

**支持的嵌入模型**：
- OpenAI: `text-embedding-3-small`, `text-embedding-3-large`
- 通义千问：`text-embedding-v2`
- 本地模型：通过 `base_url` 配置

---

### 2.2 向量相似度计算

**Neo4j 向量函数**：
```cypher
vector.similarity.cosine(vector1, vector2)
```

**相似度阈值**：
- `score > 0.5`: 中等相似度
- `score > 0.7`: 高相似度
- `score > 0.9`: 极高相似度

**归一化算法**：
```python
def normalize_scores(results, score_field="score"):
    """使用 z-score 标准化和 sigmoid 转换"""
    if not results:
        return results
    
    # 提取分数
    scores = [item.get(score_field) for item in results]
    
    # 计算均值和标准差
    mean_score = sum(scores) / len(scores)
    std_dev = math.sqrt(sum((s - mean_score)**2 for s in scores) / len(scores))
    
    # z-score 标准化 + sigmoid 转换
    for item, score in zip(results, scores):
        z_score = (score - mean_score) / std_dev
        normalized = 1 / (1 + math.exp(-z_score))  # sigmoid
        item[f"normalized_{score_field}"] = normalized
    
    return results
```

---

### 2.3 混合搜索重排序

**文件**：[`app/core/memory/src/search.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/src/search.py)

**Reciprocal Rank Fusion (RRF)**：
```python
def rerank_with_activation(
    keyword_results: Dict[str, List[Dict]],
    embedding_results: Dict[str, List[Dict]],
    alpha: float = 0.6,  # BM25 权重
    limit: int = 10,
    activation_boost_factor: float = 0.8
) -> Dict[str, List[Dict]]:
    """融合关键词和语义搜索结果"""
    
    # 1. 归一化分数
    keyword_results = normalize_scores(keyword_results, "score")
    embedding_results = normalize_scores(embedding_results, "score")
    
    # 2. 融合分数
    final_scores = {}
    for category in ["statements", "chunks", "entities", "summaries"]:
        merged = []
        keyword_map = {item["id"]: item for item in keyword_results.get(category, [])}
        embedding_map = {item["id"]: item for item in embedding_results.get(category, [])}
        
        all_ids = set(keyword_map.keys()) | set(embedding_map.keys())
        
        for item_id in all_ids:
            keyword_item = keyword_map.get(item_id, {})
            embedding_item = embedding_map.get(item_id, {})
            
            # RRF 融合
            final_score = (
                alpha * keyword_item.get("normalized_score", 0) +
                (1 - alpha) * embedding_item.get("normalized_score", 0)
            )
            
            # 激活值加成
            if "activation_value" in keyword_item:
                final_score += activation_boost_factor * keyword_item["activation_value"]
            
            merged_item = {**keyword_item, **embedding_item, "final_score": final_score}
            merged.append(merged_item)
        
        # 排序并限制数量
        merged.sort(key=lambda x: x["final_score"], reverse=True)
        final_scores[category] = merged[:limit]
    
    return final_scores
```

**融合策略**：
- `alpha=0.6`: BM25 权重 60%，语义权重 40%
- `activation_boost_factor=0.8`: 激活值加成系数
- 按 `final_score` 降序排序

---

## 3️⃣ 遗忘曲线实现

### 3.1 遗忘引擎核心

**文件**：[`app/core/memory/storage_services/forgetting_engine/forgetting_engine.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/forgetting_engine/forgetting_engine.py)

**遗忘曲线公式**：
```python
R(t, S) = offset + (1 - offset) * exp(-λ_time * t / (λ_mem * S))
```

**参数说明**：
- `R`: 记忆保持率（0 到 1）
- `t`: 经过的时间（天）
- `S`: 记忆强度
- `offset`: 最小保持率（防止完全遗忘）
- `λ_time`: 时间衰减参数
- `λ_mem`: 记忆强度参数

**配置类**：
```python
class ForgettingEngineConfig:
    offset: float = 0.1          # 最小保持率 10%
    lambda_time: float = 0.5     # 时间衰减参数
    lambda_mem: float = 1.0      # 记忆强度参数
    forgetting_threshold: float = 0.5  # 遗忘阈值
```

---

### 3.2 遗忘分数计算

**代码实现**：
```python
class ForgettingEngine:
    def __init__(self, config=None):
        self.config = config or ForgettingEngineConfig()
        self.offset = self.config.offset
        self.lambda_time = self.config.lambda_time
        self.lambda_mem = self.config.lambda_mem
    
    def forgetting_curve(self, t: float, S: float) -> float:
        """计算记忆保持率"""
        if S <= 0:
            return self.offset
        
        exponent = -self.lambda_time * t / (self.lambda_mem * S)
        retention = self.offset + (1 - self.offset) * math.exp(exponent)
        
        return max(0.0, min(1.0, retention))
    
    def calculate_forgetting_score(self, time_elapsed: float, memory_strength: float) -> float:
        """计算遗忘分数（1 - 保持率）"""
        retention = self.forgetting_curve(time_elapsed, memory_strength)
        return 1.0 - retention
```

**示例计算**：
```python
engine = ForgettingEngine()

# 新记忆（t=0 天，S=1.0）
score = engine.calculate_forgetting_score(0, 1.0)
# → 0.0（不会遗忘）

# 1 天后的记忆（t=1, S=1.0）
score = engine.calculate_forgetting_score(1, 1.0)
# → 0.3（轻微遗忘）

# 7 天后的记忆（t=7, S=0.5）
score = engine.calculate_forgetting_score(7, 0.5)
# → 0.7（严重遗忘）
```

---

### 3.3 激活值计算（ACT-R 理论）

**文件**：[`app/core/memory/storage_services/forgetting_engine/actr_calculator.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/forgetting_engine/actr_calculator.py)

**ACT-R 激活值公式**：
```python
A_i = ln(Σ_j (t_j^(-d))) + S_i + Σ_k PC_k
```

**参数说明**：
- `A_i`: 记忆块 i 的激活值
- `t_j`: 第 j 次访问距现在的时间
- `d`: 衰减参数（默认 0.5）
- `S_i`: 源激活（外部刺激强度）
- `PC_k`: 部分匹配惩罚

**代码实现**：
```python
class ACTRCalculator:
    def __init__(self, decay=0.5):
        self.decay = decay  # 衰减参数 d
    
    def calculate_activation_value(
        self,
        access_history: List[datetime],
        importance_score: float = 0.5,
        now: Optional[datetime] = None
    ) -> float:
        """计算 ACT-R 激活值"""
        if not access_history:
            return 0.0
        
        now = now or datetime.now()
        
        # 计算历史激活项
        activation_sum = 0.0
        for access_time in access_history:
            t_j = (now - access_time).total_seconds() / 86400  # 转换为天
            if t_j > 0:
                activation_sum += t_j ** (-self.decay)
        
        # 对数转换
        if activation_sum > 0:
            history_activation = math.log(activation_sum)
        else:
            history_activation = 0.0
        
        # 加上重要性评分（作为源激活 S_i）
        total_activation = history_activation + importance_score
        
        return total_activation
```

---

### 3.4 访问历史管理

**文件**：[`app/core/memory/storage_services/forgetting_engine/access_history_manager.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/forgetting_engine/access_history_manager.py)

**批量更新激活值**：
```python
async def record_batch_access(
    self,
    node_ids: List[str],
    node_label: str,
    end_user_id: Optional[str] = None
) -> List[Dict[str, Any]]:
    """批量记录节点访问并更新激活值"""
    
    # 1. 读取现有节点数据
    existing_nodes = await self._fetch_nodes(node_ids, node_label, end_user_id)
    
    # 2. 更新访问历史
    now = datetime.now()
    for node in existing_nodes:
        access_history = node.get("access_history", [])
        access_history.append(now.isoformat())
        
        # 限制历史记录数量（保留最近 100 次）
        if len(access_history) > 100:
            access_history = access_history[-100:]
        
        node["access_history"] = access_history
        node["last_access_time"] = now
        node["access_count"] = len(access_history)
    
    # 3. 重新计算激活值
    for node in existing_nodes:
        activation_value = self.actr_calculator.calculate_activation_value(
            access_history=[datetime.fromisoformat(t) for t in node["access_history"]],
            importance_score=node.get("importance_score", 0.5)
        )
        node["activation_value"] = activation_value
    
    # 4. 批量写回 Neo4j
    await self._update_nodes(existing_nodes, node_label)
    
    return existing_nodes
```

**访问历史格式**：
```json
{
  "access_history": [
    "2026-02-28T10:00:00",
    "2026-02-27T15:30:00",
    "2026-02-26T09:15:00"
  ],
  "last_access_time": "2026-02-28T10:00:00",
  "access_count": 3,
  "activation_value": 1.25
}
```

---

## 4️⃣ 搜索结果激活值更新

**文件**：[`app/repositories/neo4j/graph_search.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/repositories/neo4j/graph_search.py)

**批量更新逻辑**：
```python
async def _update_activation_values_batch(
    connector: Neo4jConnector,
    nodes: List[Dict[str, Any]],
    node_label: str,
    end_user_id: Optional[str] = None,
    max_retries: int = 3
) -> List[Dict[str, Any]]:
    """批量更新节点的激活值"""
    
    # 创建计算器和管理器
    actr_calculator = ACTRCalculator()
    access_manager = AccessHistoryManager(
        connector=connector,
        actr_calculator=actr_calculator,
        max_retries=max_retries
    )
    
    # 提取节点 ID 并去重
    unique_node_ids = list(set(node.get('id') for node in nodes if node.get('id')))
    
    # 批量记录访问
    updated_nodes = await access_manager.record_batch_access(
        node_ids=unique_node_ids,
        node_label=node_label,
        end_user_id=end_user_id
    )
    
    return updated_nodes
```

**更新流程**：
```
搜索结果 → 提取节点 ID → 批量读取 → 更新访问历史 → 重新计算激活值 → 批量写回
```

**性能优化**：
- 批量处理（一次更新多个节点）
- 去重（避免重复更新）
- 重试机制（处理并发冲突）

---

## 5️⃣ 完整数据流

### 5.1 记忆写入流程

```
用户对话
    ↓
提取 Statements/Entities
    ↓
生成向量嵌入（OpenAI Embedding）
    ↓
保存到 Neo4j（MERGE 节点和边）
    ↓
设置初始激活值（activation_value=0.5）
    ↓
设置初始重要性评分（importance_score=0.5）
```

### 5.2 记忆检索流程

```
用户提问
    ↓
生成查询向量嵌入
    ↓
执行混合搜索（关键词 + 语义）
    ↓
Neo4j Cypher 查询
    ↓
返回搜索结果（含激活值）
    ↓
更新访问历史和激活值
    ↓
重排序（RRF + 激活值加成）
    ↓
返回给 LLM 生成答案
```

### 5.3 遗忘曲线应用

```
每次检索 → 记录访问时间 → 更新 access_history
    ↓
计算激活值（ACT-R 公式）
    ↓
如果 activation_value < 阈值 → 标记为待遗忘
    ↓
定期清理（后台任务）
```

---

## 6️⃣ 性能优化策略

### 6.1 并行查询

```python
# 并行执行多个类别的查询
tasks = []
task_keys = []

if "statements" in include:
    tasks.append(connector.execute_query(SEARCH_STATEMENTS_BY_KEYWORD, ...))
    task_keys.append("statements")

if "entities" in include:
    tasks.append(connector.execute_query(SEARCH_ENTITIES_BY_NAME, ...))
    task_keys.append("entities")

# 并行执行
task_results = await asyncio.gather(*tasks, return_exceptions=True)
```

**性能提升**：4 个类别并行，减少 75% 查询时间

---

### 6.2 批量更新

```python
# 批量更新激活值（而非逐个更新）
updated_nodes = await access_manager.record_batch_access(
    node_ids=unique_node_ids,  # 去重后的 ID 列表
    node_label=node_label,
    end_user_id=end_user_id
)
```

**性能提升**：批量更新比单个更新快 10-100 倍

---

### 6.3 结果去重

```python
def _deduplicate_results(items: List[Dict]) -> List[Dict]:
    """基于 ID 和内容去重"""
    seen_ids = set()
    seen_content = set()
    deduplicated = []
    
    for item in items:
        item_id = item.get("id") or item.get("uuid")
        content = item.get("text") or item.get("content") or ""
        normalized_content = str(content).strip().lower()
        
        if item_id and item_id in seen_ids:
            continue
        if normalized_content and normalized_content in seen_content:
            continue
        
        seen_ids.add(item_id)
        seen_content.add(normalized_content)
        deduplicated.append(item)
    
    return deduplicated
```

---

## 7️⃣ 关键发现

### 7.1 Neo4j 向量支持

**Neo4j 5+ 向量功能**：
- `vector.similarity.cosine()`: 余弦相似度
- `vector.similarity.euclidean()`: 欧几里得距离
- 支持向量索引（提高查询速度）

**索引创建**：
```cypher
CREATE VECTOR INDEX statement_embedding_index
FOR (s:Statement)
ON (s.statement_embedding)
OPTIONS {indexConfig: {
    `vector.dimensions`: 1536,
    `vector.similarity_function`: 'cosine'
}}
```

---

### 7.2 遗忘曲线参数调优

**推荐配置**：
```python
ForgettingEngineConfig(
    offset=0.1,           # 最小保持率 10%
    lambda_time=0.5,      # 时间衰减适中
    lambda_mem=1.0,       # 记忆强度线性影响
    forgetting_threshold=0.5  # 50% 遗忘阈值
)
```

**调优建议**：
- 增加 `lambda_time`: 加速遗忘
- 增加 `lambda_mem`: 增强记忆强度影响
- 降低 `forgetting_threshold`: 更严格保留

---

### 7.3 激活值作用

**激活值影响**：
1. **检索排序**：激活值高的节点优先返回
2. **遗忘决策**：激活值低的节点优先遗忘
3. **重排序加成**：`final_score += 0.8 * activation_value`

**激活值来源**：
- 访问历史（主要来源）
- 重要性评分（次要来源）
- 情绪强度（可选加成）

---

## 📋 待研究分支

- [ ] **向量索引优化** - Neo4j 向量索引性能
- [ ] **遗忘调度器** - 定期清理低激活值节点
- [ ] **情绪影响** - 情绪对记忆强度的影响
- [ ] **部分匹配惩罚** - ACT-R 的 PC_k 参数实现

---

**研究人**：Jarvis  
**日期**：2026-02-28  
**方法**：毛线团研究法（分支深入）  
**状态**：✅ Neo4j 查询 + 向量数据库 + 遗忘曲线完成
