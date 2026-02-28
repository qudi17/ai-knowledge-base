# RAG + Agent 融合架构文档

> 版本：2.0  
> 日期：2026-02-23  
> 作者：Eddy  
> 更新：融入 Agent 通用能力框架

---

## 目录

1. [架构概述](#架构概述)
2. [核心融合点](#核心融合点)
3. [完整架构图](#完整架构图)
4. [阶段1：数据生成与记忆管理](#阶段1数据生成与记忆管理)
5. [阶段2：智能检索与规划](#阶段2智能检索与规划)
6. [阶段3：工具调用与行动](#阶段3工具调用与行动)
7. [阶段4：评估与优化](#阶段4评估与优化)
8. [技术栈](#技术栈)
9. [部署建议](#部署建议)

---

## 架构概述

### 融合理念

**纯 RAG 的局限性**：
- ❌ 静态检索，无法处理复杂任务
- ❌ 无对话上下文管理
- ❌ 无法调用外部工具
- ❌ 缺乏自我反思与优化能力

**RAG + Agent 的优势**：
- ✅ **Planning**：任务拆解、流程编排、自我反思
- ✅ **Memory**：短期记忆（对话历史）+ 长期记忆（向量库）
- ✅ **Tool Use**：联网搜索、API调用、代码执行
- ✅ **Agent Core**：基于 LLM 的决策大脑

### 架构对比

| 维度 | 纯 RAG 系统 | RAG + Agent 系统 |
|------|-------------|-----------------|
| **决策能力** | 静态检索流程 | 动态规划与推理 |
| **任务处理** | 单一问题 | 复杂任务分解 |
| **知识管理** | 静态文档库 | 持续学习与压缩 |
| **工具使用** | 无 | 搜索、API、代码 |
| **适应性** | 固定流程 | 灵活自适应 |
| **多轮对话** | 无状态 | 上下文管理 |
| **复杂查询** | 直接检索 | 规划→检索→迭代 |

---

## 核心融合点

### 1. Planning（规划）→ 增强检索

**作用**：
- 任务拆解：复杂查询 → 子问题序列
- 流程编排：确定检索顺序
- 自我反思：检查结果，决定是否需要补充检索

**融合场景**：
```python
# 复杂查询示例
query = "分析2024年Q1季度各行业销售额，找出增长最快的三个行业，并生成可视化图表"

# 纯 RAG：直接检索（可能失败）
results = retriever.retrieve(query)

# RAG + Agent：规划后检索
plan = planning_module.decompose(query)
# plan = [
#     "2024年Q1各行业销售额数据",
#     "各行业增长率分析",
#     "可视化图表生成需求"
# ]

# 依次检索
results = []
for sub_query in plan:
    results.extend(retriever.retrieve(sub_query))
```

---

### 2. Memory（记忆）→ 对话状态管理

**作用**：
- **短期记忆**：当前对话上下文
- **长期记忆**：向量库存储（RAG）
- **记忆压缩**：历史摘要，保留关键信息

**融合场景**：
```python
class AgentRAGMemory:
    """Agent RAG 记忆系统"""
    
    def __init__(self):
        self.short_term = []  # 对话历史
        self.long_term = []   # 长期知识库
        self.vector_db = VectorStore()  # 向量检索
        self.summarizer = LLMSummarizer()

    def add_conversation(self, role, content):
        """添加对话到短期记忆"""
        self.short_term.append({"role": role, "content": content})
        
        # 限制短期记忆大小
        if len(self.short_term) > 20:
            self.short_term = self.short_term[-20:]

    def retrieve_from_memory(self, query, top_k=5):
        """从记忆中检索相关信息"""
        return self.vector_db.search(query, top_k)

    def compress_history(self):
        """压缩对话历史，提取关键信息到长期记忆"""
        # 聚合历史对话
        conversation_history = self.get_conversation_history()
        
        # 生成摘要
        summary = self.summarizer.summarize(conversation_history)
        
        # 存入长期记忆
        self.vector_db.add(summary)
        
        return summary

    def get_context(self, query, max_history=5):
        """获取检索上下文"""
        # 1. 从短期记忆获取最近的对话
        recent_conversation = self.short_term[-max_history:]
        
        # 2. 从长期记忆检索相关文档
        retrieved_docs = self.retrieve_from_memory(query, top_k=3)
        
        # 3. 组合上下文
        context = {
            "conversation": recent_conversation,
            "documents": retrieved_docs
        }
        
        return context
```

---

### 3. Tool Use（工具）→ 增强能力

**作用**：
- 联网搜索：获取最新信息
- API 调用：查询数据库
- 代码执行：数据分析、图表生成

**融合场景**：
```python
class RAGWithTools:
    """支持工具调用的 RAG 系统"""
    
    def __init__(self):
        self.retriever = BaseRetriever()
        self.search_tool = SearchTool()
        self.api_tool = APITool()
        self.chart_tool = ChartGenerator()
        self.code_executor = CodeExecutor()

    def retrieve_with_tools(self, query, max_iterations=2):
        """支持工具调用的智能检索"""
        results = self.retriever.retrieve(query)
        
        for iteration in range(max_iterations):
            # 检查结果完整性
            completeness = self.check_completeness(results, query)
            
            if not completeness["satisfied"]:
                # 决定使用哪个工具
                tools_to_use = self.plan_tools(
                    completeness["gaps"],
                    query
                )
                
                # 执行工具
                for tool in tools_to_use:
                    if tool == "search":
                        new_data = self.search_tool.search(
                            completeness["gaps"]
                        )
                    elif tool == "api":
                        new_data = self.api_tool.query(
                            completeness["gaps"]
                        )
                    
                    results.extend(new_data)
            
            # 自我反思：是否需要继续
            should_continue = self.agent_core.decide(
                query,
                results,
                need_more_info=True
            )
            
            if not should_continue:
                break
        
        return results

    def check_completeness(self, results, query):
        """检查检索结果是否完整"""
        prompt = f"""
        检查以下检索结果是否完整回答了用户问题：

        用户问题：{query}

        检索结果：{results}

        返回JSON格式：
        {{
            "satisfied": true/false,
            "gaps": ["缺失信息1", "缺失信息2", ...],
            "confidence": 0.0-1.0
        }}
        """
        response = self.agent_core.generate(prompt)
        return json.loads(response)

    def plan_tools(self, gaps, query):
        """规划需要使用的工具"""
        prompt = f"""
        用户问题：{query}

        缺失信息：{gaps}

        可用工具：search（联网搜索）、api（API调用）、chart（图表生成）、code（代码执行）

        选择最合适的工具组合返回JSON：
        {{
            "tools": ["search", "api", ...],
            "reason": "选择理由"
        }}
        """
        response = self.agent_core.generate(prompt)
        return json.loads(response)
```

---

### 4. Agent Core → 决策大脑

**作用**：
- 角色设定：定义 Agent 的行为风格
- 逻辑推理：决策检索策略、工具选择
- 多轮对话管理：上下文维护

**融合场景**：
```python
class AgentRAGCore:
    """Agent RAG 核心决策大脑"""
    
    def __init__(self, model, profile):
        self.model = model
        self.profile = profile  # 角色设定
    
    def decide_retrieval_strategy(self, query, context):
        """决定检索策略"""
        prompt = f"""
        角色设定：{self.profile}

        用户问题：{query}

        当前上下文：{context}

        分析问题类型并决定检索策略：

        问题类型：
        - single_query：单一查询，直接检索
        - multi_step：多步骤查询，需要规划
        - needs_search：需要联网搜索
        - needs_computation：需要计算/代码执行

        返回JSON：
        {{
            "strategy": "single_query|multi_step|needs_search|needs_computation",
            "sub_queries": ["query1", "query2", ...],
            "confidence": 0.0-1.0,
            "reason": "分析理由"
        }}
        """
        response = self.model.generate(prompt)
        return json.loads(response)

    def generate_answer(self, query, context):
        """生成最终答案"""
        prompt = f"""
        角色设定：{self.profile}

        用户问题：{query}

        参考文档：{context}

        请根据文档内容回答问题，如果信息不足，说明需要更多信息。

        返回格式：
        {{
            "answer": "答案内容",
            "confidence": 0.0-1.0,
            "sources": ["doc1", "doc2"],
            "needs_more_info": true/false
        }}
        """
        response = self.model.generate(prompt)
        return json.loads(response)

    def reflect_on_results(self, query, results):
        """反思检索结果"""
        prompt = f"""
        用户问题：{query}

        检索结果：{results}

        反思：
        1. 检索结果是否充分？
        2. 是否需要重新检索？
        3. 是否需要补充信息？

        返回JSON：
        {{
            "needs_reretrieval": true/false,
            "improvements": ["建议1", "建议2"],
            "should_rerun": true/false
        }}
        """
        response = self.model.generate(prompt)
        return json.loads(response)
```

---

## 完整架构图

### 系统架构总览

```
┌─────────────────────────────────────────────────────────────┐
│              RAG + Agent 融合系统架构                         │
│                  (增强型智能问答系统)                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Agent Core（核心决策大脑）                 │
│                  基于LLM的推理引擎                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ 角色设定     │  │ 逻辑推理    │  │ 决策引擎    │         │
│  │ Profile     │  │ Reasoning   │  │ Decision    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                            ↓
        ┌───────────────────┼───────────────────┐
        ↓                   ↓                   ↓
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Planning     │    │   Memory     │    │  Tool Use    │
│  (规划)      │    │   (记忆)     │    │   (工具)     │
├──────────────┤    ├──────────────┤    ├──────────────┤
│ 任务拆解     │    │ 短期记忆     │    │ 联网搜索     │
│ 自我反思     │    │ 对话上下文   │    │ API调用      │
│ 流程编排     │    │ 历史摘要     │    │ 代码执行     │
│ 策略规划     │    │ 记忆压缩     │    │ 图表生成     │
└──────────────┘    │ 向量检索     │    │ 数据库查询   │
                   └──────────────┘    └──────────────┘
                           ↓
                ┌─────────────────┐
                │    RAG 核心     │
                └─────────────────┘
                           ↓
        ┌───────────────────┼───────────────────┐
        ↓                   ↓                   ↓
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ 数据生成     │    │  智能检索    │    │   结果评估   │
│ (Offline)    │    │ (Online)     │    │ (Offline)    │
├──────────────┤    ├──────────────┤    ├──────────────┤
│ 文档加载     │    │ 问题处理     │    │ 召回率       │
│ 分块策略     │    │ 多策略检索   │    │ 精确率       │
│ 元数据管理   │    │ 特征工程     │    │ F1分数       │
│ 向量索引     │    │ 重排机制     │    │ 幻觉检测     │
│ BM25索引     │    │ Agent融合    │    │ 首轮解决率   │
│ 缓存管理     │    │ 工具增强     │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
```

### 数据流图

```
用户查询
    ↓
┌─────────────────────┐
│  Agent Core         │
│  - 分析问题类型     │
│  - 决策检索策略     │
└─────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Planning                           │
│  - 任务拆解（如需要）                │
│  - 规划子问题序列                    │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Memory Retrieval                   │
│  - 从短期记忆获取上下文              │
│  - 从长期记忆（RAG）检索相关文档     │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Intelligent Retrieval               │
│  - 多策略检索（向量 + BM25）         │
│  - 特征工程                          │
│  - 重排机制                          │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Tool Use Decision                   │
│  - 检查结果完整性                    │
│  - 规划需要的工具                    │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Tool Execution                     │
│  - 执行工具（搜索/API/代码等）       │
│  - 获取补充信息                      │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Self-Reflection & Rerun             │
│  - 自我反思结果                      │
│  - 决定是否需要重新检索              │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Context Assembly                    │
│  - 组合检索结果 + 工具结果           │
│  - 生成最终上下文                    │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Answer Generation                   │
│  - Agent Core 生成答案               │
│  - 生成置信度和引用来源              │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Memory Update                       │
│  - 添加到短期记忆                    │
│  - 提取关键信息到长期记忆            │
└─────────────────────────────────────┘
    ↓
输出：答案 + 来源 + 置信度
```

---

## 阶段1：数据生成与记忆管理

### 1.1 数据生成（RAG 部分）

#### 文档加载

```python
class DocumentLoader:
    """文档加载器"""
    
    def load(self, file_path):
        """加载文档"""
        if file_path.endswith('.pdf'):
            return self._load_pdf(file_path)
        elif file_path.endswith('.txt') or file_path.endswith('.md'):
            return self._load_text(file_path)
        elif file_path.endswith('.html'):
            return self._load_html(file_path)
        else:
            raise ValueError(f"Unsupported file type: {file_path}")

    def load_from_api(self, api_url, params):
        """从API加载数据"""
        response = requests.get(api_url, params=params)
        return response.json()
```

#### 分块策略

```python
class SmartChunker:
    """智能分块器"""
    
    def __init__(self, strategy="semantic"):
        self.strategy = strategy
        self.nlp = spacy.load("en_core_web_sm")

    def chunk(self, text, config):
        """分块"""
        if self.strategy == "semantic":
            return self._semantic_chunk(text, config)
        elif self.strategy == "element":
            return self._element_chunk(text, config)
        else:
            return self._fixed_chunk(text, config)

    def _semantic_chunk(self, text, config):
        """语义分块"""
        doc = self.nlp(text)
        chunks = []
        current_chunk = []
        sentence_count = 0

        for sent in doc.sents:
            current_chunk.append(sent.text)
            sentence_count += 1

            if sentence_count >= config.get("max_sentences", 10):
                chunks.append(" ".join(current_chunk))
                current_chunk = []
                sentence_count = 0

        return chunks

    def _element_chunk(self, text, config):
        """元素级分块"""
        # 按标题、表格、列表等结构分块
        # 实现略
        pass
```

#### 向量与BM25索引

```python
class MemoryIndex:
    """记忆索引（RAG + 长期记忆）"""
    
    def __init__(self, model_name="BAAI/bge-small-en-v1.5"):
        self.vector_model = SentenceTransformer(model_name)
        self.vector_index = None
        self.bm25_index = None
        self.chunks = []
        self.metadata = []

    def build_index(self, chunks):
        """构建索引"""
        # 向量索引
        embeddings = self.vector_model.encode(
            [c["content"] for c in chunks]
        )
        dimension = embeddings.shape[1]
        self.vector_index = faiss.IndexFlatIP(dimension)
        self.vector_index.add(embeddings)

        # BM25索引
        from rank_bm25 import BM25Okapi
        tokenized_docs = [
            [word.lower() for word in c["content"].split()]
            for c in chunks
        ]
        self.bm25_index = BM25Okapi(tokenized_docs)

        self.chunks = chunks
        self.metadata = chunks

    def search(self, query, top_k=10):
        """检索"""
        # 向量检索
        query_emb = self.vector_model.encode([query])
        scores, indices = self.vector_index.search(query_emb, top_k)

        # BM25检索
        tokenized_query = query.lower().split()
        bm25_scores = self.bm25_index.get_scores(tokenized_query)

        # 合并结果
        results = []
        for i in indices[0]:
            results.append({
                "chunk": self.chunks[i],
                "score": float(scores[0][i]),
                "bm25_score": float(bm25_scores[i])
            })

        return results
```

### 1.2 记忆管理

```python
class MemoryManager:
    """记忆管理器（RAG + 短期记忆）"""
    
    def __init__(self, max_short_term=20):
        self.short_term = []  # 短期记忆：对话历史
        self.max_short_term = max_short_term
        self.summarizer = LLMSummarizer()

    def add(self, role, content):
        """添加到短期记忆"""
        self.short_term.append({
            "role": role,
            "content": content,
            "timestamp": datetime.now()
        })

        # 限制大小
        if len(self.short_term) > self.max_short_term:
            self.short_term = self.short_term[-self.max_short_term:]

    def get_recent(self, count=5):
        """获取最近的对话"""
        return self.short_term[-count:]

    def summarize(self):
        """总结历史对话"""
        if len(self.short_term) < 5:
            return None

        history = "\n".join([
            f"{msg['role']}: {msg['content']}"
            for msg in self.short_term
        ])

        prompt = f"""
        总结以下对话历史，提取关键信息：

        {history}

        总结格式：
        {{
            "key_topics": ["topic1", "topic2", ...],
            "important_entities": ["entity1", "entity2", ...],
            "summary": "简短总结"
        }}
        """
        summary = self.summarizer.summarize(prompt)
        return summary

    def compress_to_long_term(self, memory_manager):
        """压缩到长期记忆"""
        summary = self.summarize()
        if summary:
            memory_manager.add_to_long_term(summary)
```

---

## 阶段2：智能检索与规划

### 2.1 问题处理

```python
class QueryProcessor:
    """查询处理器（集成 Agent 规划）"""
    
    def __init__(self, agent_core, memory_manager):
        self.agent_core = agent_core
        self.memory_manager = memory_manager

    def process(self, query):
        """处理查询（集成规划、记忆、检索）"""
        # 1. 分析问题类型
        analysis = self.agent_core.decide_retrieval_strategy(
            query,
            self.memory_manager.get_recent()
        )

        # 2. 如果是多步骤查询，进行任务拆解
        if analysis["strategy"] == "multi_step":
            sub_queries = analysis["sub_queries"]
            results = []

            for sub_query in sub_queries:
                # 从记忆检索
                memory_results = self.memory_manager.retrieve_from_memory(
                    sub_query
                )

                # 从索引检索
                index_results = self.retriever.retrieve(sub_query)

                # 合并结果
                results.extend(memory_results)
                results.extend(index_results)

            return self._merge_results(results)

        # 3. 单一查询，直接检索
        else:
            # 从记忆获取上下文
            context = self.memory_manager.get_context(query)

            # 从索引检索
            results = self.retriever.retrieve(query)

            # 反思结果
            reflection = self.agent_core.reflect_on_results(
                query,
                results
            )

            # 如果需要，补充检索
            if reflection.get("needs_reretrieval"):
                additional_results = self.retriever.retrieve(
                    reflection["improvements"]
                )
                results.extend(additional_results)

            return self._merge_results(results)

    def _merge_results(self, results):
        """合并并去重结果"""
        # 实现去重逻辑
        pass
```

### 2.2 智能检索

```python
class IntelligentRetriever:
    """智能检索器（多策略 + 重排）"""
    
    def __init__(self, vector_index, bm25_index, agent_core):
        self.vector_index = vector_index
        self.bm25_index = bm25_index
        self.agent_core = agent_core

    def retrieve(self, query, top_k=10):
        """智能检索"""
        # 1. 多策略检索
        vector_results = self.vector_index.search(query, top_k=100)
        bm25_results = self.bm25_index.search(query, top_k=100)

        # 2. 合并去重
        merged = self._merge(vector_results, bm25_results)

        # 3. 特征工程
        results_with_features = self._add_features(
            merged,
            query
        )

        # 4. 重排（简单 + Agent 增强重排）
        results_with_scores = self._fuse_scores(
            results_with_features
        )

        # 5. Agent 增强重排
        final_results = self._agent_rerank(
            results_with_scores,
            query
        )

        return final_results[:top_k]

    def _agent_rerank(self, results, query):
        """Agent 增强重排"""
        # 使用 Agent Core 进行相关性打分
        prompt = f"""
        用户问题：{query}

        待排序的文档片段：

        {results}

        请评估每个文档与问题的相关度，返回相关度分数（0-10）：
        """
        
        responses = self.agent_core.generate_batch(prompt, results)
        
        for i, response in enumerate(responses):
            results[i]["agent_score"] = self._parse_score(response)

        return sorted(
            results,
            key=lambda x: x.get("agent_score", 0),
            reverse=True
        )
```

---

## 阶段3：工具调用与行动

### 3.1 工具集

```python
class ToolUseManager:
    """工具使用管理器"""
    
    def __init__(self):
        self.tools = {
            "search": SearchTool(),
            "api": APITool(),
            "code": CodeExecutor(),
            "chart": ChartGenerator(),
            "db": DatabaseTool()
        }

    def execute(self, query, tool_name, params):
        """执行工具"""
        if tool_name not in self.tools:
            raise ValueError(f"Unknown tool: {tool_name}")

        return self.tools[tool_name].execute(params)

    def plan_tools(self, gaps, query):
        """规划需要的工具"""
        prompt = f"""
        用户问题：{query}

        缺失信息：{gaps}

        可用工具：
        1. search - 联网搜索最新信息
        2. api - 调用API获取数据
        3. code - 执行代码进行计算
        4. chart - 生成可视化图表
        5. db - 查询数据库

        选择最合适的工具返回JSON：
        {{
            "tools": ["tool1", "tool2"],
            "reason": "选择理由"
        }}
        """
        
        # 使用 Agent Core 规划
        response = self.agent_core.generate(prompt)
        return json.loads(response)
```

### 3.2 工具实现

```python
class SearchTool:
    """联网搜索工具"""
    
    def __init__(self, api_key):
        self.api_key = api_key
        self.search_engine = "google"  # 或 bing, duckduckgo

    def search(self, query, top_k=10):
        """执行搜索"""
        if self.search_engine == "google":
            results = self._google_search(query, top_k)
        elif self.search_engine == "bing":
            results = self._bing_search(query, top_k)
        else:
            results = self._duckduckgo_search(query, top_k)

        return results

    def _google_search(self, query, top_k):
        """Google搜索"""
        # 使用 Google Custom Search API
        pass

    def _bing_search(self, query, top_k):
        """Bing搜索"""
        # 使用 Bing Search API
        pass

    def _duckduckgo_search(self, query, top_k):
        """DuckDuckGo搜索（免费）"""
        # 使用 requests + BeautifulSoup
        pass


class CodeExecutor:
    """代码执行工具"""
    
    def __init__(self):
        self.timeout = 30  # 超时时间（秒）

    def execute(self, code):
        """执行代码"""
        try:
            result = exec(code, {}, {})
            return {"success": True, "result": result}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def execute_with_safety(self, code):
        """安全执行代码"""
        # 限制可用的库
        allowed_libs = ["math", "random", "statistics", "datetime"]

        # 检查是否有禁用的库
        for lib in allowed_libs:
            if f"import {lib}" in code:
                pass

        return self.execute(code)


class ChartGenerator:
    """图表生成工具"""
    
    def generate(self, data, chart_type="bar", output_format="png"):
        """生成图表"""
        import matplotlib.pyplot as plt
        import numpy as np

        plt.figure(figsize=(10, 6))

        if chart_type == "bar":
            plt.bar(data.keys(), data.values())
        elif chart_type == "line":
            plt.plot(list(data.keys()), list(data.values()))
        elif chart_type == "pie":
            plt.pie(data.values(), labels=data.keys())

        plt.savefig(f"chart.{output_format}")
        plt.close()

        return f"chart.{output_format}"
```

---

## 阶段4：评估与优化

### 4.1 评估框架

```python
class AgentRAGEvaluator:
    """RAG + Agent 评估器"""
    
    def __init__(self, retriever, generator, agent_core):
        self.retriever = retriever
        self.generator = generator
        self.agent_core = agent_core

    def evaluate(self, test_dataset):
        """评估系统"""
        results = []

        for query_item in test_dataset:
            query = query_item["query"]
            ground_truth = query_item["ground_truth"]

            # 1. 执行查询
            answer, sources = self._execute_query(query)

            # 2. 计算检索指标
            retrieved_docs = self.retriever.get_retrieved_docs()
            metrics = {
                "recall": self._calculate_recall(retrieved_docs, ground_truth),
                "precision": self._calculate_precision(retrieved_docs, ground_truth),
                "f1": self._calculate_f1(metrics["recall"], metrics["precision"]),
                "mrr": self._calculate_mrr(retrieved_docs, ground_truth),
                "ndcg": self._calculate_ndcg(retrieved_docs, ground_truth)
            }

            # 3. 评估答案质量
            metrics["hallucination"] = self._detect_hallucination(answer)
            metrics["answer_relevance"] = self._calculate_relevance(answer, ground_truth)

            # 4. 评估 Agent 决策质量
            metrics["planning_efficiency"] = self._evaluate_planning(query_item)
            metrics["tool_usage"] = self._evaluate_tool_usage(query_item)

            results.append({
                "query": query,
                "answer": answer,
                "sources": sources,
                "metrics": metrics
            })

        # 5. 聚合指标
        summary = self._aggregate_metrics(results)
        return {"detailed": results, "summary": summary}

    def _execute_query(self, query):
        """执行查询（集成 Agent 流程）"""
        # 完整的 Agent 流程
        pass

    def _detect_hallucination(self, answer):
        """检测幻觉"""
        pass
```

### 4.2 自我优化

```python
class SelfOptimizer:
    """自我优化器"""
    
    def __init__(self, retriever, agent_core):
        self.retriever = retriever
        self.agent_core = agent_core

    def optimize(self, query, results, answer):
        """优化检索和答案"""
        # 1. 分析不足
        analysis = self._analyze_issues(query, results, answer)

        # 2. 生成优化建议
        suggestions = self.agent_core.generate(
            f"""
            用户问题：{query}

            当前检索结果：
            {results}

            当前答案：
            {answer}

            问题分析：
            {analysis}

            生成优化建议（返回JSON）：
            {{
                "improve_retrieval": ["建议1", "建议2"],
                "improve_answer": "建议内容",
                "change_tools": ["添加工具1", "移除工具2"]
            }}
            """
        )

        # 3. 应用优化
        return self._apply_suggestions(suggestions)
```

---

## 技术栈

### 核心依赖

| 组件 | 技术 | 用途 |
|------|------|------|
| **Agent Core** | zai/glm-4.7 | 决策推理 |
| **LLM** | zai/glm-4.7 | 生成与总结 |
| **向量模型** | BAAI/bge-small-en-v1.5 | 文本嵌入 |
| **向量数据库** | FAISS / ChromaDB | 向量索引 |
| **BM25** | rank_bm25 | 稀疏检索 |
| **分词** | spaCy / jieba | 文本分块 |
| **记忆压缩** | LLM | 对话摘要 |
| **代码执行** | Python exec | 数据计算 |
| **图表生成** | matplotlib | 可视化 |
| **工具管理** | 自定义类 | 工具调用 |
| **评估框架** | LLM-as-Judge | 自动评估 |
| **缓存** | Redis / 本地文件 | 多级缓存 |

### 安装命令

```bash
# 核心依赖
pip install sentence-transformers faiss-cpu rank-bm25 spacy jieba

# 中文分词
pip install jieba

# 可选：GPU加速
pip install faiss-gpu

# 工具相关
pip install matplotlib requests

# 中文支持
python -m spacy download en_core_web_sm
python -m spacy download zh_core_web_sm
```

---

## 部署建议

### 开发环境

```python
config = {
    "agent": {
        "model": "zai/glm-4.7",
        "profile": "专业的技术问答助手",
        "max_turns": 5
    },
    "retrieval": {
        "vector_weight": 0.6,
        "bm25_weight": 0.3,
        "metadata_weight": 0.1
    },
    "memory": {
        "max_short_term": 20,
        "enable_compression": True
    },
    "tools": {
        "enabled": ["search", "code", "chart"],
        "max_iterations": 2
    },
    "evaluation": {
        "enabled": True,
        "report_interval": "daily"
    }
}
```

### 生产环境

```python
config = {
    "agent": {
        "model": "zai/glm-4.7-flash",  # 更快的模型
        "profile": "企业级技术问答助手",
        "max_turns": 3,
        "temperature": 0.3
    },
    "retrieval": {
        "vector_weight": 0.5,
        "bm25_weight": 0.3,
        "metadata_weight": 0.2,
        "top_k_for_rerank": 50
    },
    "memory": {
        "max_short_term": 10,
        "enable_compression": True,
        "long_term_cache": True
    },
    "tools": {
        "enabled": ["search", "api", "db"],
        "max_iterations": 2,
        "rate_limit": "10/min"
    },
    "cache": {
        "enabled": True,
        "redis_url": "redis://localhost:6379",
        "ttl": 3600
    },
    "evaluation": {
        "enabled": True,
        "report_interval": "daily",
        "thresholds": {
            "recall": 0.8,
            "hallucination": 0.1
        }
    },
    "monitoring": {
        "log_queries": True,
        "track_metrics": True
    }
}
```

### 系统架构

```
┌──────────────────────────────────────────────────────────┐
│                      应用层                              │
│  - Web API (FastAPI/Flask)                              │
│  - 命令行界面                                           │
│  - 移动端接口                                           │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│                   服务层                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│  │ 查询处理     │ │ 检索服务     │ │ 答案生成     │     │
│  │ Query       │ │ Retrieval   │ │ Generation   │     │
│  │ Service     │ │ Service     │ │ Service      │     │
│  └──────────────┘ └──────────────┘ └──────────────┘     │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│                   核心层                                 │
│  ┌──────────────────────────────────────────────┐       │
│  │              Agent Core                       │       │
│  │  - 决策引擎                                    │       │
│  │  - 角色设定                                    │       │
│  └──────────────────────────────────────────────┘       │
│                           ↓                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│  │ Planning     │ │   Memory     │ │  Tool Use    │     │
│  │ Service     │ │   Service    │ │   Service    │     │
│  └──────────────┘ └──────────────┘ └──────────────┘     │
└──────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│                   数据层                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐     │
│  │ 向量索引     │ │ BM25索引     │ │   缓存       │     │
│  │ Vector DB    │ │ BM25 DB     │ │   Cache      │     │
│  └──────────────┘ └──────────────┘ └──────────────┘     │
└──────────────────────────────────────────────────────────┘
```

---

## 总结

这个 **RAG + Agent 融合架构** 提供了：

### 1. **完整的 Agent 能力集成**
   - Planning：任务拆解、流程编排、自我反思
   - Memory：短期记忆 + 长期记忆（RAG）
   - Tool Use：联网搜索、API调用、代码执行
   - Agent Core：决策大脑、逻辑推理

### 2. **增强的 RAG 能力**
   - 多策略检索（向量 + BM25 + 元数据）
   - Agent 增强重排
   - 工具增强检索
   - 记忆管理（对话上下文）

### 3. **智能化的决策流程**
   - 问题类型分析
   - 策略规划
   - 工具选择
   - 结果反思

### 4. **完善的评估体系**
   - 检索指标（召回率、精确率、F1、MRR、NDCG）
   - 答案质量（幻觉检测、相关度）
   - Agent 决策质量（规划效率、工具使用）
   - 自我优化

### 5. **生产级部署支持**
   - 多级缓存
   - 监控与日志
   - 评估与报告
   - 可扩展架构

---

## 核心优势对比

| 特性 | 纯 RAG | RAG + Agent |
|------|--------|-------------|
| **复杂查询** | ❌ 不支持 | ✅ 任务拆解 |
| **多轮对话** | ❌ 无状态 | ✅ 上下文管理 |
| **工具调用** | ❌ 不支持 | ✅ 搜索/API/代码 |
| **自我反思** | ❌ 不支持 | ✅ 检索优化 |
| **知识更新** | ❌ 静态 | ✅ 记忆压缩 |
| **可视化** | ❌ 不支持 | ✅ 图表生成 |
| **适应性** | ❌ 固定 | ✅ 灵活决策 |

---

## 下一步行动

1. **✅ 阅读本架构文档**
2. **🔧 实现基础 RAG 系统**
3. **🤖 逐步添加 Agent 能力**
4. **🔄 测试与优化**
5. **📊 评估与改进**

---

*文档生成日期：2026-02-23*  
*文档版本：2.0*  
*融合了 Agent 通用能力框架*