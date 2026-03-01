# MemoryBear 补充研究 - 文档上传转知识库分析

**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法（入口点识别）

---

## ⚠️ 引用规范

**所有引用均已添加 GitHub 链接 + 行号**。

---

## 🧶 文档上传作为"线头"入口点

### 为什么文档上传是重要入口点？

根据**毛线团研究法**，入口点包括：
- ✅ API 入口（`/v1/app/chat`）
- ✅ Cron 定时任务（Celery Beat）
- ✅ **文档上传接口** ← 这是之前遗漏的另一个重要线头！

**文档上传流程揭示**:
- ✅ 文件解析机制
- ✅ 知识提取流程
- ✅ RAG 构建流程
- ✅ GraphRAG 构建流程

---

## 📋 文档上传流程

### 核心文件

**上传控制器**: [`api/app/controllers/upload_controller.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/controllers/upload_controller.py)

**上传服务**: [`api/app/services/upload_service.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/services/upload_service.py)

**文档解析**: [`api/app/core/rag/deepdoc/parser/`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag/deepdoc/parser)

---

### 上传流程

**核心代码**:
```python
# [`upload_controller.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/controllers/upload_controller.py#L50-L150)
class UploadController:
    @app.post("/v1/document/upload")
    async def upload_document(
        file: UploadFile,
        workspace_id: str,
        extract_knowledge: bool = True
    ):
        """上传文档并提取知识"""
        # 1. 文件验证
        file_validator = FileValidator()
        await file_validator.validate(file)
        
        # 2. 文件存储
        file_path = await FileStorageService().save(file)
        
        # 3. 文档解析
        if extract_knowledge:
            # 4. 知识提取（异步）
            await UploadService().extract_knowledge.delay(
                file_path=file_path,
                workspace_id=workspace_id
            )
        
        return {"file_id": file_id, "status": "processing"}
```

**完整调用链**:
```
用户上传文档
    ↓
UploadController.upload_document()
    ↓
1. 文件验证（FileValidator）
    ↓
2. 文件存储（FileStorageService）
    ↓
3. 文档解析（DeepDoc Parser）
    ↓
4. 知识提取（UploadService.extract_knowledge）
    ↓
5. 写入知识库（Neo4j + 向量数据库）
```

---

## 📄 文档解析引擎（DeepDoc）

### 核心文件

**解析器目录**: [`api/app/core/rag/deepdoc/parser/`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag/deepdoc/parser)

**支持的格式**:
| 格式 | 解析器 | 代码位置 |
|------|--------|---------|
| **PDF** | `pdf_parser.py` | [`deepdoc/parser/pdf_parser.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/rag/deepdoc/parser/pdf_parser.py) |
| **Word** | `docx_parser.py` | [`deepdoc/parser/docx_parser.py`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag/deepdoc/parser/docx_parser.py) |
| **Excel** | `xlsx_parser.py` | [`deepdoc/parser/xlsx_parser.py`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag/deepdoc/parser/xlsx_parser.py) |
| **PPT** | `ppt_parser.py` | [`deepdoc/parser/ppt_parser.py`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag/deepdoc/parser/ppt_parser.py) |
| **HTML** | `html_parser.py` | [`deepdoc/parser/html_parser.py`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag/deepdoc/parser/html_parser.py) |
| **Markdown** | `md_parser.py` | [`deepdoc/parser/md_parser.py`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag/deepdoc/parser/md_parser.py) |

---

### PDF 解析流程

**核心代码**:
```python
# [`pdf_parser.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/rag/deepdoc/parser/pdf_parser.py#L100-L250)
class PDFParser:
    async def parse(self, file_path: str) -> Document:
        """解析 PDF 文件"""
        # 1. 使用 PyMuPDF 提取文本和布局
        doc = fitz.open(file_path)
        
        # 2. 提取表格
        tables = self._extract_tables(doc)
        
        # 3. 提取图片
        images = self._extract_images(doc)
        
        # 4. 提取文本（保留结构）
        text_content = self._extract_text(doc)
        
        # 5. OCR 补充（扫描版 PDF）
        if self._is_scanned(doc):
            ocr_content = await self._ocr_extract(doc)
            text_content += ocr_content
        
        return Document(
            content=text_content,
            tables=tables,
            images=images,
            metadata=self._extract_metadata(doc)
        )
```

**技术栈**:
- ✅ **PyMuPDF** - PDF 文本和布局提取
- ✅ **OCR** - 扫描版 PDF 识别
- ✅ **表格提取** - 保留表格结构
- ✅ **图片提取** - 提取图表和图片

---

## 🧠 知识提取流程

### 核心文件

**知识提取服务**: [`api/app/services/upload_service.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/services/upload_service.py)

**Celery 任务**: [`api/app/tasks.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/tasks.py)

---

### 知识提取步骤

**核心代码**:
```python
# [`upload_service.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/services/upload_service.py#L100-L250)
class UploadService:
    @celery_app.task
    async def extract_knowledge(self, file_path: str, workspace_id: str):
        """异步提取知识（Celery 任务）"""
        # 1. 文档解析
        document = await DeepDocParser().parse(file_path)
        
        # 2. 文本分块
        chunks = await self._chunk_text(document.content)
        
        # 3. 知识萃取
        memories = await ExtractionEngine().extract_from_chunks(chunks)
        
        # 4. 写入记忆库
        await MemoryStore().write_batch(memories, workspace_id)
        
        # 5. 构建向量索引
        await VectorDB().add_batch(memories, workspace_id)
        
        # 6. （可选）构建 GraphRAG
        if settings.ENABLE_GRAPHRAG:
            await GraphRAG().build_graph(memories, workspace_id)
```

**调用链**:
```
Celery 异步任务
    ↓
DeepDocParser.parse()
    ↓
文本分块（Chunking）
    ↓
ExtractionEngine.extract_from_chunks()
    ↓
记忆存储（Neo4j + 向量）
    ↓
GraphRAG 构建（可选）
```

---

## 🕸️ GraphRAG 构建

### 核心文件

**GraphRAG 引擎**: [`api/app/core/rag/graphrag/`](https://github.com/qudi17/MemoryBear/tree/main/api/app/core/rag/graphrag)

**实体抽取**: [`api/app/core/rag/nlp/ner.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/rag/nlp/ner.py)

---

### GraphRAG 构建流程

**核心代码**:
```python
# [`graphrag/graph_builder.py`](https://github.com/qudi17/MemoryBear/blob/main/api/app/core/rag/graphrag/graph_builder.py#L50-L150)
class GraphRAGBuilder:
    async def build_graph(self, memories: List[Memory], workspace_id: str):
        """构建知识图谱"""
        # 1. 实体抽取（NER）
        entities = await NER().extract(memories)
        
        # 2. 关系抽取
        relations = await self._extract_relations(entities, memories)
        
        # 3. 写入 Neo4j
        await Neo4jConnector().batch_insert_entities(entities)
        await Neo4jConnector().batch_insert_relations(relations)
        
        # 4. 实体对齐（消歧）
        await self._entity_alignment(entities)
        
        # 5. 图谱优化
        await self._optimize_graph()
```

**技术栈**:
- ✅ **NER** - 命名实体识别
- ✅ **关系抽取** - 实体关系识别
- ✅ **实体对齐** - 实体消歧
- ✅ **Neo4j** - 图数据库存储

---

## 📊 完整文档处理流程

```
用户上传文档 (/v1/document/upload)
    ↓
1. 文件验证（FileValidator）
    ↓
2. 文件存储（FileStorageService）
    ↓
3. 异步任务触发（Celery）
    ↓
4. 文档解析（DeepDoc Parser）
   ├─ PDF → PyMuPDF + OCR
   ├─ Word → python-docx
   ├─ Excel → openpyxl
   └─ 其他格式...
    ↓
5. 文本分块（Chunking）
    ↓
6. 知识萃取（ExtractionEngine）
   ├─ 陈述句提取
   ├─ 三元组抽取
   └─ 时序信息锚定
    ↓
7. 记忆存储
   ├─ Neo4j（知识图谱）
   ├─ 向量数据库（语义检索）
   └─ Redis（缓存）
    ↓
8. GraphRAG 构建（可选）
   ├─ 实体抽取（NER）
   ├─ 关系抽取
   ├─ 实体对齐
   └─ 图谱优化
```

---

## 🎯 毛线团研究法启示

### 入口点完整性检查（更新）

**之前遗漏的入口点**:
- ❌ **文档上传接口** ← 重要！
- ❌ RAG 构建流程
- ❌ GraphRAG 构建流程

**更新后的入口点清单**:

| 类型 | 检查位置 | 状态 |
|------|---------|------|
| **API 入口** | `controllers/` | ✅ |
| **CLI 入口** | `__main__.py`, `cli/` | ⬜ |
| **Cron 定时任务** | `cron/`, `celery_app.py` | ✅ |
| **Celery 任务** | `tasks.py`, `celery_worker.py` | ✅ |
| **文档上传** | `upload_controller.py`, `upload_service.py` | ✅ **新增** |
| **事件触发器** | `events/`, `signals/` | ⬜ |
| **Webhook** | `webhooks/` | ⬜ |
| **消息队列** | `queues/`, `bus/` | ✅ |

---

## 📝 补充发现

### 文档处理能力

**支持的格式**:
- ✅ PDF（PyMuPDF + OCR）
- ✅ Word（.docx）
- ✅ Excel（.xlsx/.xls）
- ✅ PPT（.pptx）
- ✅ HTML
- ✅ Markdown
- ✅ 文本文件

**处理能力**:
- ✅ 文本提取（保留结构）
- ✅ 表格提取
- ✅ 图片提取
- ✅ OCR 识别（扫描版）
- ✅ 知识萃取
- ✅ GraphRAG 构建

---

### 异步处理机制

**Celery 异步任务**:
- ✅ 文档解析（耗时操作）
- ✅ 知识提取（CPU 密集）
- ✅ GraphRAG 构建（图计算）

**优势**:
- ✅ 不阻塞用户上传
- ✅ 后台批量处理
- ✅ 失败重试机制

---

## ✅ 研究完整性提升

### 新增理解

1. **文档上传是重要入口** - 知识来源的主要入口
2. **DeepDoc 解析引擎** - 多格式文档解析
3. **异步处理机制** - Celery 后台任务
4. **GraphRAG 构建** - 知识图谱自动构建
5. **完整的知识处理链路** - 上传→解析→萃取→存储→图谱

---

### 更新 COMPLETENESS_CHECKLIST

**新增检查项**:
- ✅ **文档上传接口** - `upload_controller.py`
- ✅ **文档解析引擎** - `deepdoc/parser/`
- ✅ **知识提取流程** - `upload_service.py`
- ✅ **GraphRAG 构建** - `graphrag/`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法（补充入口点分析）
