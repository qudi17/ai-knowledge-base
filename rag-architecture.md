# RAG系统架构文档

> 版本：1.0
> 日期：2026-02-22
> 作者：Eddy

---

## 目录

1. [系统概述](#系统概述)
2. [阶段1：数据生成](#阶段1数据生成)
3. [阶段2：数据检索](#阶段2数据检索)
4. [阶段3：结果衡量](#阶段3结果衡量)
5. [技术栈](#技术栈)
6. [部署建议](#部署建议)

---

## 系统概述

### 架构图

```
┌─────────────────────────────────────────────────────────┐
│                    RAG 系统架构                          │
└─────────────────────────────────────────────────────────┘

┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  数据生成   │ -> │  数据检索   │ -> │  结果衡量   │
│  (Offline)  │    │  (Online)   │    │  (Offline)  │
└─────────────┘    └─────────────┘    └─────────────┘

核心流程：
数据源 -> 索引生成 -> 问题处理 -> 多策略检索 -> 重排 -> 答案生成 -> 评估
```

### 核心特性

- ✅ 双路检索（向量 + BM25）
- ✅ 智能重排（简单/复杂场景自适应）
- ✅ 问题拆分/重写
- ✅ 元数据管理
- ✅ 多级缓存
- ✅ 完整评估体系

---

## 阶段1：数据生成

### 1.1 数据读取

#### 支持的数据源

| 数据类型 | 格式 | 读取方式 |
|---------|------|---------|
| 文档 | PDF, DOCX, TXT, MD | file loader |
| 网页 | HTML | web crawler |
| 数据库 | SQL, NoSQL | database connector |
| API | JSON, XML | API client |

#### 数据预处理流程

```python
class DataLoader:
    """数据加载器"""

    def load_from_file(self, file_path):
        """从文件加载数据"""
        pass

    def load_from_db(self, db_config):
        """从数据库加载数据"""
        pass

    def load_from_api(self, api_config):
        """从API加载数据"""
        pass

    def clean_text(self, text):
        """清理文本"""
        # 去除HTML标签
        # 标准化空白符
        # 去除特殊字符
        pass
```

---

### 1.2 分块策略（Chunking）

#### 分块方法

**方法1：固定长度分块**
```python
chunk_size = 512  # tokens
overlap = 50      # 10% overlap
```

**方法2：元素级分块（推荐）**
```python
# 按文档结构分块
chunks = [
    {"type": "section", "title": "Introduction", "content": "..."},
    {"type": "table", "content": "..."},
    {"type": "section", "title": "Methodology", "content": "..."}
]
```

**方法3：语义分块**
```python
# 使用 spaCy 或其他 NLP 工具
import spacy
nlp = spacy.load("en_core_web_sm")

def semantic_chunk(text, max_sentences=10):
    """基于语义的智能分块"""
    doc = nlp(text)
    chunks = []
    current_chunk = []
    sentence_count = 0

    for sent in doc.sents:
        current_chunk.append(sent.text)
        sentence_count += 1

        if sentence_count >= max_sentences:
            chunks.append(" ".join(current_chunk))
            current_chunk = []
            sentence_count = 0

    return chunks
```

#### 分块配置

```python
chunking_config = {
    "method": "semantic",  # fixed | element | semantic
    "chunk_size": 512,
    "overlap": 50,
    "min_chunk_size": 100,
    "max_chunk_size": 1000,
    "separator": "\n\n"
}
```

---

### 1.3 元数据管理

#### 元数据结构

```python
class ChunkMetadata:
    """分块元数据"""

    def __init__(self):
        self.chunk_id = ""              # 唯一标识
        self.source_file = ""           # 来源文件
        self.source_page = 0            # 页码
        self.source_section = ""        # 章节标题
        self.title = ""                 # 文档标题
        self.tags = []                  # 标签
        self.chunk_index = 0            # 在文档中的索引
        self.total_chunks = 0           # 总分块数
        self.created_at = ""            # 创建时间
        self.chunk_type = ""            # 类型：section/table/list
        self.parent_id = ""            # 父块ID（用于层级结构）
        self.language = ""             # 语言
        self.word_count = 0            # 字数
```

#### 元数据用途

1. **检索过滤**：按标签、时间、来源过滤
2. **相关性增强**：标题匹配、标签匹配加分
3. **结果展示**：提供上下文信息
4. **调试分析**：追溯来源

---

### 1.4 索引生成

#### 向量索引

```python
from sentence_transformers import SentenceTransformer
import faiss

class VectorIndex:
    """向量索引"""

    def __init__(self, model_name="BAAI/bge-small-en-v1.5"):
        self.model = SentenceTransformer(model_name)
        self.index = None
        self.chunks = []

    def build_index(self, chunks):
        """构建索引"""
        embeddings = self.model.encode(
            [c["content"] for c in chunks],
            show_progress_bar=True
        )

        dimension = embeddings.shape[1]
        self.index = faiss.IndexFlatIP(dimension)  # 内积相似度
        self.index.add(embeddings)
        self.chunks = chunks

    def search(self, query_embedding, top_k=10):
        """搜索"""
        scores, indices = self.index.search(
            query_embedding.reshape(1, -1),
            top_k
        )
        return [
            {"chunk": self.chunks[i], "score": float(scores[0][j])}
            for j, i in enumerate(indices[0])
        ]
```

#### BM25索引

```python
from rank_bm25 import BM25Okapi
import jieba  # 中文分词

class BM25Index:
    """BM25索引"""

    def __init__(self, language="en"):
        self.language = language
        self.index = None
        self.chunks = []

    def tokenize(self, text):
        """分词"""
        if self.language == "zh":
            return list(jieba.cut(text))
        else:
            return text.lower().split()

    def build_index(self, chunks):
        """构建索引"""
        tokenized_docs = [
            self.tokenize(c["content"])
            for c in chunks
        ]
        self.index = BM25Okapi(tokenized_docs)
        self.chunks = chunks

    def search(self, query, top_k=10):
        """搜索"""
        tokenized_query = self.tokenize(query)
        scores = self.index.get_scores(tokenized_query)
        top_indices = scores.argsort()[-top_k:][::-1]

        return [
            {"chunk": self.chunks[i], "score": float(scores[i])]}
            for i in top_indices
        ]
```

---

### 1.5 缓存策略

#### 多级缓存

```python
class CacheManager:
    """缓存管理器"""

    def __init__(self):
        self.vector_cache = {}
        self.bm25_cache = {}
        self.chunk_cache = {}

    def cache_vector_index(self, index, key):
        """缓存向量索引"""
        self.vector_cache[key] = index

    def cache_bm25_index(self, index, key):
        """缓存BM25索引"""
        self.bm25_cache[key] = index

    def cache_chunks(self, chunks, key):
        """缓存分块"""
        self.chunk_cache[key] = chunks

    def load_vector_index(self, key):
        """加载向量索引"""
        return self.vector_cache.get(key)

    def load_bm25_index(self, key):
        """加载BM25索引"""
        return self.bm25_cache.get(key)
```

#### 缓存配置

```python
cache_config = {
    "vector_cache": {
        "enabled": True,
        "cache_dir": "./cache/vector",
        "max_size": "1GB"
    },
    "bm25_cache": {
        "enabled": True,
        "cache_dir": "./cache/bm25",
        "max_size": "100MB"
    },
    "chunk_cache": {
        "enabled": True,
        "cache_dir": "./cache/chunks",
        "max_size": "500MB"
    }
}
```

---

## 阶段2：数据检索

### 2.1 问题处理

#### 问题拆分/重写

```python
class QueryProcessor:
    """查询处理器"""

    def __init__(self, model):
        self.model = model

    def analyze_query(self, query):
        """分析查询类型"""
        prompt = f"""
        分析以下查询，判断是否需要拆分：
        查询：{query}

        返回JSON格式：
        {{
            "type": "single" | "multi",
            "sub_queries": ["query1", "query2", ...],
            "reason": "分析原因"
        }}
        """
        response = self.model.generate(prompt)
        return json.loads(response)

    def rewrite_query(self, query):
        """重写查询（优化表达）"""
        prompt = f"""
        优化以下查询，使其更清晰、更易检索：
        原查询：{query}

        优化后的查询：
        """
        return self.model.generate(prompt)

    def validate_sub_query(self, sub_query, original_query):
        """验证子查询是否偏离原问题"""
        # 计算向量相似度
        sim = cosine_similarity(
            get_embedding(sub_query),
            get_embedding(original_query)
        )

        # 如果相似度低于阈值，则认为偏离
        threshold = 0.7
        if sim < threshold:
            return False, f"相似度过低：{sim:.2f}"
        return True, f"相似度：{sim:.2f}"
```

---

### 2.2 多策略检索

#### 检索流程

```python
class MultiStrategyRetriever:
    """多策略检索器"""

    def __init__(self, vector_index, bm25_index, config):
        self.vector_index = vector_index
        self.bm25_index = bm25_index
        self.config = config

    def retrieve(self, query, top_k=10):
        """多策略检索"""

        # 1. 向量检索
        vector_results = self.vector_index.search(
            get_embedding(query),
            top_k=100
        )

        # 2. BM25检索
        bm25_results = self.bm25_index.search(
            query,
            top_k=100
        )

        # 3. 合并去重
        merged_results = self._merge_results(
            vector_results,
            bm25_results
        )

        # 4. 特征工程
        results_with_features = self._add_features(
            merged_results,
            query
        )

        # 5. 融合打分
        results_with_scores = self._fuse_scores(
            results_with_features,
            self.config.get("fusion_weights", {})
        )

        # 6. 重排
        final_results = self._rerank(
            results_with_scores,
            query,
            top_k
        )

        return final_results
```

#### 特征工程

```python
def _add_features(self, chunks, query):
    """添加特征"""
    query_lower = query.lower()
    query_embedding = get_embedding(query)

    for item in chunks:
        chunk = item["chunk"]
        features = {}

        # 基础分数
        features["vector_score"] = normalize(item["vector_score"])
        features["bm25_score"] = normalize(item["bm25_score"])

        # 元数据特征
        features["title_match"] = 1 if query_lower in chunk.get("title", "").lower() else 0
        features["tag_match"] = len(set(query_lower.split()) & set(chunk.get("tags", [])))

        # 文档特征
        features["word_count"] = len(chunk.get("content", "").split())
        features["chunk_position"] = chunk.get("chunk_index", 0) / chunk.get("total_chunks", 1)

        # 语义特征
        chunk_embedding = get_embedding(chunk.get("content", ""))
        features["semantic_similarity"] = cosine_similarity(
            query_embedding,
            chunk_embedding
        )

        item["features"] = features

    return chunks
```

#### 融合打分

```python
def _fuse_scores(self, chunks, weights):
    """融合分数"""
    default_weights = {
        "vector": 0.6,
        "bm25": 0.3,
        "metadata": 0.1
    }
    weights = {**default_weights, **weights}

    for item in chunks:
        features = item["features"]

        # 线性加权
        fused_score = (
            weights["vector"] * features["vector_score"] +
            weights["bm25"] * features["bm25_score"] +
            weights["metadata"] * (
                features["title_match"] * 0.3 +
                features["tag_match"] * 0.2 +
                features["semantic_similarity"] * 0.5
            )
        )

        item["fused_score"] = fused_score

    return chunks
```

---

### 2.3 重排策略

#### 简单场景重排

```python
def simple_rerank(chunks, query, top_k=10):
    """简单重排：按融合分数排序"""
    return sorted(
        chunks,
        key=lambda x: x.get("fused_score", 0),
        reverse=True
    )[:top_k]
```

#### 复杂场景重排

```python
def advanced_rerank(chunks, query, top_k=10, method="lambda_mart"):
    """复杂重排：使用重排模型"""

    if method == "lambda_mart":
        # 方案1：LambdaMART
        model = load_lambda_mart_model()
        features = prepare_features(chunks, query)
        scores = model.predict(features)

        for i, item in enumerate(chunks):
            item["rerank_score"] = scores[i]

    elif method == "cross_encoder":
        # 方案2：Cross-Encoder
        model = SentenceTransformer('cross-encoder/ms-marco-MiniLM-L-6-v2')
        scores = model.predict(
            [(query, item["chunk"]["content"]) for item in chunks]
        )

        for i, item in enumerate(chunks):
            item["rerank_score"] = float(scores[i])

    elif method == "bert_ranker":
        # 方案3：BERT Ranker
        model = load_bert_ranker()
        scores = model.rank(query, [item["chunk"] for item in chunks])

        for i, item in enumerate(chunks):
            item["rerank_score"] = scores[i]

    # 按重排分数排序
    return sorted(
        chunks,
        key=lambda x: x.get("rerank_score", 0),
        reverse=True
    )[:top_k]
```

#### 重排选择策略

```python
def select_rerank_strategy(chunks, query):
    """根据场景选择重排策略"""
    # 简单场景
    if len(chunks) <= 20:
        return "simple"
    # 复杂场景
    else:
        # 根据查询复杂度选择
        if len(query.split()) > 10:
            return "cross_encoder"
        else:
            return "lambda_mart"
```

---

## 阶段3：结果衡量

### 3.1 评估指标

```python
class EvaluationMetrics:
    """评估指标"""

    @staticmethod
    def recall(retrieved_docs, ground_truth_docs):
        """召回率"""
        retrieved_set = set(doc["id"] for doc in retrieved_docs)
        truth_set = set(doc["id"] for doc in ground_truth_docs)

        if len(truth_set) == 0:
            return 0.0

        return len(retrieved_set & truth_set) / len(truth_set)

    @staticmethod
    def precision(retrieved_docs, ground_truth_docs):
        """精确率"""
        retrieved_set = set(doc["id"] for doc in retrieved_docs)
        truth_set = set(doc["id"] for doc in ground_truth_docs)

        if len(retrieved_set) == 0:
            return 0.0

        return len(retrieved_set & truth_set) / len(retrieved_set)

    @staticmethod
    def f1_score(precision, recall):
        """F1分数"""
        if precision + recall == 0:
            return 0.0
        return 2 * (precision * recall) / (precision + recall)

    @staticmethod
    def mrr(retrieved_docs, ground_truth_docs):
        """平均倒数排名"""
        truth_set = set(doc["id"] for doc in ground_truth_docs)

        for i, doc in enumerate(retrieved_docs, 1):
            if doc["id"] in truth_set:
                return 1.0 / i

        return 0.0

    @staticmethod
    def ndcg(retrieved_docs, ground_truth_docs):
        """归一化折损累积增益"""
        # 实现NDCG计算
        pass
```

---

### 3.2 幻觉检测

```python
class HallucinationDetector:
    """幻觉检测器"""

    def __init__(self, model):
        self.model = model

    def detect(self, answer, retrieved_docs):
        """检测幻觉"""
        # 提取答案中的关键信息
        key_info = self._extract_key_info(answer)

        # 检查关键信息是否在检索到的文档中
        all_docs_content = " ".join([doc["content"] for doc in retrieved_docs])

        hallucinated = []
        for info in key_info:
            if info not in all_docs_content:
                hallucinated.append(info)

        if len(hallucinated) > 0:
            hallucination_rate = len(hallucinated) / len(key_info)
            return True, hallucination_rate, hallucinated

        return False, 0.0, []

    def _extract_key_info(self, answer):
        """提取关键信息"""
        prompt = f"""
        从以下答案中提取关键信息（事实、数据、名词等）：
        答案：{answer}

        返回关键信息列表：
        """
        response = self.model.generate(prompt)
        return [info.strip() for info in response.split("\n") if info.strip()]
```

---

### 3.3 评估流程

```python
class RAGEvaluator:
    """RAG系统评估器"""

    def __init__(self, retriever, metrics, detector):
        self.retriever = retriever
        self.metrics = metrics
        self.detector = detector

    def evaluate(self, test_dataset):
        """评估RAG系统"""
        results = []

        for query_item in test_dataset:
            query = query_item["query"]
            ground_truth = query_item["ground_truth"]

            # 1. 检索
            retrieved_docs = self.retriever.retrieve(query, top_k=10)

            # 2. 生成答案（如果有生成器）
            # answer = generator.generate(query, retrieved_docs)

            # 3. 计算指标
            recall = self.metrics.recall(retrieved_docs, ground_truth)
            precision = self.metrics.precision(retrieved_docs, ground_truth)
            f1 = self.metrics.f1_score(precision, recall)
            mrr = self.metrics.mrr(retrieved_docs, ground_truth)

            # 4. 检测幻觉
            # has_hallucination, hallucination_rate, hallucinated = \
            #     self.detector.detect(answer, retrieved_docs)

            results.append({
                "query": query,
                "recall": recall,
                "precision": precision,
                "f1": f1,
                "mrr": mrr,
                # "has_hallucination": has_hallucination,
                # "hallucination_rate": hallucination_rate
            })

        # 5. 聚合指标
        avg_recall = sum(r["recall"] for r in results) / len(results)
        avg_precision = sum(r["precision"] for r in results) / len(results)
        avg_f1 = sum(r["f1"] for r in results) / len(results)
        avg_mrr = sum(r["mrr"] for r in results) / len(results)

        return {
            "detailed_results": results,
            "summary": {
                "avg_recall": avg_recall,
                "avg_precision": avg_precision,
                "avg_f1": avg_f1,
                "avg_mrr": avg_mrr
            }
        }
```

---

## 技术栈

### 核心依赖

| 组件 | 技术 | 用途 |
|------|------|------|
| 向量模型 | BAAI/bge-small-en-v1.5 | 文本嵌入 |
| 向量数据库 | FAISS / ChromaDB | 向量索引 |
| BM25 | rank_bm25 | 稀疏检索 |
| 分词 | spaCy / jieba | 文本分块 |
| 重排 | LambdaMART / Cross-Encoder | 结果重排 |
| 缓存 | Redis / 本地文件 | 多级缓存 |
| 评估 | LLM-as-Judge | 自动评估 |

### 安装命令

```bash
# 核心依赖
pip install sentence-transformers faiss-cpu rank-bm25 spacy jieba

# 中文分词
pip install jieba

# 可选：GPU加速
pip install faiss-gpu
```

---

## 部署建议

### 开发环境

```python
# 简单配置
config = {
    "chunking": {
        "method": "semantic",
        "chunk_size": 512,
        "overlap": 50
    },
    "retrieval": {
        "vector_weight": 0.6,
        "bm25_weight": 0.3,
        "metadata_weight": 0.1
    },
    "rerank": {
        "strategy": "simple"
    }
}
```

### 生产环境

```python
# 生产配置
config = {
    "chunking": {
        "method": "semantic",
        "chunk_size": 512,
        "overlap": 50
    },
    "retrieval": {
        "vector_weight": 0.5,
        "bm25_weight": 0.3,
        "metadata_weight": 0.2
    },
    "rerank": {
        "strategy": "lambda_mart",
        "top_k_for_rerank": 50
    },
    "cache": {
        "enabled": True,
        "redis_url": "redis://localhost:6379"
    },
    "evaluation": {
        "enabled": True,
        "report_interval": "daily"
    }
}
```

---

## 总结

这个RAG系统架构提供了：

1. **完整的端到端流程**：从数据加载到结果评估
2. **多策略检索**：向量 + BM25 + 元数据
3. **灵活的重排**：简单/复杂场景自适应
4. **完善的评估体系**：召回率、精确率、F1、MRR、幻觉检测
5. **可扩展的设计**：易于添加新的检索策略或评估指标

---

*文档生成日期：2026-02-22*
*文档版本：1.0*
