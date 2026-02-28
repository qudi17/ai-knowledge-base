# 大规模股票研究报告 RAG 解决方案

**数据规模**：100万份报告 × 4-5页 = 400-500万页
**总文本量**：约 80-100亿中文字符（假设每页 2000 字）
**数据格式**：PDF

---

## 🏗️ 整体架构

```
数据层 (100万份 PDF)
    ↓
  解析层
    ↓
  清洗层
    ↓
  分块层 (chunking)
    ↓
  向量化层
    ↓
  存储/索引层
    ↓
  检索层
    ↓
  查询层
```

---

## 📊 方案选择

| 组件 | 推荐方案 | 理由 |
|---|---|---|
| PDF 解析 | **pdfplumber** / **PyMuPDF** | 中文支持好，速度快 |
| 文本清洗 | **jieba** + 正则 | 中文分词，去除噪声 |
| 分块策略 | **语义分块** + **重叠** | 更好的检索效果 |
| 向量嵌入 | **智谱 GLM** / **OpenAI** | 中文效果优秀 |
| 索引存储 | **Weaviate** / **Milvus** / **Chroma** | 可扩展，支持大规模 |
| 检索引擎 | **Hybrid** (BM25 + 向量) | 提升召回率 |
| 缓存层 | **Redis** / **内存缓存** | 减少重复计算 |

---

## 🔄 完整流程图

```
┌─────────────────────────────────────────────────────────┐
│                    数据准备阶段                            │
│  • 100万份 PDF 研报                                       │
│  • 扫描文件系统                                           │
│  • 验证文件完整性                                         │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    解析阶段                               │
│  • pdfplumber 逐页解析                                    │
│  • 提取文本 + 元数据（公司、行业、日期）                     │
│  • 识别表格和公式                                          │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    清洗阶段                               │
│  • 去除多余空白                                            │
│  • 中文分词 (jieba)                                        │
│  • 过滤噪声（页眉、页脚、广告）                             │
│  • 标准化标点                                            │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    分块阶段                               │
│  • 语义分块 (基于句子边界)                                 │
│  • 每块 500-1000 字                                      │
│  • 重叠 50-100 字                                         │
│  • 添加元数据标签                                          │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    向量化阶段                              │
│  • 调用嵌入 API (GLM-4 / OpenAI)                          │
│  • 批量处理 (50-100 条/批次)                               │
│  • 错误重试 + 降级处理                                    │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    索引构建阶段                            │
│  • 保存向量 + 元数据                                      │
│  • 建立 BM25 索引                                         │
│  • 数据预计算                                             │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    检索阶段                               │
│  • 混合检索 (向量 + BM25)                                  │
│  • 重排序 (Cross-Encoder)                                  │
│  • 结果合并                                             │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    查询阶段                               │
│  • 用户提问                                               │
│  • 检索相关文档                                           │
│  • 生成答案                                               │
└─────────────────────────────────────────────────────────┘
```

---

## 💻 关键步骤代码实现

### 步骤 1: PDF 解析

```python
# pdf_parser.py
import pdfplumber
from typing import List, Dict
import re
from pathlib import Path

class PDFParser:
    """PDF 解析器 - 提取文本和元数据"""

    def __init__(self, chunk_size: int = 1000, chunk_overlap: int = 50):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

    def parse_file(self, file_path: Path) -> List[Dict]:
        """解析单个 PDF 文件"""
        text_chunks = []
        metadata = {
            "file_name": file_path.name,
            "file_path": str(file_path),
            "page_count": 0
        }

        with pdfplumber.open(file_path) as pdf:
            for i, page in enumerate(pdf.pages):
                # 提取页面文本
                page_text = self._extract_text(page)
                metadata["page_count"] += 1

                # 提取元数据（页眉、页脚、日期等）
                page_metadata = self._extract_metadata(page, i + 1)

                # 分块
                chunks = self._chunk_text(page_text, metadata, page_metadata)
                text_chunks.extend(chunks)

        print(f"✓ 解析完成: {file_path.name} -> {len(text_chunks)} 个块")
        return text_chunks

    def _extract_text(self, page) -> str:
        """提取页面文本"""
        # 保留段落结构
        text = page.extract_text(layout=True)
        # 去除多余的空白
        text = re.sub(r'\n+', '\n', text)
        return text.strip()

    def _extract_metadata(self, page, page_num: int) -> Dict:
        """提取页面元数据"""
        metadata = {"page_num": page_num}

        # 尝试提取日期（常见格式）
        date_pattern = r'(\d{4}年\d{1,2}月\d{1,2}日)'
        dates = re.findall(date_pattern, page.extract_text() or "")
        if dates:
            metadata["date"] = dates[-1]

        # 尝试提取公司名称
        company_pattern = r'([A-Za-z0-9\u4e00-\u9fa5]{2,20})研究报告'
        companies = re.findall(company_pattern, page.extract_text() or "")
        if companies:
            metadata["company"] = companies[-1]

        # 尝试提取行业
        industry_pattern = r'(计算机|互联网|医药|金融|消费|汽车|电子|通信|传媒|化工|建筑|原材料)'
        industries = re.findall(industry_pattern, page.extract_text() or "")
        if industries:
            metadata["industry"] = industries[-1]

        return metadata

    def _chunk_text(
        self,
        text: str,
        file_metadata: Dict,
        page_metadata: Dict
    ) -> List[Dict]:
        """文本分块"""
        if not text:
            return []

        chunks = []
        words = text.split()

        # 语义分块（按句子边界）
        sentences = re.split(r'[。！？\.\!?]', text)
        current_chunk = ""
        overlap_chunk = ""

        for sentence in sentences:
            # 添加重叠
            if overlap_chunk:
                sentence = overlap_chunk + sentence
                overlap_chunk = ""

            # 尝试合并句子直到达到 chunk_size
            while len(current_chunk) + len(sentence) < self.chunk_size:
                current_chunk += sentence + "。"
                sentence = ""

                # 如果句子为空，说明已经达到大小
                if not sentence:
                    break

            # 如果当前句子太长，强制分块
            if len(current_chunk) + len(sentence) >= self.chunk_size:
                # 保存当前块
                if len(current_chunk) >= self.chunk_size // 2:
                    chunks.append({
                        "text": current_chunk.strip(),
                        "metadata": {
                            **file_metadata,
                            **page_metadata,
                            "chunk_id": len(chunks) + 1
                        }
                    })

                # 保存重叠部分
                overlap_chunk = current_chunk[-self.chunk_overlap:]

                # 开始新块
                current_chunk = sentence
            else:
                current_chunk += sentence + "。"

        # 保存最后一个块
        if current_chunk.strip():
            chunks.append({
                "text": current_chunk.strip(),
                "metadata": {
                    **file_metadata,
                    **page_metadata,
                    "chunk_id": len(chunks) + 1
                }
            })

        return chunks

    def parse_directory(self, directory: Path, pattern: str = "*.pdf") -> List[Dict]:
        """批量解析目录"""
        import glob
        import time

        all_chunks = []
        pdf_files = sorted(Path(directory).glob(pattern))

        print(f"📂 找到 {len(pdf_files)} 个 PDF 文件")

        for pdf_file in pdf_files:
            try:
                chunks = self.parse_file(pdf_file)
                all_chunks.extend(chunks)

                # 控制速率
                time.sleep(0.1)  # 避免触发 API 限流

            except Exception as e:
                print(f"✗ 解析失败: {pdf_file.name} - {e}")

        print(f"✓ 全部完成: 共 {len(all_chunks)} 个文本块")
        return all_chunks


# 使用示例
if __name__ == "__main__":
    parser = PDFParser(chunk_size=1000, chunk_overlap=50)
    chunks = parser.parse_directory(Path("./research_papers"))
    print(f"总块数: {len(chunks)}")
```

---

### 步骤 2: 文本清洗

```python
# text_cleaner.py
import re
import jieba
from typing import List, Dict

class TextCleaner:
    """文本清洗器"""

    def __init__(self, stop_words_path: str = None):
        # 加载停用词
        self.stop_words = self._load_stop_words(stop_words_path)

    def clean(self, text: str) -> str:
        """清洗单个文本块"""
        # 1. 去除特殊字符
        text = self._remove_special_chars(text)

        # 2. 去除多余空白
        text = re.sub(r'\s+', ' ', text).strip()

        # 3. 中文分词
        words = self._segment(text)

        # 4. 去除停用词
        words = [w for w in words if w not in self.stop_words]

        # 5. 合并回文本
        return ' '.join(words)

    def clean_batch(self, chunks: List[Dict]) -> List[Dict]:
        """批量清洗"""
        return [
            {
                "text": self.clean(chunk["text"]),
                "metadata": chunk["metadata"]
            }
            for chunk in chunks
        ]

    def _remove_special_chars(self, text: str) -> str:
        """去除特殊字符"""
        # 保留中文、英文、数字、常见标点
        text = re.sub(r'[^\u4e00-\u9fa5a-zA-Z0-9，。！？、；：""''（）《》]', ' ', text)
        return text

    def _segment(self, text: str) -> List[str]:
        """中文分词"""
        return jieba.lcut(text)

    def _load_stop_words(self, path: str) -> set:
        """加载停用词表"""
        if path and Path(path).exists():
            with open(path, 'r', encoding='utf-8') as f:
                return set(line.strip() for line in f)
        return set()


# 使用示例
if __name__ == "__main__":
    cleaner = TextCleaner()

    test_text = """
    甲股市场方面，医药行业整体表现稳健。行业龙头公司凭借强大的研发实力，
    持续推出创新药物。同时，随着人口老龄化加剧，医药行业长期前景向好。
    投资者应关注具有核心竞争力的细分领域龙头。
    """

    cleaned = cleaner.clean(test_text)
    print(f"清洗前: {test_text[:100]}...")
    print(f"清洗后: {cleaned[:100]}...")
```

---

### 步骤 3: 向量化

```python
# vectorizer.py
import os
from typing import List, Dict
import asyncio
from openai import AsyncOpenAI

class Vectorizer:
    """向量化器 - 使用 GLM 嵌入"""

    def __init__(
        self,
        api_key: str,
        model: str = "glm-4-flashx",
        batch_size: int = 50,
        base_url: str = "https://api.z.ai/api/coding/paas/v4"
    ):
        self.client = AsyncOpenAI(
            api_key=api_key,
            base_url=base_url
        )
        self.model = model
        self.batch_size = batch_size

    async def embed(self, text: str) -> List[float]:
        """单个文本嵌入"""
        try:
            response = await self.client.embeddings.create(
                model=self.model,
                input=text
            )
            return response.data[0].embedding
        except Exception as e:
            print(f"✗ 嵌入失败: {text[:50]}... - {e}")
            return [0.0] * 1536  # 默认零向量

    async def embed_batch(self, texts: List[str]) -> List[List[float]]:
        """批量嵌入"""
        results = []
        total = len(texts)

        print(f"⏳ 批量嵌入中: {total} 条文本")

        for i in range(0, total, self.batch_size):
            batch = texts[i:i + self.batch_size]

            try:
                response = await self.client.embeddings.create(
                    model=self.model,
                    input=batch
                )
                results.extend([d.embedding for d in response.data])
                print(f"✓ 进度: {i + len(batch)}/{total}")

            except Exception as e:
                print(f"✗ 批量嵌入失败: {e}")
                # 逐条重试
                for text in batch:
                    embedding = await self.embed(text)
                    results.append(embedding)

        print(f"✓ 完成: 共 {len(results)} 个向量")
        return results

    def to_jsonl(self, vectors: List[List[float]], metadata: List[Dict]) -> str:
        """转换为 JSONL 格式"""
        lines = []
        for vec, meta in zip(vectors, metadata):
            lines.append({
                "vector": vec,
                "metadata": meta
            })
        return '\n'.join(json.dumps(line, ensure_ascii=False) for line in lines)


# 使用示例
import json
import asyncio

async def main():
    vectorizer = Vectorizer(
        api_key=os.getenv("ZAI_API_KEY"),
        model="glm-4-flashx"
    )

    test_texts = [
        "A股医药行业龙头公司持续推出创新药物",
        "人工智能在医疗领域的应用前景广阔",
        "新能源汽车产业链正在快速成长"
    ]

    vectors = await vectorizer.embed_batch(test_texts)

    # 保存为 JSONL
    metadata = [{"id": i, "text": t[:50] + "..."} for i, t in enumerate(test_texts)]
    jsonl_data = vectorizer.to_jsonl(vectors, metadata)

    with open("vectors.jsonl", "w", encoding="utf-8") as f:
        f.write(jsonl_data)

    print(f"✓ 保存到 vectors.jsonl ({len(vectors)} 条)")


if __name__ == "__main__":
    asyncio.run(main())
```

---

### 步骤 4: 索引构建

```python
# index_builder.py
import chromadb
from chromadb.config import Settings
from typing import List, Dict
import json
from pathlib import Path

class IndexBuilder:
    """索引构建器 - 使用 ChromaDB"""

    def __init__(self, persist_dir: str = "./chroma_index"):
        self.persist_dir = Path(persist_dir)
        self.persist_dir.mkdir(exist_ok=True)

        # 初始化 ChromaDB
        self.client = chromadb.PersistentClient(
            path=str(self.persist_dir),
            settings=Settings(
                anonymized_telemetry=False,
                allow_reset=True
            )
        )

        # 创建集合
        self.collection = self.client.get_or_create_collection(
            name="stock_research",
            metadata={"hnsw:space": "cosine"}
        )

    def add_documents(self, texts: List[str], metadata: List[Dict]):
        """添加文档到索引"""
        if not texts:
            print("✓ 没有文档需要添加")
            return

        print(f"⏳ 添加 {len(texts)} 个文档到索引...")

        # 准备数据
        ids = [f"doc_{i}" for i in range(len(texts))]
        embeddings = self._generate_embeddings(texts)  # 需要外部提供嵌入

        # 添加到 ChromaDB
        self.collection.add(
            ids=ids,
            embeddings=embeddings,
            documents=texts,
            metadatas=metadata
        )

        print(f"✓ 成功添加 {len(texts)} 个文档")

    def search(self, query: str, top_k: int = 10) -> List[Dict]:
        """搜索"""
        # 生成查询嵌入
        query_embedding = self._generate_embeddings([query])[0]

        # 搜索
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=top_k
        )

        # 格式化结果
        return self._format_results(results)

    def _generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        """生成嵌入（需要外部提供嵌入 API）"""
        # 这里应该调用向量化 API
        # 示例：返回零向量
        return [[0.0] * 1536 for _ in texts]

    def _format_results(self, results: Dict) -> List[Dict]:
        """格式化结果"""
        formatted = []
        for i, doc in enumerate(results["documents"][0]):
            formatted.append({
                "text": doc,
                "score": 1 - results["distances"][0][i],  # 距离转相似度
                "metadata": results["metadatas"][0][i]
            })
        return formatted

    def stats(self):
        """获取索引统计"""
        count = self.collection.count()
        print(f"索引统计: {count} 个文档")
        return count


# 使用示例
if __name__ == "__main__":
    builder = IndexBuilder(persist_dir="./stock_research_chroma")

    # 添加文档
    texts = [
        "A股医药行业龙头公司持续推出创新药物",
        "人工智能在医疗领域的应用前景广阔",
        "新能源汽车产业链正在快速成长"
    ]

    metadata = [
        {"company": "恒瑞医药", "industry": "医药"},
        {"company": "字节跳动", "industry": "互联网"},
        {"company": "比亚迪", "industry": "汽车"}
    ]

    builder.add_documents(texts, metadata)

    # 搜索
    results = builder.search("创新药物研发", top_k=2)
    for r in results:
        print(f"[{r['score']:.2f}] {r['text']}")
        print(f"  {r['metadata']}")
```

---

### 步骤 5: 混合检索

```python
# hybrid_search.py
import chromadb
from rank_bm25 import BM25Okapi
from typing import List, Dict
import jieba

class HybridSearcher:
    """混合检索器 - 向量 + BM25"""

    def __init__(self, vector_collection, bm25_index):
        self.vector_collection = vector_collection
        self.bm25_index = bm25_index

    def search(
        self,
        query: str,
        top_k: int = 10,
        vector_weight: float = 0.7,
        bm25_weight: float = 0.3
    ) -> List[Dict]:
        """混合检索"""
        # 1. 向量搜索
        vector_results = self._vector_search(query, top_k=int(top_k * 1.5))

        # 2. BM25 搜索
        bm25_results = self._bm25_search(query, top_k=int(top_k * 1.5))

        # 3. 结果合并和重排序
        combined = self._merge_results(
            vector_results,
            bm25_results,
            top_k=top_k,
            vector_weight=vector_weight,
            bm25_weight=bm25_weight
        )

        return combined

    def _vector_search(self, query: str, top_k: int) -> List[Dict]:
        """向量搜索"""
        query_embedding = self._get_embedding([query])[0]

        results = self.vector_collection.query(
            query_embeddings=[query_embedding],
            n_results=top_k
        )

        return self._format_results(results, method="vector")

    def _bm25_search(self, query: str, top_k: int) -> List[Dict]:
        """BM25 搜索"""
        # 中文分词
        tokens = jieba.lcut(query)

        # 搜索
        scores = self.bm25_index.get_scores(tokens)
        top_indices = scores.argsort()[::-1][:top_k]

        return self._format_bm25_results(top_indices, scores, top_k)

    def _merge_results(
        self,
        vector_results: List[Dict],
        bm25_results: List[Dict],
        top_k: int,
        vector_weight: float,
        bm25_weight: float
    ) -> List[Dict]:
        """合并结果"""
        combined = {}

        # 合并结果并计算加权分数
        for r in vector_results:
            combined[r["id"]] = {
                "text": r["text"],
                "score": r["score"] * vector_weight,
                "metadata": r["metadata"],
                "methods": {"vector": r["score"]}
            }

        for r in bm25_results:
            if r["id"] in combined:
                combined[r["id"]]["score"] += r["score"] * bm25_weight
                combined[r["id"]]["methods"]["bm25"] = r["score"]
            else:
                combined[r["id"]] = {
                    "text": r["text"],
                    "score": r["score"] * bm25_weight,
                    "metadata": r["metadata"],
                    "methods": {"bm25": r["score"]}
                }

        # 排序并返回 top_k
        sorted_results = sorted(
            combined.values(),
            key=lambda x: x["score"],
            reverse=True
        )

        return sorted_results[:top_k]

    def _format_results(self, results: Dict, method: str) -> List[Dict]:
        """格式化向量结果"""
        formatted = []
        for i, doc in enumerate(results["documents"][0]):
            formatted.append({
                "id": results["ids"][0][i],
                "text": doc,
                "score": 1 - results["distances"][0][i],  # 余弦距离转相似度
                "metadata": results["metadatas"][0][i],
                "method": method
            })
        return formatted

    def _format_bm25_results(self, indices: List[int], scores: List[float], top_k: int) -> List[Dict]:
        """格式化 BM25 结果"""
        formatted = []
        for i in indices[:top_k]:
            formatted.append({
                "id": i,
                "text": self.bm25_index.get_doc(i),
                "score": float(scores[i]),
                "metadata": {},
                "method": "bm25"
            })
        return formatted

    def _get_embedding(self, texts: List[str]) -> List[List[float]]:
        """获取嵌入（需要外部提供嵌入 API）"""
        # 这里应该调用嵌入 API
        return [[0.0] * 1536 for _ in texts]


# 使用示例
if __name__ == "__main__":
    # 初始化
    vector_client = chromadb.PersistentClient(path="./chroma_index")
    vector_collection = vector_client.get_collection("stock_research")

    # 创建 BM25 索引
    texts = [doc for doc in vector_collection.get()["documents"]]
    tokenized_corpus = [list(jieba.lcut(doc)) for doc in texts]
    bm25 = BM25Okapi(tokenized_corpus)

    searcher = HybridSearcher(vector_collection, bm25)

    # 搜索
    results = searcher.search("医药创新药物研发", top_k=5)
    for r in results:
        print(f"[{r['score']:.3f}] ({r['method']}) {r['text']}")
```

---

## 📈 性能优化方案

### 1. 批处理与并行

```python
# parallel_processor.py
from concurrent.futures import ThreadPoolExecutor
import asyncio

def parallel_process(data: List, func, workers: int = 4):
    """并行处理"""
    with ThreadPoolExecutor(max_workers=workers) as executor:
        results = list(executor.map(func, data))
    return results

def async_parallel_process(data: List, func, max_concurrent: int = 10):
    """异步并行处理"""
    semaphore = asyncio.Semaphore(max_concurrent)

    async def limited_func(item):
        async with semaphore:
            return await func(item)

    return asyncio.run(asyncio.gather(*[limited_func(item) for item in data]))
```

### 2. 缓存策略

```python
# cache_manager.py
from functools import lru_cache
import hashlib
import json

class CacheManager:
    """缓存管理器"""

    def __init__(self, cache_file: str = "query_cache.json"):
        self.cache_file = cache_file
        self.cache = self._load_cache()

    def _load_cache(self) -> Dict:
        """加载缓存"""
        try:
            with open(self.cache_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            return {}

    def _get_key(self, query: str) -> str:
        """生成缓存键"""
        return hashlib.md5(query.encode()).hexdigest()

    def get(self, query: str) -> List[Dict]:
        """获取缓存结果"""
        key = self._get_key(query)
        return self.cache.get(key, [])

    def set(self, query: str, results: List[Dict]):
        """设置缓存"""
        key = self._get_key(query)
        self.cache[key] = results
        self._save_cache()

    def _save_cache(self):
        """保存缓存"""
        with open(self.cache_file, 'w', encoding='utf-8') as f:
            json.dump(self.cache, f, ensure_ascii=False)

    @lru_cache(maxsize=10000)
    def cached_search(self, query: str, *args, **kwargs) -> List[Dict]:
        """带缓存的搜索"""
        results = self.search(query, *args, **kwargs)
        self.set(query, results)
        return results
```

### 3. 数据预处理流水线

```python
# pipeline.py
from typing import Callable
import time

class ProcessingPipeline:
    """处理流水线"""

    def __init__(self):
        self.steps = []

    def add_step(self, name: str, func: Callable, desc: str = ""):
        """添加步骤"""
        self.steps.append({
            "name": name,
            "func": func,
            "desc": desc or name
        })

    def run(self, input_data):
        """执行流水线"""
        current = input_data

        for step in self.steps:
            start = time.time()
            print(f"⏳ 执行步骤: {step['desc']}")

            try:
                current = step['func'](current)
                elapsed = time.time() - start
                print(f"✓ 完成: {elapsed:.2f}s")

            except Exception as e:
                print(f"✗ 失败: {e}")
                raise

        return current

    def get_summary(self) -> Dict:
        """获取步骤摘要"""
        return {
            "steps": [
                {
                    "name": s["name"],
                    "desc": s["desc"]
                }
                for s in self.steps
            ]
        }
```

---

## 🚀 完整管道实现

```python
# complete_pipeline.py
from pathlib import Path
from pdf_parser import PDFParser
from text_cleaner import TextCleaner
from vectorizer import Vectorizer
from index_builder import IndexBuilder
from cache_manager import CacheManager

class StockResearchRAGPipeline:
    """股票研报 RAG 完整管道"""

    def __init__(
        self,
        data_dir: str,
        output_dir: str = "./output",
        vectorizer: Vectorizer = None
    ):
        self.data_dir = Path(data_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)

        # 初始化各组件
        self.parser = PDFParser(chunk_size=1000, chunk_overlap=50)
        self.cleaner = TextCleaner()
        self.index_builder = IndexBuilder(persist_dir=str(output_dir / "chroma_index"))
        self.cache = CacheManager(cache_file=str(output_dir / "query_cache.json"))
        self.vectorizer = vectorizer

    def build_index(self, rebuild: bool = False):
        """构建索引"""
        if rebuild:
            print("🗑️  清空现有索引...")
            self.index_builder.collection.delete()

        print(f"📂 读取数据目录: {self.data_dir}")

        # 1. 解析 PDF
        raw_chunks = self.parser.parse_directory(self.data_dir)
        print(f"✓ 解析完成: {len(raw_chunks)} 个文本块")

        # 2. 清洗文本
        cleaned_chunks = self.cleaner.clean_batch(raw_chunks)
        print(f"✓ 清洗完成")

        # 3. 过滤空文本
        valid_chunks = [
            c for c in cleaned_chunks
            if len(c["text"]) > 50  # 过滤太短的文本
        ]
        print(f"✓ 过滤完成: {len(valid_chunks)} 个有效块")

        # 4. 向量化
        texts = [c["text"] for c in valid_chunks]
        metadatas = [c["metadata"] for c in valid_chunks]

        if self.vectorizer:
            embeddings = asyncio.run(self.vectorizer.embed_batch(texts))
        else:
            embeddings = [[0.0] * 1536 for _ in texts]

        # 5. 构建索引
        self.index_builder.add_documents(texts, metadatas)

        print(f"\n✅ 索引构建完成!")
        print(f"📊 文档数: {len(texts)}")

    def query(
        self,
        question: str,
        top_k: int = 10,
        use_cache: bool = True
    ) -> List[Dict]:
        """查询"""
        if use_cache:
            cached_results = self.cache.get(question)
            if cached_results:
                print(f"💾 使用缓存结果")
                return cached_results

        results = self.index_builder.search(question, top_k=top_k)

        if use_cache:
            self.cache.set(question, results)

        return results


# 使用示例
async def main():
    pipeline = StockResearchRAGPipeline(
        data_dir="./research_papers"
    )

    # 构建索引
    pipeline.build_index(rebuild=True)

    # 查询
    results = pipeline.query(
        "A股医药行业龙头公司有哪些?",
        top_k=5
    )

    for r in results:
        print(f"\n[{r['score']:.3f}]")
        print(f"文本: {r['text'][:200]}...")
        print(f"元数据: {r['metadata']}")


if __name__ == "__main__":
    asyncio.run(main())
```

---

## 💰 成本优化

### 按需加载 + 分批处理

```python
# incremental_loading.py
class IncrementalIndexBuilder:
    """增量索引构建器"""

    def __init__(self, total_files: int):
        self.total_files = total_files
        self.processed_files = 0

    def build_incremental(
        self,
        files: List[Path],
        batch_size: int = 1000,
        output_dir: str = "./incremental_index"
    ):
        """分批构建索引"""
        for i in range(0, len(files), batch_size):
            batch = files[i:i + batch_size]
            self._process_batch(batch)
            self.processed_files += len(batch)

            progress = (self.processed_files / self.total_files) * 100
            print(f"\n📊 进度: {progress:.1f}% ({self.processed_files}/{self.total_files})")

    def _process_batch(self, batch: List[Path]):
        """处理一批文件"""
        # 解析 + 清洗 + 向量化
        chunks = self.parser.parse_directory(Path(batch[0]).parent)
        cleaned = self.cleaner.clean_batch(chunks)
        texts = [c["text"] for c in cleaned]
        metadatas = [c["metadata"] for c in cleaned]
        embeddings = self.vectorizer.embed_batch(texts)

        # 添加到索引
        self.index_builder.add_documents(texts, metadatas)
```

---

## 📊 监控与日志

```python
# monitoring.py
import logging
from datetime import datetime

class RAGMonitor:
    """RAG 监控"""

    def __init__(self, log_file: str = "rag_monitor.log"):
        self.logger = self._setup_logger(log_file)

    def _setup_logger(self, log_file: str):
        """设置日志"""
        logger = logging.getLogger("RAG")
        logger.setLevel(logging.INFO)

        handler = logging.FileHandler(log_file, encoding="utf-8")
        formatter = logging.Formatter(
            '%(asctime)s | %(levelname)s | %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        handler.setFormatter(formatter)

        logger.addHandler(handler)
        return logger

    def log_step(self, step_name: str, status: str, details: dict = None):
        """记录步骤"""
        message = f"[{step_name}] {status}"
        if details:
            message += f" - {details}"

        if status == "✓":
            self.logger.info(message)
        else:
            self.logger.error(message)

    def log_query(self, query: str, result_count: int, time_taken: float):
        """记录查询"""
        self.logger.info(
            f"查询: {query[:50]}... | 结果: {result_count} | 耗时: {time_taken:.2f}s"
        )

    def log_cost(self, model: str, input_tokens: int, output_tokens: int, cost: float):
        """记录成本"""
        self.logger.info(
            f"模型: {model} | 输入: {input_tokens} | 输出: {output_tokens} | 费用: ${cost:.4f}"
        )

    def print_stats(self, stats: dict):
        """打印统计信息"""
        self.logger.info("\n" + "=" * 50)
        self.logger.info("统计信息:")
        for k, v in stats.items():
            self.logger.info(f"  {k}: {v}")
        self.logger.info("=" * 50 + "\n")
```

---

## 🎯 部署建议

### 1. 数据预处理 (一次性)

```bash
# 在低峰期执行
python pdf_parser.py --input ./research_papers --output ./processed
```

### 2. 索引构建 (批量)

```bash
# 分批构建，避免内存溢出
python index_builder.py --batch-size 10000
```

### 3. 查询服务 (长期运行)

```bash
# 启动 FastAPI 服务
uvicorn rag_server:app --host 0.0.0.0 --port 8000
```

---

## 📝 总结

| 组件 | 推荐方案 | 估算成本 |
|---|---|---|
| PDF 解析 | pdfplumber | 免费 |
| 文本清洗 | jieba + 正则 | 免费 |
| 向量嵌入 | GLM-4-flashx | ~¥0.001/1000字 |
| 索引存储 | ChromaDB | 本地免费 |
| 查询服务 | FastAPI + AsyncIO | 低成本 |

**总成本估算**：
- 100万份报告 → ~800-1000万中文字
- 嵌入成本 → ~¥800-1000（使用 flashx 模型）
- 硬件要求 → 16GB RAM, SSD

需要我详细展开某个具体模块的实现吗？
