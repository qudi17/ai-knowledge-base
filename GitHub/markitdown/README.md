# MarkItDown 研究文档

**研究完成日期**：2026-02-28  
**研究方法**：毛线团研究法（Yarn Ball Method）  
**项目 Fork**：https://github.com/qudi17/markitdown.git  
**原始项目**：https://github.com/microsoft/markitdown.git

---

## 📊 项目概览

### 定位

MarkItDown 是一个轻量级 Python 工具，用于将各种文件格式转换为 Markdown，专为 LLM 和文本分析管道设计。

**类似于**：[textract](https://github.com/deanmalmgren/textract)  
**区别**：专注于保留文档结构（标题、列表、表格、链接），而非纯文本提取

### 支持格式

- **文档**：PDF, Word, PowerPoint, Excel
- **图片**：EXIF 元数据 + OCR
- **音频**：EXIF 元数据 + 语音转录
- **Web**：HTML, YouTube URLs, Wikipedia
- **数据格式**：CSV, JSON, XML
- **其他**：ZIP, EPUB, Outlook MSG

### 代码规模

| 指标 | 数值 |
|------|------|
| **Python 文件数** | ~55 个 |
| **核心代码行数** | ~4,600 行 |
| **核心模块** | 25+ 个转换器 |
| **测试文件** | ~10 个 |

---

## 📚 研究文档清单

| # | 文档 | 大小 | 说明 |
|---|------|------|------|
| 1 | [01-markitdown-overview.md](./01-markitdown-overview.md) | 15KB | 项目概览 + 架构分析 |
| 2 | [02-converters-detail.md](./02-converters-detail.md) | 12KB | 25+ 个转换器详解 |
| 3 | [03-pdf-structure-extraction.md](./03-pdf-structure-extraction.md) | 14KB | 📄 PDF 结构识别详解 |
| 4 | [research-summary.md](./research-summary.md) | 17KB | 📝 完整研究总结 |

**总计**：4 篇，~58KB

---

## 🏗️ 系统架构

### 分层架构

```
┌─────────────────────────────────────┐
│          CLI 层                      │
│  markitdown path-to-file.pdf        │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│        MarkItDown 核心               │
│  - convert() 统一入口                │
│  - convert_local()                   │
│  - convert_uri()                     │
│  - convert_stream()                  │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│      Converter 注册表                │
│  - 按优先级排序                      │
│  - 特定格式优先                      │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│        转换器层                      │
│  - PdfConverter                      │
│  - DocxConverter                     │
│  - XlsxConverter                     │
│  - ... (25+ 个转换器)                 │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│        依赖库                        │
│  - pdfminer.six                      │
│  - python-docx                       │
│  - openpyxl                          │
│  - ...                              │
└─────────────────────────────────────┘
```

---

## 💡 核心设计模式

### 1. 责任链模式（Chain of Responsibility）

```python
class MarkItDown:
    def __init__(self):
        self._converters: List[ConverterRegistration] = []
    
    def register_converter(self, converter, priority=0.0):
        self._converters.append(ConverterRegistration(converter, priority))
        self._converters.sort(key=lambda reg: reg.priority)
    
    def convert_stream(self, file_stream, stream_info):
        for reg in self._converters:
            if reg.converter.accepts(file_stream, stream_info):
                try:
                    return reg.converter.convert(file_stream, stream_info)
                except Exception:
                    continue  # 尝试下一个
        
        raise UnsupportedFormatException()
```

**优势**：
- ✅ 易于扩展新格式
- ✅ 自动回退机制
- ✅ 优先级控制

---

### 2. 策略模式（Strategy Pattern）

每个转换器都是独立策略：

```python
class PdfConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info):
        return stream_info.mimetype == "application/pdf"
    
    def convert(self, file_stream, stream_info):
        # 使用 pdfminer.six 转换

class DocxConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info):
        return stream_info.extension == ".docx"
    
    def convert(self, file_stream, stream_info):
        # 使用 python-docx 转换
```

---

### 3. 流式处理模式

```python
def convert_stream(self, file_stream: BinaryIO, stream_info: StreamInfo):
    """
    从流中读取并转换，不创建临时文件
    
    关键设计：
    1. 接受 file-like object
    2. 支持 seek(), tell(), read()
    3. 转换器可以读取流，但必须重置位置
    """
    
    # 检测文件类型
    if stream_info is None:
        stream_info = self._detect_stream_info(file_stream)
    
    # 尝试所有转换器
    for reg in self._converters:
        if reg.converter.accepts(file_stream, stream_info):
            file_stream.seek(0)  # 重置位置
            return reg.converter.convert(file_stream, stream_info)
```

**优势**：
- ✅ 无临时文件
- ✅ 支持大文件
- ✅ 内存友好

---

## 📄 PDF 处理详解

### 结构识别机制

**双层提取策略**：
1. **第一层**：pdfplumber（基于单词位置）
2. **第二层**：pdfminer.six（纯文本回退）

**核心算法**：
- 单词位置分析
- 表格区域识别
- 段落 vs 表格分类

### 表格提取

**识别标准**：
1. 多列对齐（≥3 列）
2. 列一致性（多行共享列边界）
3. 短单元格（≤30 字符）
4. 密度检查（≤30% 长单元格）

**输出格式**：
```markdown
| Product  | Q1   | Q2   | Q3   |
|----------|------|------|------|
| Widget A | $100 | $120 | $150 |
| Widget B | $200 | $220 | $250 |
```

### 图表处理

**当前能力**：
- ✅ 提取图表标题
- ✅ 提取图表说明文字
- ✅ 提取图表中的数据表格
- ❌ 不提取图表图像本身

---

## 🎯 使用示例

### 基本用法

```python
from markitdown import MarkItDown

md = MarkItDown()

# 本地文件
result = md.convert("document.pdf")
print(result.markdown)
print(result.title)

# URL
result = md.convert("https://example.com/document.pdf")

# 二进制流
with open("document.pdf", "rb") as f:
    result = md.convert(f)
```

### 高级用法

```python
# 使用 Document Intelligence（Azure）
md = MarkItDown(
    docintel_endpoint="https://your-resource.cognitiveservices.azure.com/",
    docintel_credential=credential,
    docintel_file_types=["pdf", "docx", "xlsx"]
)

# 使用 LLM 标注图片
md = MarkItDown(
    llm_client=openai_client,
    llm_model="gpt-4o",
    llm_prompt="Describe this image in detail"
)

# 启用插件
md.enable_plugins()
```

---

## 🔗 相关资源

### 官方资源
- **GitHub**: https://github.com/qudi17/markitdown
- **PyPI**: https://pypi.org/project/markitdown/
- **MCP Server**: https://github.com/qudi17/markitdown/tree/main/packages/markitdown-mcp

### 技术参考
- **pdfplumber**: https://github.com/jsvine/pdfplumber
- **pdfminer.six**: https://github.com/pdfminer/pdfminer.six
- **markdownify**: https://github.com/matthewwithanm/python-markdownify

### 研究方法论
- **毛线团研究法**: [../research-methodology.md](../research-methodology.md)
- **MemoryBear 研究**: [../MemoryBear/research-summary.md](../MemoryBear/research-summary.md)
- **nanobot 研究**: [../nanobot/research-summary.md](../nanobot/research-summary.md)

---

**研究状态**：✅ **完成**  
**研究质量**：✅ **所有结论基于实际代码**  
**可复用性**：✅ **方法论适用于任何 GitHub 项目**

**研究人**：Jarvis  
**日期**：2026-02-28  
**方法**：毛线团研究法（Yarn Ball Method）
