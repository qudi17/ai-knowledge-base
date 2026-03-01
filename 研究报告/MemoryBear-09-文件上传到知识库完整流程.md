---
tags: [memorybear, rag, file-upload, knowledge-base, chunking]
created: 2026-02-28
type: technical-analysis
status: draft
---

# MemoryBear - 文件上传到知识库完整流程分析

**研究日期**：2026-02-28  
**研究目标**：理解 MemoryBear 如何处理上传文件并转为知识库  
**核心文件**：`extraction_orchestrator.py`（93KB, 1900+ 行）

---

## 📊 执行摘要

### 完整流程概览

```
用户上传文件
    ↓
1. 文件存储（OSS/S3/Local）
    ↓
2. 文件解析（PDF/Word/Excel 等）
    ↓
3. 数据预处理（清洗、格式化）
    ↓
4. 分块（Chunking）
    ↓
5. 知识提取（陈述句/三元组/时间信息）
    ↓
6. 嵌入向量生成
    ↓
7. 去重消歧
    ↓
8. 写入 Neo4j 知识图谱
    ↓
9. 写入向量数据库
    ↓
知识库可用
```

---

## 🏗️ 核心组件

### 1. 文件解析器（Parsers）

**位置**：`api/app/core/rag/deepdoc/parser/`

**支持的格式**：

| 解析器 | 文件 | 代码行 | 说明 |
|--------|------|--------|------|
| **PDFParser** | pdf_parser.py | 56KB | 最复杂，支持 OCR、表格、图表 |
| **MinerUParser** | mineru_parser.py | 21KB | MagicData 高精度解析 |
| **ExcelParser** | excel_parser.py | 10KB | 表格数据处理 |
| **HTMLParser** | html_parser.py | 8KB | 网页内容解析 |
| **DocxParser** | docx_parser.py | 4KB | Word 文档 |
| **PPTParser** | ppt_parser.py | 3KB | PowerPoint |
| **JSONParser** | json_parser.py | 6KB | JSON/JSONL |
| **MarkdownParser** | markdown_parser.py | 10KB | Markdown 文档 |
| **TxTParser** | txt_parser.py | 1KB | 纯文本 |

---

### 2. 数据预处理器

**位置**：`api/app/core/memory/storage_services/extraction_engine/data_preprocessing/data_preprocessor.py`

**功能**：
- 支持多种格式：JSON, CSV, Excel, TXT
- 自动检测文件编码
- 清洗和标准化数据
- 转换为 DialogData 对象

**核心方法**：
```python
class DataPreprocessor:
    def __init__(self, input_file_path: str = None, output_file_path: str = None):
        self.supported_formats = ['.json', '.csv', '.txt', '.xlsx', '.tsv']
    
    def preprocess(self, input_file_path: str = None, output_file_path: str = None) -> List[DialogData]:
        # 1. 检测文件格式
        file_format = self.get_file_format(input_file_path)
        
        # 2. 检测编码
        encoding = self._detect_encoding(input_file_path)
        
        # 3. 根据格式读取
        if file_format == '.json':
            data = self._read_json(input_file_path)
        elif file_format == '.csv':
            data = self._read_csv(input_file_path)
        # ...
        
        # 4. 转换为 DialogData
        dialogs = self._convert_to_dialog_data(data)
        
        return dialogs
```

---

### 3. 分块器（Chunker）

**位置**：`api/app/core/memory/llm_tools/chunker_client.py`

**注意**：`data_chunker.py` 是占位符，实际实现在 `chunker_client.py`

**支持 7 种分块策略**：

| 策略 | 实现 | 适用场景 |
|------|------|---------|
| **TokenChunker** | chonkie.TokenChunker | 简单快速 |
| **SemanticChunker** | chonkie.SemanticChunker | 语义连贯 |
| **RecursiveChunker** | chonkie.RecursiveChunker | 结构化文本 |
| **LateChunker** | chonkie.LateChunker | 长文档 |
| **NeuralChunker** | chonkie.NeuralChunker | 高质量 |
| **LLMChunker** | 自定义 LLM 分块 | 智能分块 |
| **HybridChunker** | 自定义混合策略 | 平衡效果 |

**配置模型**：
```python
class ChunkerConfig(BaseModel):
    chunker_strategy: str = "RecursiveChunker"
    embedding_model: str
    chunk_size: int = 2048
    threshold: float = 0.8
    language: str = "zh"
```

---

### 4. 知识提取编排器

**位置**：`api/app/core/memory/storage_services/extraction_engine/extraction_orchestrator.py`

**核心类**：`ExtractionOrchestrator`（93KB, 1900+ 行）

**职责**：协调整个知识提取流程

---

## 📋 完整处理流程

### 阶段 1：文件上传与存储

**流程**：
```
用户上传文件
    ↓
FileController.receive_file()
    ↓
FileStorageService.save_file()
    ↓
存储策略（Local/OSS/S3）
    ↓
返回 file_url / file_id
```

**代码位置**：
- Controller: `api/app/controllers/file_controller.py`
- Service: `api/app/services/file_storage_service.py`
- Storage: `api/app/core/storage/` (local.py, oss.py, s3.py)

---

### 阶段 2：文件解析

**PDF 解析示例**（最复杂的场景）：

```python
# api/app/core/rag/deepdoc/parser/pdf_parser.py

class PDFParser:
    def parse(self, pdf_path: str, callback=None) -> Dict:
        """
        解析 PDF 文件
        
        返回：
        {
            "pages": [...],      # 每页内容
            "tables": [...],     # 表格数据
            "figures": [...],    # 图表数据
            "text": "...",       # 完整文本
            "layout": [...]      # 版面分析
        }
        """
        # 1. PDF 加载
        doc = fitz.open(pdf_path)
        
        # 2. 逐页解析
        for page in doc:
            # OCR 识别（如果是扫描版）
            if self.need_ocr(page):
                text = self.ocr_page(page)
            else:
                text = page.get_text()
            
            # 表格检测
            tables = self.detect_tables(page)
            
            # 图表检测
            figures = self.detect_figures(page)
            
            # 版面分析
            layout = self.analyze_layout(page)
        
        # 3. 后处理
        result = self.postprocess({
            "text": text,
            "tables": tables,
            "figures": figures,
            "layout": layout
        })
        
        return result
```

**其他格式**：
- Word: `docx_parser.py` → python-docx
- Excel: `excel_parser.py` → openpyxl/pandas
- HTML: `html_parser.py` → BeautifulSoup

---

### 阶段 3：数据预处理

**流程**：
```
解析后的文本/数据
    ↓
DataPreprocessor.preprocess()
    ↓
1. 编码检测（chardet）
    ↓
2. 数据读取（JSON/CSV/TXT）
    ↓
3. 数据清洗
   - 去除空白字符
   - 标准化格式
   - 修复编码问题
    ↓
4. 转换为 DialogData
    ↓
List[DialogData]
```

**DialogData 结构**：
```python
class DialogData:
    ref_id: str              # 引用 ID
    content: str             # 完整内容
    context: ConversationContext
    chunks: List[Chunk]      # 分块结果（后续填充）
    metadata: Dict           # 元数据
```

---

### 阶段 4：分块（Chunking）

**流程**：
```
List[DialogData]
    ↓
ChunkerClient.generate_chunks()
    ↓
遍历每个消息/段落
    ↓
┌─────────────────────────────┐
│ 内容长度 > chunk_size?       │
└───────┬─────────────────────┘
        │
    ┌───┴───┐
    │ 是    │  否
    ↓       ↓
使用分块策略  直接作为 chunk
进一步分块    
    ↓       ↓
创建 chunks  创建 chunk
    ↓
添加 metadata
    ↓
返回 chunked_dialogs
```

**代码**：
```python
# api/app/core/memory/llm_tools/chunker_client.py

class ChunkerClient:
    async def generate_chunks(self, dialogue: DialogData) -> DialogData:
        dialogue.chunks = []
        
        for msg_idx, msg in enumerate(dialogue.context.msgs):
            msg_content = msg.msg.strip()
            
            if len(msg_content) > self.chunk_size:
                # 消息太长，进一步分块
                sub_chunks = self.chunker(msg_content)
                for idx, sub_chunk in enumerate(sub_chunks):
                    chunk = Chunk(
                        content=f"{msg.role}: {sub_chunk.text}",
                        speaker=msg.role,
                        metadata={
                            "message_index": msg_idx,
                            "sub_chunk_index": idx,
                            "chunker_strategy": self.chunker_config.chunker_strategy,
                        }
                    )
                    dialogue.chunks.append(chunk)
            else:
                # 直接作为 chunk
                chunk = Chunk(
                    content=f"{msg.role}: {msg_content}",
                    speaker=msg.role,
                    metadata={
                        "message_index": msg_idx,
                        "chunker_strategy": self.chunker_config.chunker_strategy,
                    }
                )
                dialogue.chunks.append(chunk)
        
        return dialogue
```

---

### 阶段 5：知识提取（核心）

**ExtractionOrchestrator.run()** 协调整个流程：

```python
# api/app/core/memory/storage_services/extraction_engine/extraction_orchestrator.py

async def run(
    self,
    dialog_data_list: List[DialogData],
    is_pilot_run: bool = False,
) -> Tuple[...]:
    """
    运行完整的知识提取流水线
    """
    logger.info(f"开始知识提取流水线，共 {len(dialog_data_list)} 个对话")
    
    # ========== 步骤 1: 陈述句提取 ==========
    statement_tasks = []
    for dialog in dialog_data_list:
        for chunk in dialog.chunks:
            task = self.statement_extractor.process_chunk(chunk)
            statement_tasks.append(task)
    
    statement_results = await asyncio.gather(*statement_tasks)
    
    # ========== 步骤 2: 并行执行（优化点）==========
    # 2a. 三元组提取
    triplet_task = self._extract_triplets(dialog_data_list)
    
    # 2b. 时间信息提取
    temporal_task = self._extract_temporal_info(dialog_data_list)
    
    # 2c. 陈述句/分块嵌入生成
    embedding_task = self._generate_statement_embeddings(dialog_data_list)
    
    # 并行执行
    triplet_results, temporal_results, embedding_results = await asyncio.gather(
        triplet_task,
        temporal_task,
        embedding_task,
    )
    
    # ========== 步骤 3: 实体嵌入生成（依赖三元组）==========
    entity_embeddings = await self._generate_entity_embeddings(triplet_results)
    
    # ========== 步骤 4: 数据赋值 ==========
    # 将三元组、时间信息赋值到陈述句
    
    # ========== 步骤 5: 创建节点和边 ==========
    chunk_nodes = self._create_chunk_nodes(dialog_data_list)
    statement_nodes = self._create_statement_nodes(statement_results)
    entity_nodes = self._create_entity_nodes(triplet_results)
    
    # ========== 步骤 6: 两阶段去重消歧 ==========
    deduped_entities, merge_records = await dedup_layers_and_merge_and_return(
        entity_nodes,
        statement_entity_edges,
        entity_entity_edges,
        llm_client=self.llm_client,
        connector=self.connector,
    )
    
    # ========== 步骤 7: 写入数据库 ==========
    if not is_pilot_run:
        # 写入 Neo4j
        await self._write_nodes_to_neo4j(chunk_nodes, statement_nodes, deduped_entities)
        await self._write_edges_to_neo4j(statement_entity_edges, entity_entity_edges)
        
        # 写入向量数据库
        await self._write_embeddings_to_vector_db(embedding_results)
    
    # ========== 步骤 8: 生成摘要 ==========
    await self._generate_knowledge_base_summary()
    
    return (
        (dialog_nodes, chunk_nodes, statement_nodes),
        (entity_nodes, statement_entity_edges, entity_entity_edges),
        (deduped_entities, statement_entity_edges, entity_entity_edges),
    )
```

---

### 阶段 6：知识提取子流程

#### 6.1 陈述句提取（Statement Extraction）

**位置**：`knowledge_extraction/statement_extraction.py`

**功能**：从 chunk 中提取结构化陈述句

**Prompt 示例**：
```
从以下文本中提取关键陈述句：

文本：{chunk_content}

要求：
1. 每个陈述句表达一个完整的事实
2. 保持客观，不添加主观判断
3. 使用简洁的语言
4. 输出 JSON 格式

输出格式：
{
    "statements": [
        {"text": "...", "subject": "...", "predicate": "...", "object": "..."},
        ...
    ]
}
```

---

#### 6.2 三元组提取（Triplet Extraction）

**位置**：`knowledge_extraction/triplet_extraction.py`

**功能**：提取 (主体，谓词，客体) 三元组

**代码**：
```python
class TripletExtractor:
    async def extract(self, text: str) -> List[Triplet]:
        prompt = f"""
        从以下文本中提取实体关系三元组：
        
        文本：{text}
        
        本体类型：{self.ontology_types}
        
        输出格式：
        {{
            "triplets": [
                {{"head": "实体 1", "relation": "关系", "tail": "实体 2"}},
                ...
            ]
        }}
        """
        
        response = await self.llm_client.chat(prompt)
        triplets = self.parse_response(response)
        
        return triplets
```

---

#### 6.3 时间信息提取（Temporal Extraction）

**位置**：`knowledge_extraction/temporal_extraction.py`

**功能**：提取时间表达式和时效性信息

**提取内容**：
- 时间点（2023 年 Q4）
- 时间段（2023-2024 年）
- 相对时间（去年、上个月）
- 时效性（永久、临时、过期）

---

#### 6.4 嵌入向量生成（Embedding Generation）

**位置**：`knowledge_extraction/embedding_generation.py`

**功能**：为陈述句和实体生成向量嵌入

**代码**：
```python
async def embedding_generation(
    texts: List[str],
    embedder_client: OpenAIEmbedderClient,
    batch_size: int = 32,
) -> List[List[float]]:
    """批量生成嵌入向量"""
    all_embeddings = []
    
    for i in range(0, len(texts), batch_size):
        batch_texts = texts[i:i+batch_size]
        batch_embeddings = await embedder_client.embed(batch_texts)
        all_embeddings.extend(batch_embeddings)
    
    return all_embeddings
```

---

### 阶段 7：去重消歧

**位置**：`deduplication/two_stage_dedup.py`

**两阶段去重**：

#### 阶段 1：去重（Deduplication）

**目标**：识别并合并重复实体

**方法**：
1. 基于向量相似度聚类
2. LLM 判断是否重复
3. 合并重复实体

**代码**：
```python
async def dedup_layers_and_merge_and_return(
    entity_nodes: List[ExtractedEntityNode],
    ...
) -> Tuple[List[ExtractedEntityNode], List[Dict]]:
    # 1. 向量相似度聚类
    clusters = cluster_entities_by_similarity(entity_nodes, threshold=0.85)
    
    # 2. LLM 判断每对实体是否重复
    dedup_tasks = []
    for cluster in clusters:
        for pair in combinations(cluster, 2):
            task = llm_judge_duplicate(pair, llm_client)
            dedup_tasks.append(task)
    
    dedup_results = await asyncio.gather(*dedup_tasks)
    
    # 3. 合并重复实体
    merged_entities = merge_duplicate_entities(entity_nodes, dedup_results)
    
    return merged_entities, merge_records
```

---

#### 阶段 2：消歧（Disambiguation）

**目标**：区分同名异义实体

**方法**：
1. 基于上下文相似度
2. LLM 判断是否同义
3. 拆分或合并实体

---

### 阶段 8：写入数据库

#### 8.1 Neo4j 知识图谱

**节点类型**：
- DialogueNode（对话节点）
- ChunkNode（分块节点）
- StatementNode（陈述句节点）
- EntityNode（实体节点）

**边类型**：
- StatementChunkEdge（陈述句 - 分块）
- StatementEntityEdge（陈述句 - 实体）
- EntityEntityEdge（实体 - 实体）

**代码**：
```python
async def _write_nodes_to_neo4j(
    self,
    chunk_nodes: List[ChunkNode],
    statement_nodes: List[StatementNode],
    entity_nodes: List[ExtractedEntityNode],
):
    if self.is_pilot_run:
        return
    
    # 批量写入
    await self.connector.create_nodes(chunk_nodes)
    await self.connector.create_nodes(statement_nodes)
    await self.connector.create_nodes(entity_nodes)
```

---

#### 8.2 向量数据库

**用途**：语义检索

**存储内容**：
- 陈述句向量
- 实体向量
- Chunk 向量

**代码**：
```python
async def _write_embeddings_to_vector_db(
    self,
    embedding_results: Dict[str, List[float]],
):
    for statement_id, embedding in embedding_results.items():
        await self.vector_db.upsert(
            id=statement_id,
            vector=embedding,
            metadata={"type": "statement"}
        )
```

---

## 📊 性能优化

### 1. 并行执行

**优化点**：
```python
# 串行执行（慢）
statements = await extract_statements()
triplets = await extract_triplets()
temporal = await extract_temporal()

# 并行执行（快 3 倍）
statements, triplets, temporal = await asyncio.gather(
    extract_statements(),
    extract_triplets(),
    extract_temporal(),
)
```

---

### 2. 批量处理

**嵌入生成**：
```python
# 单个处理（慢）
for text in texts:
    embedding = await embedder.embed(text)

# 批量处理（快 10 倍）
embeddings = await embedder.embed_batch(texts, batch_size=32)
```

---

### 3. 试运行模式

**用途**：测试流程，不写入数据库

```python
result = await orchestrator.run(
    dialog_data_list,
    is_pilot_run=True  # 试运行，不写入
)
```

---

## 🎯 对 100 万研报场景的启示

### 可借鉴的设计

#### 1. 多格式解析支持

**建议**：
```python
# 支持多种研报格式
parsers = {
    ".pdf": PDFParser,
    ".docx": DocxParser,
    ".html": HTMLParser,
    ".txt": TxTParser,
}
```

---

#### 2. 灵活的分块策略

**建议**：
```python
# 针对不同文档类型使用不同策略
if document_type == "财报":
    strategy = "SemanticChunker"
elif document_type == "研报":
    strategy = "RecursiveChunker"  # 按章节
elif document_type == "新闻":
    strategy = "SentenceChunker"
```

---

#### 3. 知识提取流程

**建议**：
```python
# 研报场景的知识提取
async def extract_knowledge_from_report(report: ReportData):
    # 1. 陈述句提取（关键事实）
    statements = await extract_statements(report.chunks)
    
    # 2. 三元组提取（公司 - 指标 - 数值）
    triplets = await extract_triplets(report.chunks)
    # 例：(贵州茅台，2023 年营收，500 亿元)
    
    # 3. 时间信息提取（报告期）
    temporal = await extract_temporal(report.chunks)
    
    # 4. 嵌入生成
    embeddings = await generate_embeddings(statements)
    
    return statements, triplets, temporal, embeddings
```

---

#### 4. 去重消歧机制

**建议**：
```python
# 公司名消歧
# "茅台"、"贵州茅台"、"600519.SH" → 同一实体
merged_entities = await dedup_entities(entity_nodes)
```

---

### MemoryBear 的局限性（对研报场景）

| 局限 | 说明 | 改进方案 |
|------|------|---------|
| **面向对话** | 设计初衷是对话记忆 | 需要适配文档场景 |
| **缺少文档级上下文** | Chunk 只有角色信息 | 需要添加文档元数据 |
| **复杂度高** | 93KB 编排器，学习曲线陡 | 简化流程，专注核心 |
| **成本** | 大量 LLM 调用 | 使用 Contextual Retrieval 优化 |

---

## 📋 完整流程图

```
用户上传文件（PDF/Word/Excel 等）
    ↓
┌─────────────────────────────────────┐
│  1. 文件解析                         │
│     PDFParser / DocxParser / ...    │
│     输出：纯文本 + 表格 + 图表        │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  2. 数据预处理                       │
│     DataPreprocessor.preprocess()   │
│     - 编码检测                       │
│     - 数据清洗                       │
│     - 转换为 DialogData              │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  3. 分块（Chunking）                 │
│     ChunkerClient.generate_chunks() │
│     - 7 种策略可选                    │
│     - 默认 chunk_size=2048          │
│     输出：List[Chunk]               │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  4. 知识提取（并行执行）             │
│     ExtractionOrchestrator.run()    │
│                                     │
│     4a. 陈述句提取 ← LLM            │
│     4b. 三元组提取 ← LLM            │
│     4c. 时间信息提取 ← LLM          │
│     4d. 嵌入生成 ← Embedding 模型   │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  5. 去重消歧                         │
│     two_stage_dedup()               │
│     - 阶段 1：去重（向量聚类+LLM）    │
│     - 阶段 2：消歧（上下文+LLM）      │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  6. 写入数据库                       │
│     - Neo4j（知识图谱）             │
│     - 向量数据库（语义检索）         │
└─────────────────────────────────────┘
    ↓
知识库可用
    ↓
┌─────────────────────────────────────┐
│  7. 检索                             │
│     SearchService.execute_hybrid_search() │
│     - 向量检索 + 图谱检索            │
│     - Reranking（可选）             │
└─────────────────────────────────────┘
```

---

## 🔗 关键文件索引

| 组件 | 文件路径 | 代码行 | 说明 |
|------|---------|--------|------|
| **编排器** | extraction_orchestrator.py | 1900+ | 核心流程协调 |
| **分块器** | chunker_client.py | 300+ | 7 种分块策略 |
| **预处理器** | data_preprocessor.py | 600+ | 多格式支持 |
| **陈述句提取** | statement_extraction.py | - | LLM 提取 |
| **三元组提取** | triplet_extraction.py | - | 关系提取 |
| **去重消歧** | two_stage_dedup.py | - | 两阶段去重 |
| **PDF 解析** | pdf_parser.py | 56KB | 最复杂解析器 |

---

**文档版本**：v1.0  
**创建日期**：2026-02-28  
**作者**：Jarvis（基于 MemoryBear 代码分析）  
**状态**：Draft  
**下次 Review**：实施阶段 1 后更新
