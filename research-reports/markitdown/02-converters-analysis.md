# MarkItDown - 核心转换器分析

**研究阶段**: Phase 2  
**研究日期**: 2026-03-01  
**研究方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能

---

## 📊 转换器概览

### 转换器架构

MarkItDown 采用**策略模式**，每个文件格式对应一个独立的转换器：

```
DocumentConverter (抽象基类)
├── PdfConverter (~500 行)
├── DocxConverter (~60 行)
├── XlsxConverter (~100 行)
├── XlsConverter (~80 行)
├── PptxConverter (~240 行)
├── HtmlConverter (~70 行)
├── ImageConverter (~70 行)
├── AudioConverter (~80 行)
└── ... (25+ 个转换器)
```

---

## 📄 PdfConverter 深度分析

### 核心定位

**PdfConverter** 是最复杂的转换器（~500 行），负责将 PDF 文档转换为 Markdown。

**文件位置**: `packages/markitdown/src/markitdown/converters/_pdf_converter.py`

---

### 依赖管理

**依赖库**:
- `pdfminer.six` - PDF 文本提取
- `pdfplumber` - PDF 布局和表格提取

**依赖检查**:
```python
# _pdf_converter.py:41-46
_dependency_exc_info = None
try:
    import pdfminer
    import pdfminer.high_level
    import pdfplumber
except ImportError:
    _dependency_exc_info = sys.exc_info()
```

**错误处理**:
```python
# _pdf_converter.py:362-374
def convert(self, file_stream, stream_info, **kwargs):
    if _dependency_exc_info is not None:
        raise MissingDependencyException(
            MISSING_DEPENDENCY_MESSAGE.format(
                converter=type(self).__name__,
                extension=".pdf",
                feature="pdf",
            )
        )
```

---

### 双层提取策略

**核心设计**: PdfConverter 采用**双层提取策略**，优先使用 pdfplumber，失败时回退到 pdfminer。

**提取流程**:
```
1. 尝试 pdfplumber 提取
   ↓
   ├─ 成功 → 使用 pdfplumber 结果
   └─ 失败 → 回退到第二层
       ↓
2. 使用 pdfminer 提取
   ↓
3. 后处理（MasterFormat 合并）
```

**核心代码**:
```python
# _pdf_converter.py:417-461
def convert(self, file_stream, stream_info, **kwargs):
    markdown_chunks = []
    pdf_bytes = io.BytesIO(file_stream.read())
    
    try:
        # 第一层：pdfplumber 提取
        with pdfplumber.open(pdf_bytes) as pdf:
            for page in pdf.pages:
                # 尝试基于单词位置的提取
                page_content = _extract_form_content_from_words(page)
                
                if page_content is None:
                    # 不是表单样式，使用基本提取
                    text = page.extract_text()
                    if text and text.strip():
                        markdown_chunks.append(text.strip())
                else:
                    # 表单样式提取成功
                    markdown_chunks.append(page_content)
        
        # 如果大部分是纯文本，使用 pdfminer
        if plain_pages > form_pages:
            pdf_bytes.seek(0)
            markdown = pdfminer.high_level.extract_text(pdf_bytes)
        else:
            markdown = "\n\n".join(markdown_chunks)
    
    except Exception:
        # 回退到 pdfminer
        pdf_bytes.seek(0)
        markdown = pdfminer.high_level.extract_text(pdf_bytes)
    
    # 后处理
    markdown = _merge_partial_numbering_lines(markdown)
    return DocumentConverterResult(markdown=markdown)
```

---

### 表单样式提取（核心创新）

**问题**: 传统 PDF 提取忽略文档结构（如表单、表格）

**解决方案**: `_extract_form_content_from_words()` 函数分析单词位置，识别表单/表格结构。

**核心算法**:

#### 1. 单词位置分析

```python
# _pdf_converter.py:123-175
def _extract_form_content_from_words(page):
    # 提取单词及其坐标
    words = page.extract_words(
        keep_blank_chars=True,
        x_tolerance=3,      # X 方向容差 3pt
        y_tolerance=3       # Y 方向容差 3pt
    )
    
    # 按 Y 坐标分组（行）
    y_tolerance = 5
    rows_by_y = {}
    for word in words:
        y_key = round(word["top"] / y_tolerance) * y_tolerance
        rows_by_y.setdefault(y_key, []).append(word)
    
    # 分析每行
    for y_key in sorted(rows_by_y.keys()):
        row_words = sorted(rows_by_y[y_key], key=lambda w: w["x0"])
        
        # 计算行宽
        first_x0 = row_words[0]["x0"]
        last_x1 = row_words[-1]["x1"]
        line_width = last_x1 - first_x0
        
        # 识别列
        x_positions = [w["x0"] for w in row_words]
        x_groups = []
        for x in sorted(x_positions):
            if not x_groups or x - x_groups[-1] > 50:
                x_groups.append(x)
        
        # 判断是否为段落
        is_paragraph = line_width > page_width * 0.55 and len(text) > 60
```

---

#### 2. 表格区域识别

**识别标准**:
1. **多列对齐**: 行包含≥3 个不同的 X 位置
2. **列一致性**: 多行共享相同的列边界
3. **短单元格**: 单元格内容≤30 字符（表格特征）
4. **密度检查**: ≤30% 的单元格包含长文本

**代码实现**:
```python
# _pdf_converter.py:191-256
# 收集所有表格样式的 X 位置
all_table_x_positions = []
for info in row_info:
    if info["num_columns"] >= 3 and not info["is_paragraph"]:
        all_table_x_positions.extend(info["x_groups"])

# 计算自适应容差
if gaps and len(gaps) >= 3:
    # 使用 70% 分位数作为阈值
    sorted_gaps = sorted(gaps)
    percentile_70_idx = int(len(sorted_gaps) * 0.70)
    adaptive_tolerance = sorted_gaps[percentile_70_idx]
    adaptive_tolerance = max(25, min(50, adaptive_tolerance))

# 计算全局列边界
global_columns = []
for x in all_table_x_positions:
    if not global_columns or x - global_columns[-1] > adaptive_tolerance:
        global_columns.append(x)

# 检查列密度
if len(global_columns) > 1:
    content_width = global_columns[-1] - global_columns[0]
    avg_col_width = content_width / len(global_columns)
    
    # 列太窄（<30px）可能是密集文本
    if avg_col_width < 30:
        return None  # 不是表格
```

---

#### 3. Markdown 表格生成

**函数**: `_to_markdown_table()`

**实现**:
```python
# _pdf_converter.py:78-119
def _to_markdown_table(table, include_separator=True):
    # 规范化空值
    table = [[cell if cell else "" for cell in row] for row in table]
    
    # 过滤空行
    table = [row for row in table if any(cell.strip() for cell in row)]
    
    # 计算列宽
    col_widths = [max(len(str(cell)) for cell in col) for col in zip(*table)]
    
    def fmt_row(row):
        return "|" + "|".join(str(cell).ljust(width) for cell, width in zip(row, col_widths)) + "|"
    
    if include_separator:
        header, *rows = table
        md = [fmt_row(header)]
        md.append("|" + "|".join("-" * w for w in col_widths) + "|")  # 分隔符
        for row in rows:
            md.append(fmt_row(row))
    else:
        md = [fmt_row(row) for row in table]
    
    return "\n".join(md)
```

**输出示例**:
```markdown
| Product  | Q1   | Q2   | Q3   |
|----------|------|------|------|
| Widget A | $100 | $120 | $150 |
| Widget B | $200 | $220 | $250 |
```

---

### MasterFormat 后处理

**问题**: 某些 PDF（如建筑规范）使用特殊编号格式（`.1`, `.2`），提取后格式丢失

**解决方案**: `_merge_partial_numbering_lines()` 函数合并编号和后续文本

**实现**:
```python
# _pdf_converter.py:14-53
def _merge_partial_numbering_lines(text):
    lines = text.split("\n")
    result_lines = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # 检查是否仅为部分编号（如".1"）
        if PARTIAL_NUMBERING_PATTERN.match(stripped):
            # 查找下一行非空行
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            
            if j < len(lines):
                # 合并编号和下一行
                next_line = lines[j].strip()
                result_lines.append(f"{stripped} {next_line}")
                i = j + 1
            else:
                result_lines.append(line)
                i += 1
        else:
            result_lines.append(line)
            i += 1
    
    return "\n".join(result_lines)
```

**输入**:
```
.1
The intent of this Request for Proposal...
.2
Available information relative to...
```

**输出**:
```
.1 The intent of this Request for Proposal...
.2 Available information relative to...
```

---

## 📝 DocxConverter 分析

### 核心定位

**DocxConverter** 是最简洁的转换器（~60 行），利用 `mammoth` 库将 DOCX 转换为 HTML，再转换为 Markdown。

**文件位置**: `packages/markitdown/src/markitdown/converters/_docx_converter.py`

---

### 依赖管理

**依赖库**:
- `mammoth` - DOCX 转 HTML
- `openpyxl` - DOCX 预处理

**依赖检查**:
```python
# _docx_converter.py:14-21
_dependency_exc_info = None
try:
    import mammoth
except ImportError:
    _dependency_exc_info = sys.exc_info()
```

---

### 转换流程

```
DOCX 文件
    ↓
1. 预处理（pre_process_docx）
    ↓
2. mammoth 转换为 HTML
    ↓
3. HtmlConverter 转换为 Markdown
    ↓
Markdown 输出
```

**核心代码**:
```python
# _docx_converter.py:57-80
def convert(self, file_stream, stream_info, **kwargs):
    if _dependency_exc_info is not None:
        raise MissingDependencyException(...)
    
    style_map = kwargs.get("style_map", None)
    pre_process_stream = pre_process_docx(file_stream)
    
    return self._html_converter.convert_string(
        mammoth.convert_to_html(pre_process_stream, style_map=style_map).value,
        **kwargs,
    )
```

---

### 设计特点

**1. 复用 HtmlConverter**:
- DocxConverter 继承自 HtmlConverter
- 避免重复实现 HTML 转 Markdown 逻辑

**2. 支持样式映射**:
```python
style_map = kwargs.get("style_map", None)
mammoth.convert_to_html(pre_process_stream, style_map=style_map)
```

**3. 流式处理**:
- 无临时文件
- 支持大文件

---

## 📊 XlsxConverter 分析

### 核心定位

**XlsxConverter** 将 Excel 文件（.xlsx/.xls）转换为 Markdown，每个工作表作为一个独立的表格。

**文件位置**: `packages/markitdown/src/markitdown/converters/_xlsx_converter.py`

---

### 依赖管理

**依赖库**:
- `pandas` - Excel 文件读取
- `openpyxl` - XLSX 引擎
- `xlrd` - XLS 引擎

**依赖检查**:
```python
# _xlsx_converter.py:13-27
_xlsx_dependency_exc_info = None
try:
    import pandas as pd
    import openpyxl
except ImportError:
    _xlsx_dependency_exc_info = sys.exc_info()

_xls_dependency_exc_info = None
try:
    import pandas as pd
    import xlrd
except ImportError:
    _xls_dependency_exc_info = sys.exc_info()
```

---

### 转换流程

```
Excel 文件
    ↓
1. pandas 读取所有工作表
    ↓
2. 每个工作表转换为 HTML 表格
    ↓
3. HtmlConverter 转换为 Markdown
    ↓
4. 合并所有工作表（## 工作表名）
    ↓
Markdown 输出
```

**核心代码**:
```python
# _xlsx_converter.py:57-77
def convert(self, file_stream, stream_info, **kwargs):
    if _xlsx_dependency_exc_info is not None:
        raise MissingDependencyException(...)
    
    # 读取所有工作表
    sheets = pd.read_excel(file_stream, sheet_name=None, engine="openpyxl")
    
    md_content = ""
    for s in sheets:
        md_content += f"## {s}\n"
        html_content = sheets[s].to_html(index=False)
        md_content += (
            self._html_converter.convert_string(
                html_content, **kwargs
            ).markdown.strip() + "\n\n"
        )
    
    return DocumentConverterResult(markdown=md_content.strip())
```

**输出示例**:
```markdown
## Sheet1

| Name | Age | City |
|------|-----|------|
| Alice | 30 | New York |
| Bob | 25 | Los Angeles |

## Sheet2

| Product | Price |
|---------|-------|
| Widget | $100 |
| Gadget | $200 |
```

---

### 设计特点

**1. 多工作表支持**:
- 自动遍历所有工作表
- 每个工作表作为独立章节

**2. 复用 HtmlConverter**:
- Excel → HTML → Markdown
- 避免重复实现表格转 Markdown 逻辑

**3. 支持两种格式**:
- XlsxConverter (.xlsx) - 使用 openpyxl 引擎
- XlsConverter (.xls) - 使用 xlrd 引擎

---

## 🎯 转换器对比

| 转换器 | 代码行 | 依赖库 | 复杂度 | 特色功能 |
|--------|--------|--------|--------|---------|
| **PdfConverter** | ~500 行 | pdfminer, pdfplumber | ⭐⭐⭐⭐⭐ | 双层提取、表单识别、表格提取 |
| **DocxConverter** | ~60 行 | mammoth, openpyxl | ⭐⭐ | 样式映射、预处理 |
| **XlsxConverter** | ~100 行 | pandas, openpyxl | ⭐⭐⭐ | 多工作表、HTML 转换 |
| **XlsConverter** | ~80 行 | pandas, xlrd | ⭐⭐ | 旧 Excel 格式支持 |

---

## 📊 设计模式识别

### 1. 依赖检查模式

**所有转换器使用统一的依赖检查模式**:

```python
# 1. 模块级依赖检查
_dependency_exc_info = None
try:
    import some_library
except ImportError:
    _dependency_exc_info = sys.exc_info()

# 2. convert() 方法中检查
def convert(self, file_stream, stream_info, **kwargs):
    if _dependency_exc_info is not None:
        raise MissingDependencyException(...)
```

**优势**:
- ✅ 延迟报错（使用时才报错）
- ✅ 清晰的错误信息
- ✅ 便于调试

---

### 2. 流式处理模式

**所有转换器接受 `BinaryIO`**:

```python
def convert(
    self,
    file_stream: BinaryIO,  # 流式输入
    stream_info: StreamInfo,
    **kwargs: Any,
) -> DocumentConverterResult:
```

**优势**:
- ✅ 无临时文件
- ✅ 支持大文件
- ✅ 内存友好

---

### 3. 复用模式

**Docx/XlsxConverter 复用 HtmlConverter**:

```python
class DocxConverter(HtmlConverter):
    def __init__(self):
        super().__init__()
        self._html_converter = HtmlConverter()
    
    def convert(self, file_stream, stream_info, **kwargs):
        # DOCX → HTML
        html = mammoth.convert_to_html(...)
        # HTML → Markdown
        return self._html_converter.convert_string(html, **kwargs)
```

**优势**:
- ✅ 避免重复实现
- ✅ 代码复用
- ✅ 易于维护

---

## 📝 Phase 2 验收

### 验收标准

| 标准 | 状态 | 说明 |
|------|------|------|
| ✅ 分析 PdfConverter | 完成 | 双层提取 + 表单识别 |
| ✅ 分析 DocxConverter | 完成 | mammoth + HtmlConverter |
| ✅ 分析 XlsxConverter | 完成 | pandas + 多工作表 |
| ✅ 识别设计模式 | 完成 | 依赖检查 + 流式处理 + 复用 |
| ✅ 代码位置索引 | 完成 | 所有引用有源码位置 |

---

## 📝 研究笔记

### 关键发现

1. **PdfConverter 是最复杂的转换器**（~500 行），包含双层提取策略和表单识别
2. **Docx/XlsxConverter 复用 HtmlConverter**，避免重复实现
3. **所有转换器使用统一的依赖检查模式**
4. **所有转换器支持流式处理**（无临时文件）

### 待深入研究

- [ ] PptxConverter 实现（~240 行）
- [ ] ImageConverter 和 AudioConverter（LLM 标注）
- [ ] 性能基准测试
- [ ] 与 textract 详细对比

---

## 🔗 下一步：Phase 3

**目标**: 分析性能优化和质量保障机制

**任务**:
- [ ] 分析流式处理性能
- [ ] 分析错误处理机制
- [ ] 分析测试覆盖
- [ ] 收集性能数据

**产出**: `03-performance-quality.md`

---

**研究日期**: 2026-03-01  
**研究者**: Jarvis  
**方法**: 毛线团研究法 + GSD 流程 + Superpowers 技能
