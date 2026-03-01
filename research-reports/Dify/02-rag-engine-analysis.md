# Dify - RAG 引擎深度分析

**研究阶段**: Phase 2  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 v2.0

---

## 📊 RAG 引擎架构

### 核心模块

```
api/core/rag/
├── datasource/           # 数据源（15+ 向量数据库支持）
│   └── vdb/             # 向量数据库
│       ├── qdrant/      # Qdrant
│       ├── milvus/      # Milvus
│       ├── weaviate/    # Weaviate
│       ├── pgvector/    # PostgreSQL
│       └── ...          # 15+ 种
├── retrieval/           # 检索引擎
│   ├── dataset_retrieval.py  # 知识库检索 ⭐
│   └── retrieval_methods.py  # 检索方法
├── index_processor/     # 索引处理器
│   └── processor/       # 分块索引
├── embedding/           # 向量化
├── splitter/            # 文档分块
├── rerank/              # 重排序
│   └── rerank_type.py  # 重排序模式
└── data_post_processor/ # 后处理
```

---

## 🔍 核心流程分析

### 1. 文档处理流程

```
文档上传 → 解析 → 清洗 → 分块 → 向量化 → 索引 → 存储
```

**关键代码**: [`api/core/rag/index_processor/`](https://github.com/langgenius/dify/tree/main/api/core/rag/index_processor)

```python
# 索引处理流程
class IndexProcessor:
    def process(self, documents: list[Document]):
        # 1. 文档解析
        parsed_docs = self.parser.parse(documents)
        
        # 2. 文档清洗
        cleaned_docs = self.cleaner.clean(parsed_docs)
        
        # 3. 文档分块
        chunks = self.splitter.split(cleaned_docs)
        
        # 4. 向量化
        embeddings = self.embedding.embed_documents(chunks)
        
        # 5. 索引
        self.vector_store.add_documents(chunks, embeddings)
```

---

### 2. 检索流程

**关键代码**: [`api/core/rag/retrieval/dataset_retrieval.py`](https://github.com/langgenius/dify/blob/main/api/core/rag/retrieval/dataset_retrieval.py)

```python
class DatasetRetrieval:
    def knowledge_retrieval(self, request: KnowledgeRetrievalRequest):
        # 1. 获取可用知识库
        available_datasets = self._get_available_datasets(...)
        
        # 2. 元数据过滤（可选）
        if request.metadata_filtering_mode != "disabled":
            metadata_filter = self.get_metadata_filter_condition(...)
        
        # 3. 向量检索
        documents = RetrievalService.retrieve(
            query=request.query,
            dataset_ids=available_datasets,
            top_k=request.top_k
        )
        
        # 4. 重排序（可选）
        if request.reranking_enable:
            documents = self.rerank(request.query, documents)
        
        # 5. 后处理
        processed_docs = DataPostProcessor.process(documents)
        
        return processed_docs
```

---

### 3. 支持的检索方法

**文件**: [`api/core/rag/retrieval/retrieval_methods.py`](https://github.com/langgenius/dify/blob/main/api/core/rag/retrieval/retrieval_methods.py)

```python
class RetrievalMethod(Enum):
    SEMANTIC_SEARCH = "semantic_search"      # 语义检索
    FULL_TEXT_SEARCH = "full_text_search"    # 全文检索
    HYBRID_SEARCH = "hybrid_search"          # 混合检索
    INVERTED_INDEX = "inverted_index"        # 倒排索引
```

---

## 🎯 向量数据库支持

### 支持的向量数据库（15+ 种）

| 数据库 | 类型 | 说明 |
|--------|------|------|
| **Qdrant** | 专用向量库 | Rust 编写，高性能 |
| **Milvus** | 专用向量库 | 分布式，大规模 |
| **Weaviate** | 专用向量库 | 图 + 向量 |
| **Chroma** | 专用向量库 | 轻量级 |
| **PGVector** | PostgreSQL 扩展 | 关系型 + 向量 |
| **TiDB Vector** | 分布式数据库 | 云原生 |
| **Oracle Vector** | 商业数据库 | 企业级 |
| **Elasticsearch** | 搜索引擎 | 全文 + 向量 |
| **OpenSearch** | 搜索引擎 | AWS  fork |
| **...** | ... | ... |

---

## 📊 分块策略

### 支持的分块方法

**文件**: [`api/core/rag/splitter/`](https://github.com/langgenius/dify/tree/main/api/core/rag/splitter)

```python
# 分块器
class TextSplitter:
    # 1. 固定长度分块
    def split_by_length(self, text: str, chunk_size: int): ...
    
    # 2. 递归字符分块
    def split_recursive(self, text: str): ...
    
    # 3. 语义分块（基于句子/段落）
    def split_by_semantic(self, text: str): ...
    
    # 4. Markdown 专用分块
    def split_markdown(self, text: str): ...
```

---

## 🔄 重排序机制

### 重排序模式

**文件**: [`api/core/rag/rerank/rerank_type.py`](https://github.com/langgenius/dify/blob/main/api/core/rag/rerank/rerank_type.py)

```python
class RerankMode(Enum):
    RERANKING_MODEL = "reranking_model"  # 重排序模型
    WEIGHTED_SCORE = "weighted_score"    # 加权分数
    NOMIC_BERT = "nomic_bert"            # Nomic BERT
    COHERE_RERANK = "cohere_rerank"      # Cohere Rerank
```

---

## 🎯 Phase 2 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 分析文档解析和分块 | 完成 | 4 种分块方法 |
| ✅ 分析向量索引和检索 | 完成 | 4 种检索方法 |
| ✅ 分析知识库管理 | 完成 | 多知识库支持 |
| ✅ 分析混合检索策略 | 完成 | 语义 + 全文 + 混合 |
| ✅ 识别设计模式 | 完成 | Strategy/Factory |

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 v2.0
