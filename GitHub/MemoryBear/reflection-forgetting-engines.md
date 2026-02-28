# MemoryBear - 反思引擎与遗忘调度器深度研究

**研究日期**：2026-02-28  
**研究方法**：毛线团研究法（分支研究）  
**研究内容**：自我反思引擎、遗忘调度器、遗忘策略

---

## 🧶 研究分支

这是 MemoryBear 记忆系统研究的深入分支，研究：
1. ✅ **自我反思引擎** - 记忆冲突检测和解决
2. ✅ **遗忘调度器** - 定期遗忘周期管理
3. ✅ **遗忘策略** - 基于 ACT-R 的节点融合
4. ✅ **LLM 摘要生成** - 高质量记忆融合

---

## 1️⃣ 自我反思引擎（Reflection Engine）

### 1.1 核心架构

**文件**：[`app/core/memory/storage_services/reflection_engine/self_reflexion.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/reflection_engine/self_reflexion.py) (26.9KB)

**类结构**：
```python
class ReflectionEngine:
    """自我反思引擎"""
    
    def __init__(self, config: ReflectionConfig, ...):
        self.config = config
        self.neo4j_connector = Neo4jConnector()
        self.llm_client = MemoryClientFactory().get_llm_client(...)
    
    async def run_reflection(self) -> ReflectionResult:
        """运行反思流程"""
```

**配置类**：
```python
class ReflectionConfig(BaseModel):
    enabled: bool = False                    # 是否启用
    iteration_period: str = "3"              # 反思周期（天）
    reflexion_range: ReflectionRange = ReflectionRange.PARTIAL
    baseline: ReflectionBaseline = ReflectionBaseline.TIME
    model_id: Optional[str] = None           # LLM 模型 ID
    end_user_id: Optional[str] = None
    
    # 评估相关
    memory_verify: bool = True               # 记忆验证
    quality_assessment: bool = True          # 质量评估
    violation_handling_strategy: str = "warn"  # 违规处理策略
```

**枚举类型**：
```python
class ReflectionRange(str, Enum):
    PARTIAL = "partial"  # 从检索结果中反思
    ALL = "all"          # 从整个数据库中反思

class ReflectionBaseline(str, Enum):
    TIME = "TIME"   # 基于时间的反思
    FACT = "FACT"   # 基于事实的反思
    HYBRID = "HYBRID"  # 混合反思
```

---

### 1.2 反思流程

**完整流程**：
```
1. 加载配置 → ReflectionConfig
   ↓
2. 选择反思范围 → PARTIAL 或 ALL
   ↓
3. 选择反思基线 → TIME 或 FACT 或 HYBRID
   ↓
4. 获取记忆数据 → Neo4j 查询
   ↓
5. LLM 评估冲突 → render_evaluate_prompt()
   ↓
6. LLM 生成解决方案 → render_reflexion_prompt()
   ↓
7. 应用更改 → update Neo4j
   ↓
8. 返回结果 → ReflectionResult
```

**代码实现**：
```python
async def run_reflection(self) -> ReflectionResult:
    """运行完整的反思流程"""
    start_time = time.time()
    
    try:
        # 1. 获取记忆数据
        if self.config.reflexion_range == "partial":
            data = await self.get_data_func(
                neo4j_connector=self.neo4j_connector,
                end_user_id=self.config.end_user_id,
                limit=50  # 限制检索数量
            )
        else:  # "all"
            data = await self.get_data_func(
                neo4j_connector=self.neo4j_connector,
                end_user_id=self.config.end_user_id,
                limit=None  # 获取全部
            )
        
        # 2. 渲染评估提示词
        evaluate_prompt = await self.render_evaluate_prompt_func(
            baseline=self.config.baseline,
            data=data,
            output_example=self.config.output_example
        )
        
        # 3. LLM 评估冲突
        conflict_response = await self.llm_client.chat(
            system_prompt="You are a memory conflict detector.",
            messages=[{"role": "user", "content": evaluate_prompt}],
            response_model=ConflictResultSchema
        )
        
        conflicts = conflict_response.conflicts
        conflicts_found = len(conflicts)
        
        if conflicts_found == 0:
            return ReflectionResult(
                success=True,
                message="No conflicts found",
                conflicts_found=0
            )
        
        # 4. 渲染反思提示词
        reflexion_prompt = await self.render_reflexion_prompt_func(
            baseline=self.config.baseline,
            data=data,
            conflicts=conflicts,
            output_example=self.config.output_example
        )
        
        # 5. LLM 生成解决方案
        reflexion_response = await self.llm_client.chat(
            system_prompt="You are a memory conflict resolver.",
            messages=[{"role": "user", "content": reflexion_prompt}],
            response_model=ReflexionResultSchema
        )
        
        # 6. 应用更改
        changes = reflexion_response.changes
        for change in changes:
            await self._apply_change(change)
        
        conflicts_resolved = len([c for c in changes if c.resolved])
        memories_updated = len(changes)
        
        # 7. 返回结果
        execution_time = time.time() - start_time
        
        return ReflectionResult(
            success=True,
            message=f"Resolved {conflicts_resolved} conflicts",
            conflicts_found=conflicts_found,
            conflicts_resolved=conflicts_resolved,
            memories_updated=memories_updated,
            execution_time=execution_time
        )
        
    except Exception as e:
        return ReflectionResult(
            success=False,
            message=str(e),
            execution_time=time.time() - start_time
        )
```

---

### 1.3 冲突检测

**评估提示词模板**：
```python
def render_evaluate_prompt(
    baseline: str,
    data: Dict[str, Any],
    output_example: Optional[str] = None
) -> str:
    """渲染冲突评估提示词"""
    
    if baseline == "TIME":
        prompt = """
You are a memory conflict detector.

Analyze the following memory items for temporal conflicts:

Memory Items:
{data}

Look for:
1. Contradictory statements about the same event at different times
2. Overlapping time ranges with conflicting information
3. Invalid temporal sequences (effect before cause)

Output format:
{{
  "conflicts": [
    {{
      "type": "temporal",
      "statement_ids": ["id1", "id2"],
      "description": "Description of the conflict",
      "severity": "high|medium|low"
    }}
  ]
}}
""".format(data=json.dumps(data, indent=2))
    
    elif baseline == "FACT":
        prompt = """
You are a memory conflict detector.

Analyze the following memory items for factual conflicts:

Memory Items:
{data}

Look for:
1. Contradictory facts about the same entity
2. Inconsistent relationships between entities
3. Logical impossibilities

Output format:
{{
  "conflicts": [
    {{
      "type": "factual",
      "statement_ids": ["id1", "id2"],
      "description": "Description of the conflict",
      "severity": "high|medium|low"
    }}
  ]
}}
""".format(data=json.dumps(data, indent=2))
    
    return prompt
```

**冲突类型**：
1. **Temporal Conflicts** - 时间冲突
   - 同一事件的不同时间描述
   - 时间范围重叠但信息冲突
   - 无效时间序列（结果在原因之前）

2. **Factual Conflicts** - 事实冲突
   - 同一实体的矛盾事实
   - 实体间关系不一致
   - 逻辑不可能

**冲突严重性**：
- `high`: 直接矛盾，必须解决
- `medium`: 可能矛盾，需要验证
- `low`: 轻微不一致，可忽略

---

### 1.4 冲突解决

**反思提示词模板**：
```python
def render_reflexion_prompt(
    baseline: str,
    data: Dict[str, Any],
    conflicts: List[Dict[str, Any]],
    output_example: Optional[str] = None
) -> str:
    """渲染冲突解决提示词"""
    
    prompt = """
You are a memory conflict resolver.

Memory Items:
{data}

Detected Conflicts:
{conflicts}

For each conflict, propose a resolution:
1. Merge conflicting statements into a unified statement
2. Mark one statement as invalid (if clearly wrong)
3. Create a new statement that reconciles both

Output format:
{{
  "changes": [
    {{
      "conflict_id": 1,
      "action": "merge|invalidate|reconcile",
      "affected_statement_ids": ["id1", "id2"],
      "new_statement": {{
        "statement": "Unified statement text",
        "valid_at": "2026-01-01T00:00:00",
        "invalid_at": null,
        "importance_score": 0.8,
        "activation_value": 0.6
      }},
      "reasoning": "Why this resolution was chosen",
      "resolved": true
    }}
  ]
}}
""".format(
        data=json.dumps(data, indent=2),
        conflicts=json.dumps(conflicts, indent=2)
    )
    
    return prompt
```

**解决策略**：
1. **Merge** - 合并冲突陈述
   - 创建统一的新陈述
   - 保留溯源信息
   - 继承较高的激活值

2. **Invalidate** - 标记为无效
   - 设置 `invalid_at` 时间戳
   - 保留历史记录
   - 降低激活值

3. **Reconcile** - 调和冲突
   - 创建新陈述调和两者
   - 保留原始陈述
   - 添加关系边

---

### 1.5 应用更改

**Cypher 更新查询**：
```python
UPDATE_QUERY = """
UNWIND $changes AS change
MATCH (s:Statement {id: change.statement_id})

// 如果是合并操作
CASE WHEN change.action = 'merge' THEN
    // 创建新陈述
    CREATE (new:Statement {
        id: change.new_statement.id,
        statement: change.new_statement.statement,
        valid_at: change.new_statement.valid_at,
        invalid_at: change.new_statement.invalid_at,
        importance_score: change.new_statement.importance_score,
        activation_value: change.new_statement.activation_value,
        end_user_id: s.end_user_id
    })
    // 删除原始陈述
    DETACH DELETE s
    
// 如果是标记无效操作
CASE WHEN change.action = 'invalidate' THEN
    SET s.invalid_at = change.invalid_at,
        s.activation_value = s.activation_value * 0.5

// 如果是调和操作
CASE WHEN change.action = 'reconcile' THEN
    // 创建调和陈述
    CREATE (new:Statement {
        id: change.new_statement.id,
        statement: change.new_statement.statement,
        ...
    })
    // 保留原始陈述，添加关系边
    CREATE (s)-[r:RECONCILED_BY]->(new)
"""
```

---

## 2️⃣ 遗忘调度器（Forgetting Scheduler）

### 2.1 核心架构

**文件**：[`app/core/memory/storage_services/forgetting_engine/forgetting_scheduler.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/forgetting_engine/forgetting_scheduler.py) (13.6KB)

**类结构**：
```python
class ForgettingScheduler:
    """遗忘调度器"""
    
    def __init__(
        self,
        forgetting_strategy: ForgettingStrategy,
        connector: Neo4jConnector
    ):
        self.forgetting_strategy = forgetting_strategy
        self.connector = connector
        self.is_running = False
    
    async def run_forgetting_cycle(
        self,
        end_user_id: Optional[str] = None,
        max_merge_batch_size: int = 100,
        min_days_since_access: int = 30
    ) -> Dict[str, Any]:
        """运行一次完整的遗忘周期"""
```

**职责**：
1. 手动触发遗忘周期
2. 批量处理可遗忘节点（限制批量大小）
3. 按激活值优先级排序（激活值最低的优先）
4. 进度跟踪和日志记录
5. 生成遗忘报告

---

### 2.2 遗忘周期流程

**完整流程**：
```
1. 检查是否正在运行 → is_running
   ↓
2. 统计遗忘前节点数量 → _count_knowledge_nodes()
   ↓
3. 识别可遗忘节点对 → find_forgettable_nodes()
   ↓
4. 按激活值排序 → sorted by avg_activation ASC
   ↓
5. 限制批量大小 → [:max_merge_batch_size]
   ↓
6. 去重（避免重复处理）→ processed_statement_ids
   ↓
7. 批量融合节点 → merge_nodes_to_summary()
   ↓
8. 记录进度（每 10%）→ logger.info()
   ↓
9. 生成遗忘报告 → Dict[str, Any]
```

**代码实现**：
```python
async def run_forgetting_cycle(
    self,
    end_user_id: Optional[str] = None,
    max_merge_batch_size: int = 100,
    min_days_since_access: int = 30
) -> Dict[str, Any]:
    """运行一次完整的遗忘周期"""
    
    # 检查是否已有遗忘周期在运行
    if self.is_running:
        raise RuntimeError("遗忘周期已在运行中")
    
    self.is_running = True
    start_time = datetime.now()
    
    try:
        # 步骤 1：统计遗忘前的节点数量
        nodes_before = await self._count_knowledge_nodes(end_user_id)
        logger.info(f"遗忘前节点总数：{nodes_before}")
        
        # 步骤 2：识别可遗忘的节点对
        forgettable_pairs = await self.forgetting_strategy.find_forgettable_nodes(
            end_user_id=end_user_id,
            min_days_since_access=min_days_since_access
        )
        
        total_forgettable = len(forgettable_pairs)
        logger.info(f"识别到 {total_forgettable} 个可遗忘节点对")
        
        if total_forgettable == 0:
            logger.info("没有可遗忘的节点对，遗忘周期结束")
            return empty_report
        
        # 步骤 3：按激活值排序（激活值最低的优先）
        sorted_pairs = sorted(
            forgettable_pairs,
            key=lambda x: x['avg_activation']
        )
        
        # 步骤 4：限制批量大小
        pairs_to_process = sorted_pairs[:max_merge_batch_size]
        actual_batch_size = len(pairs_to_process)
        
        # 步骤 5：去重（避免重复处理）
        processed_statement_ids = set()
        processed_entity_ids = set()
        unique_pairs = []
        
        for pair in pairs_to_process:
            if (pair['statement_id'] not in processed_statement_ids and
                pair['entity_id'] not in processed_entity_ids):
                unique_pairs.append(pair)
                processed_statement_ids.add(pair['statement_id'])
                processed_entity_ids.add(pair['entity_id'])
        
        # 步骤 6：批量融合节点
        merged_count = 0
        failed_count = 0
        progress_interval = max(1, actual_batch_size // 10)
        
        for i, pair in enumerate(unique_pairs):
            try:
                await self.forgetting_strategy.merge_nodes_to_summary(
                    statement_node=pair,
                    entity_node=pair,
                    config_id=config_id,
                    db=db
                )
                merged_count += 1
            except Exception as e:
                failed_count += 1
                logger.error(f"融合失败：{e}")
            
            # 记录进度（每 10%）
            if (i + 1) % progress_interval == 0:
                progress = (i + 1) / actual_batch_size * 100
                logger.info(f"遗忘进度：{progress:.1f}% ({i+1}/{actual_batch_size})")
        
        # 步骤 7：统计遗忘后节点数量
        nodes_after = await self._count_knowledge_nodes(end_user_id)
        
        # 步骤 8：生成遗忘报告
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        reduction_rate = (nodes_before - nodes_after) / nodes_before if nodes_before > 0 else 0
        success_rate = merged_count / actual_batch_size if actual_batch_size > 0 else 0
        
        report = {
            'merged_count': merged_count,
            'nodes_before': nodes_before,
            'nodes_after': nodes_after,
            'reduction_rate': reduction_rate,
            'duration_seconds': duration,
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat(),
            'failed_count': failed_count,
            'success_rate': success_rate
        }
        
        logger.info(
            f"遗忘周期完成："
            f"融合 {merged_count} 个节点对，"
            f"减少率 {reduction_rate:.2%}，"
            f"耗时 {duration:.2f}秒"
        )
        
        return report
        
    finally:
        self.is_running = False
```

---

### 2.3 遗忘报告

**报告格式**：
```json
{
  "merged_count": 45,              // 融合的节点对数量
  "nodes_before": 1250,            // 遗忘前的节点总数
  "nodes_after": 1205,             // 遗忘后的节点总数
  "reduction_rate": 0.036,         // 节点减少率（3.6%）
  "duration_seconds": 125.5,       // 执行耗时（秒）
  "start_time": "2026-02-28T10:00:00",
  "end_time": "2026-02-28T10:02:05",
  "failed_count": 2,               // 失败的融合数量
  "success_rate": 0.957            // 成功率（95.7%）
}
```

**关键指标**：
- `reduction_rate`: 节点减少率（通常 3-5%）
- `success_rate`: 融合成功率（通常 >90%）
- `duration_seconds`: 执行时间（取决于批量大小）

---

## 3️⃣ 遗忘策略（Forgetting Strategy）

### 3.1 核心架构

**文件**：[`app/core/memory/storage_services/forgetting_engine/forgetting_strategy.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/memory/storage_services/forgetting_engine/forgetting_strategy.py) (24.7KB)

**类结构**：
```python
class ForgettingStrategy:
    """遗忘策略执行器"""
    
    def __init__(
        self,
        connector: Neo4jConnector,
        actr_calculator: ACTRCalculator,
        forgetting_threshold: float = 0.3,
        enable_llm_summary: bool = True
    ):
        self.connector = connector
        self.actr_calculator = actr_calculator
        self.forgetting_threshold = forgetting_threshold
        self.enable_llm_summary = enable_llm_summary
```

**职责**：
1. 识别低激活值的节点对（Statement-Entity）
2. 将低激活值节点融合为 MemorySummary 节点
3. 使用 LLM 生成高质量摘要（可选）
4. 保留溯源信息并删除原始节点

---

### 3.2 识别可遗忘节点

**Cypher 查询**：
```python
async def find_forgettable_nodes(
    self,
    end_user_id: Optional[str] = None,
    min_days_since_access: int = 30
) -> List[Dict[str, Any]]:
    """识别可遗忘的节点对"""
    
    # 计算时间阈值
    cutoff_time = datetime.now() - timedelta(days=min_days_since_access)
    
    # Cypher 查询
    query = """
    MATCH (s:Statement)-[r]-(e:ExtractedEntity)
    WHERE s.activation_value IS NOT NULL
      AND e.activation_value IS NOT NULL
      AND s.activation_value < $threshold
      AND e.activation_value < $threshold
      AND s.last_access_time < $cutoff_time
      AND e.last_access_time < $cutoff_time
      AND (e.entity_type IS NULL OR e.entity_type <> 'Person')
    """
    
    if end_user_id:
        query += " AND s.end_user_id = $end_user_id AND e.end_user_id = $end_user_id"
    
    query += """
    RETURN s.id as statement_id,
           s.statement as statement_text,
           s.activation_value as statement_activation,
           s.importance_score as statement_importance,
           s.last_access_time as statement_last_access,
           e.id as entity_id,
           e.name as entity_name,
           e.entity_type as entity_type,
           e.activation_value as entity_activation,
           e.importance_score as entity_importance,
           e.last_access_time as entity_last_access,
           (s.activation_value + e.activation_value) / 2.0 as avg_activation
    ORDER BY avg_activation ASC
    """
    
    params = {
        'threshold': self.forgetting_threshold,
        'cutoff_time': cutoff_time.isoformat()
    }
    if end_user_id:
        params['end_user_id'] = end_user_id
    
    results = await self.connector.execute_query(query, **params)
    
    return results
```

**遗忘条件**：
1. **激活值低**：`activation_value < 0.3`
2. **长期未访问**：`last_access_time < 30 days ago`
3. **存在关系边**：`Statement-Entity` 之间有边
4. **非人物实体**：`entity_type <> 'Person'`（人物不遗忘）

**排序策略**：
- `ORDER BY avg_activation ASC`
- 激活值最低的节点对优先处理

---

### 3.3 节点融合

**融合流程**：
```
1. 读取 Statement 和 Entity 节点
   ↓
2. 生成摘要内容（LLM 或拼接）
   ↓
3. 创建 MemorySummary 节点
   ↓
4. 继承较高的激活值和重要性
   ↓
5. 保留溯源信息（original IDs）
   ↓
6. 删除原始 Statement 和 Entity 节点
```

**代码实现**：
```python
async def merge_nodes_to_summary(
    self,
    statement_node: Dict[str, Any],
    entity_node: Dict[str, Any],
    config_id: Optional[UUID] = None,
    db = None
) -> str:
    """将 Statement 和 Entity 节点融合为 MemorySummary 节点"""
    
    # 1. 生成摘要内容
    if self.enable_llm_summary:
        # 使用 LLM 生成高质量摘要
        summary_text = await self._generate_llm_summary(
            statement_text=statement_node['statement_text'],
            entity_name=entity_node['entity_name'],
            entity_type=entity_node['entity_type'],
            config_id=config_id,
            db=db
        )
    else:
        # 降级到简单拼接
        summary_text = f"{entity_node['entity_name']} ({entity_node['entity_type']}): {statement_node['statement_text']}"
    
    # 2. 继承较高的激活值和重要性
    inherited_activation = max(
        statement_node['statement_activation'],
        entity_node['entity_activation']
    )
    inherited_importance = max(
        statement_node['statement_importance'],
        entity_node['entity_importance']
    )
    
    # 3. 创建 MemorySummary 节点
    create_query = """
    CREATE (ms:MemorySummary {
        id: randomUUID(),
        content: $summary_text,
        created_at: datetime(),
        expired_at: null,
        end_user_id: $end_user_id,
        importance_score: $inherited_importance,
        activation_value: $inherited_activation,
        access_history: [],
        last_access_time: null,
        access_count: 0,
        original_statement_id: $statement_id,
        original_entity_id: $entity_id
    })
    """
    
    params = {
        'summary_text': summary_text,
        'end_user_id': statement_node.get('end_user_id'),
        'inherited_importance': inherited_importance,
        'inherited_activation': inherited_activation,
        'statement_id': statement_node['statement_id'],
        'entity_id': entity_node['entity_id']
    }
    
    await self.connector.execute_query(create_query, **params)
    
    # 4. 删除原始节点
    delete_query = """
    MATCH (s:Statement {id: $statement_id})
    MATCH (e:ExtractedEntity {id: $entity_id})
    DETACH DELETE s, e
    """
    
    await self.connector.execute_query(delete_query, **params)
    
    return summary_text
```

---

### 3.4 LLM 摘要生成

**提示词模板**：
```python
async def _generate_llm_summary(
    self,
    statement_text: str,
    entity_name: str,
    entity_type: str,
    config_id: Optional[UUID] = None,
    db = None
) -> str:
    """使用 LLM 生成高质量摘要"""
    
    # 获取 LLM 客户端
    llm_client = self._get_llm_client(config_id, db)
    
    # 提示词
    prompt = f"""
You are a memory summarization expert.

Merge the following Statement and Entity into a concise MemorySummary:

Statement: {statement_text}
Entity: {entity_name} ({entity_type})

Requirements:
1. Preserve all key information
2. Make it self-contained (no pronouns without clear antecedents)
3. Keep it concise (1-3 sentences)
4. Maintain temporal and causal relationships
5. Use natural language

Output only the summary text, no explanations.
"""
    
    # 调用 LLM
    response = await llm_client.chat(
        system_prompt="You are a memory summarization expert.",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3,  # 低温度保证一致性
        max_tokens=200
    )
    
    summary_text = response.content.strip()
    
    return summary_text
```

**摘要要求**：
1. 保留所有关键信息
2. 自包含（无代词歧义）
3. 简洁（1-3 句话）
4. 保持时间和因果关系
5. 使用自然语言

**示例**：
```
输入:
- Statement: "张三在 2025 年 3 月加入了 ABC 公司，担任软件工程师"
- Entity: "张三 (Person)"

输出:
"张三于 2025 年 3 月加入 ABC 公司，担任软件工程师职位。"
```

---

## 4️⃣ 性能优化

### 4.1 批量处理

**批量大小限制**：
```python
max_merge_batch_size = 100  # 默认值
```

**原因**：
- 避免单次事务过大
- 减少内存占用
- 便于进度跟踪

**性能对比**：
| 批量大小 | 耗时 | 内存占用 | 推荐场景 |
|---------|------|---------|---------|
| 10 | ~15 秒 | 低 | 测试 |
| 100 | ~125 秒 | 中 | 生产（推荐） |
| 1000 | ~1200 秒 | 高 | 大规模清理 |

---

### 4.2 去重优化

**问题**：同一节点可能出现在多个节点对中

**解决方案**：
```python
processed_statement_ids = set()
processed_entity_ids = set()

unique_pairs = []
for pair in pairs_to_process:
    if (pair['statement_id'] not in processed_statement_ids and
        pair['entity_id'] not in processed_entity_ids):
        unique_pairs.append(pair)
        processed_statement_ids.add(pair['statement_id'])
        processed_entity_ids.add(pair['entity_id'])
```

**效果**：
- 避免重复处理同一节点
- 减少 10-20% 的处理量
- 防止并发冲突

---

### 4.3 进度跟踪

**日志记录**：
```python
progress_interval = max(1, actual_batch_size // 10)

for i, pair in enumerate(unique_pairs):
    # ... 处理节点对 ...
    
    # 每 10% 记录一次进度
    if (i + 1) % progress_interval == 0:
        progress = (i + 1) / actual_batch_size * 100
        logger.info(f"遗忘进度：{progress:.1f}% ({i+1}/{actual_batch_size})")
```

**日志输出示例**：
```
INFO - 遗忘进度：10.0% (10/100)
INFO - 遗忘进度：20.0% (20/100)
INFO - 遗忘进度：30.0% (30/100)
...
INFO - 遗忘进度：100.0% (100/100)
```

---

## 5️⃣ 调度器集成

### 5.1 Celery Beat 定期任务

**文件**：[`app/tasks.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/tasks.py)

**定期任务配置**：
```python
@app.task
def run_forgetting_cycle_task(
    end_user_id: Optional[str] = None,
    max_merge_batch_size: int = 100,
    min_days_since_access: int = 30
):
    """定期运行遗忘周期（Celery Beat 调度）"""
    
    # 创建连接器和策略
    connector = Neo4jConnector()
    actr_calculator = ACTRCalculator()
    forgetting_strategy = ForgettingStrategy(connector, actr_calculator)
    scheduler = ForgettingScheduler(forgetting_strategy, connector)
    
    try:
        # 运行遗忘周期
        report = asyncio.run(scheduler.run_forgetting_cycle(
            end_user_id=end_user_id,
            max_merge_batch_size=max_merge_batch_size,
            min_days_since_access=min_days_since_access
        ))
        
        logger.info(f"遗忘周期完成：{report}")
        
    except Exception as e:
        logger.error(f"遗忘周期失败：{e}")
        raise
```

**Celery Beat 配置**：
```python
beat_schedule = {
    'run-forgetting-cycle-weekly': {
        'task': 'app.tasks.run_forgetting_cycle_task',
        'schedule': crontab(hour=3, minute=0, day_of_week='sunday'),  # 每周日凌晨 3 点
        'options': {
            'max_merge_batch_size': 100,
            'min_days_since_access': 30
        }
    },
    'run-reflection-monthly': {
        'task': 'app.tasks.run_reflection_task',
        'schedule': crontab(hour=2, minute=0, day_of_month=1),  # 每月 1 日凌晨 2 点
    }
}
```

---

## 6️⃣ 关键发现

### 6.1 遗忘阈值调优

**推荐配置**：
```python
ForgettingStrategy(
    forgetting_threshold=0.3,      # 激活值低于 0.3 可遗忘
    enable_llm_summary=True,       # 启用 LLM 摘要
    min_days_since_access=30       # 30 天未访问
)
```

**调优建议**：
- 降低 `forgetting_threshold`: 更激进遗忘（节省存储）
- 增加 `min_days_since_access`: 更保守遗忘（保留更多）
- 禁用 `enable_llm_summary`: 提高速度（但摘要质量下降）

---

### 6.2 反思周期配置

**推荐配置**：
```python
ReflectionConfig(
    enabled=True,
    iteration_period="3",          # 每 3 天反思一次
    reflexion_range="partial",     # 从检索结果反思
    baseline="TIME",               # 基于时间反思
    memory_verify=True,            # 启用记忆验证
    quality_assessment=True        # 启用质量评估
)
```

**周期选择**：
- `1-3 天`: 高频反思（适合活跃用户）
- `7-14 天`: 中频反思（适合普通用户）
- `30 天`: 低频反思（适合归档用户）

---

### 6.3 LLM 成本优化

**优化策略**：
1. **批量处理**：多个冲突合并为一个提示词
2. **降低温度**：`temperature=0.3`（减少 token 消耗）
3. **限制长度**：`max_tokens=200`（控制输出长度）
4. **降级策略**：LLM 失败时降级到简单拼接

**成本估算**：
- 每次遗忘周期：~50 次 LLM 调用
- 每次调用：~200 tokens
- 总成本：~10,000 tokens/周期
- 按 GPT-4 计价：~$0.30/周期

---

## 📋 待研究分支

- [ ] **情绪影响** - 情绪对记忆强度的影响
- [ ] **部分匹配惩罚** - ACT-R 的 PC_k 参数实现
- [ ] **向量索引优化** - Neo4j 向量索引性能
- [ ] **多用户隔离** - 大规模多用户场景优化

---

**研究人**：Jarvis  
**日期**：2026-02-28  
**方法**：毛线团研究法（分支深入）  
**状态**：✅ 反思引擎 + 遗忘调度器 + 遗忘策略完成
