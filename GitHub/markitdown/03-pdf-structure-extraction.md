# MarkItDown - PDF 结构识别与表格图表提取详解

**研究日期**：2026-02-28  
**研究内容**：PDF 结构识别、表格提取、图表处理机制  
**核心文件**：`converters/_pdf_converter.py` (~500 行)

---

## 📊 总体架构

### 依赖库

MarkItDown 使用两个主要库处理 PDF：

| 库 | 用途 | 版本 |
|---|---|---|
| **pdfplumber** | 主要提取引擎 | 最新版 |
| **pdfminer.six** | 备用提取引擎 | 最新版 |

**选择逻辑**：
```python
try:
    import pdfplumber  # 首选
    import pdfminer
except ImportError:
    # 缺少依赖时抛出异常
    raise MissingDependencyException(...)
```

---

## 🏗️ PDF 结构识别机制

### 1. 双层提取策略

MarkItDown 采用**双层提取策略**：

```
第一层：pdfplumber 提取
    ↓
    ├─ 成功 → 使用 pdfplumber 结果
    └─ 失败 → 回退到第二层
        ↓
第二层：pdfminer.six 提取
    ↓
    └─ 返回纯文本
```

**代码实现**：
```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L467-L507
try:
    with pdfplumber.open(pdf_bytes) as pdf:
        for page in pdf.pages:
            # 第一层：尝试基于单词位置的提取
            page_content = _extract_form_content_from_words(page)
            
            if page_content is None:
                # 不是表单样式，使用基本提取
                plain_pages += 1
                text = page.extract_text()
            else:
                # 表单样式提取成功
                form_pages += 1
                markdown_chunks.append(page_content)
    
    # 如果大部分是纯文本，使用 pdfminer 获得更好的文本处理
    if plain_pages > form_pages:
        markdown = pdfminer.high_level.extract_text(pdf_bytes)
    else:
        markdown = "\n\n".join(markdown_chunks)

except Exception:
    # 回退到 pdfminer
    markdown = pdfminer.high_level.extract_text(pdf_bytes)
```

---

### 2. 结构识别核心算法

#### 2.1 单词位置分析

**关键函数**：`_extract_form_content_from_words(page)`

**原理**：
1. 提取页面上所有单词及其坐标
2. 按 Y 坐标分组（行）
3. 分析每行的 X 坐标分布（列）
4. 识别表格区域 vs 段落区域

**代码实现**：
```python
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

#### 2.2 表格区域识别

**识别标准**：
1. **多列对齐**：行包含≥3 个不同的 X 位置
2. **列一致性**：多行共享相同的列边界
3. **短单元格**：单元格内容≤30 字符（表格特征）
4. **密度检查**：≤30% 的单元格包含长文本

**代码实现**：
```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L191-L256
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

#### 2.3 表格行分类

**判断逻辑**：
```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L259-L281
for info in row_info:
    if info["is_paragraph"]:
        info["is_table_row"] = False
        continue
    
    # 部分编号（如".1", ".2"）是列表项，不是表格行
    if info["has_partial_numbering"]:
        info["is_table_row"] = False
        continue
    
    # 计算与全局列的对齐
    aligned_columns = set()
    for word in info["words"]:
        word_x = word["x0"]
        for col_idx, col_x in enumerate(global_columns):
            if abs(word_x - col_x) < 40:
                aligned_columns.add(col_idx)
                break
    
    # 如果与≥2 个列对齐，则是表格行
    info["is_table_row"] = len(aligned_columns) >= 2
```

---

## 📋 表格提取机制

### 1. 表格提取流程

```
单词位置分析
    ↓
识别表格区域
    ↓
提取单元格数据
    ↓
计算列宽
    ↓
生成 Markdown 表格
```

### 2. 单元格提取

**代码实现**：
```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L320-L340
def extract_cells(info: dict) -> list[str]:
    """从行中提取单元格数据"""
    cells = ["" for _ in range(num_cols)]
    
    for word in info["words"]:
        word_x = word["x0"]
        
        # 找到正确的列
        assigned_col = num_cols - 1  # 默认最后一列
        for col_idx in range(num_cols - 1):
            col_end = global_columns[col_idx + 1]
            if word_x < col_end - 20:
                assigned_col = col_idx
                break
        
        # 添加单词到单元格
        if cells[assigned_col]:
            cells[assigned_col] += " " + word["text"]
        else:
            cells[assigned_col] = word["text"]
    
    return cells
```

---

### 3. Markdown 表格生成

**代码实现**：
```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L78-L119
def _to_markdown_table(table: list[list[str]], include_separator: bool = True) -> str:
    """将 2D 列表转换为 Markdown 表格"""
    
    # 规范化空值
    table = [[cell if cell else "" for cell in row] for row in table]
    
    # 过滤空行
    table = [row for row in table if any(cell.strip() for cell in row)]
    
    # 计算列宽
    col_widths = [max(len(str(cell)) for cell in col) for col in zip(*table)]
    
    def fmt_row(row: list[str]) -> str:
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

**输出示例**：
```markdown
| Name      | Age | City        |
|-----------|-----|-------------|
| Alice     | 30  | New York    |
| Bob       | 25  | Los Angeles |
| Charlie   | 35  | Chicago     |
```

---

## 📊 图表处理机制

### 1. 图表识别

MarkItDown **不直接提取图表图像**，而是：

1. **提取图表标题**（如果有）
2. **提取图表说明文字**
3. **提取图表中的数据表格**（如果有）

**识别逻辑**：
```python
# 图表通常包含以下特征
# 1. "Figure", "Chart", "Graph" 等关键词
# 2. 标题格式（Figure 1: ...）
# 3. 坐标轴标签
# 4. 数据表格

# 当前实现主要依赖 pdfplumber 的文本提取
# 不处理图像内容
```

---

### 2. 图表数据提取

**对于包含数据表格的图表**：
```python
# 使用表格提取逻辑
tables = _extract_tables_from_words(page)

for table in tables:
    # 转换为 Markdown 表格
    markdown_table = _to_markdown_table(table)
    markdown_chunks.append(markdown_table)
```

**输出示例**：
```markdown
## Figure 1: Sales Trends

| Year | Q1   | Q2   | Q3   | Q4   |
|------|------|------|------|------|
| 2023 | $10M | $12M | $15M | $18M |
| 2024 | $20M | $22M | $25M | $28M |
```

---

### 3. 图像元数据提取

**对于 PDF 中的图像**，MarkItDown 可以提取：

1. **EXIF 元数据**（如果图像包含）
2. **图像位置信息**
3. **图像周围文本**

**代码实现**（通过 ImageConverter）：
```python
# packages/markitdown/src/markitdown/converters/_image_converter.py
class ImageConverter(DocumentConverter):
    def convert(self, file_stream, stream_info):
        from PIL import Image
        img = Image.open(file_stream)
        
        # 提取 EXIF 元数据
        exif_data = self._extract_exif(img)
        if exif_data:
            markdown_parts.append("## EXIF Metadata\n\n" + exif_data)
        
        # 可选：LLM 标注
        if self._llm_client:
            caption = self._caption_image(img)
            markdown_parts.append(f"\n## Image Caption\n\n{caption}")
```

---

## 🎯 结构保留机制

### 1. 标题识别

MarkItDown 通过以下方式识别标题：

1. **字体大小**：大字体 → 标题
2. **位置**：页面顶部 → 可能是标题
3. **格式**：粗体/斜体 → 可能是标题

**后处理**：
```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L14-L53
def _merge_partial_numbering_lines(text: str) -> str:
    """合并 MasterFormat 风格的部分编号"""
    lines = text.split("\n")
    result_lines = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # 检查是否仅为部分编号（如".1", ".2"）
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

---

### 2. 列表识别

**识别标准**：
1. **项目符号**：`•`, `-`, `*` 等
2. **编号**：`1.`, `2.`, `a.`, `b.` 等
3. **缩进**：相对于正文的缩进

**输出格式**：
```markdown
- 列表项 1
- 列表项 2
  - 子项 2.1
  - 子项 2.2
```

---

### 3. 段落识别

**识别标准**：
1. **行宽**：>55% 页面宽度
2. **文本长度**：>60 字符
3. **无列对齐**：不与表格列对齐

**处理逻辑**：
```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L165-L175
is_paragraph = line_width > page_width * 0.55 and len(combined_text) > 60

# 检查 MasterFormat 风格的部分编号
has_partial_numbering = False
if row_words:
    first_word = row_words[0]["text"].strip()
    if PARTIAL_NUMBERING_PATTERN.match(first_word):
        has_partial_numbering = True
```

---

## 📊 性能优化

### 1. 自适应容差计算

**问题**：固定容差（如 35pt）在不同 PDF 中效果不一致

**解决方案**：基于统计的自适应容差

```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L202-L224
# 计算间隙
gaps = []
for i in range(len(all_table_x_positions) - 1):
    gap = all_table_x_positions[i + 1] - all_table_x_positions[i]
    if gap > 5:  # 仅显著间隙
        gaps.append(gap)

# 使用 70% 分位数作为阈值
if gaps and len(gaps) >= 3:
    sorted_gaps = sorted(gaps)
    percentile_70_idx = int(len(sorted_gaps) * 0.70)
    adaptive_tolerance = sorted_gaps[percentile_70_idx]
    adaptive_tolerance = max(25, min(50, adaptive_tolerance))  # 限制在 25-50pt
```

---

### 2. 表格验证

**验证标准**：
1. **最少行数**：≥3 行（包括表头）
2. **单元格长度**：≤30 字符（表格特征）
3. **长单元格比例**：≤30%（超过则可能是文本布局）

**代码实现**：
```python
# packages/markitdown/src/markitdown/converters/_pdf_converter.py#L375-L395
# 验证表格质量
if len(table_rows) < 3:
    return []

# 检查单元格是否包含短文本（表格特征）
long_cell_count = 0
total_cell_count = 0
for row in table_rows:
    for cell in row:
        if cell.strip():
            total_cell_count += 1
            # 单元格>30 字符可能是散文文本
            if len(cell.strip()) > 30:
                long_cell_count += 1

# 如果>30% 的单元格是长的，可能不是表格
if total_cell_count > 0 and long_cell_count / total_cell_count > 0.3:
    return []
```

---

### 3. 回退机制

**多层回退**：
```python
try:
    # 第一层：pdfplumber 提取
    with pdfplumber.open(pdf_bytes) as pdf:
        # ... 提取逻辑
except Exception:
    # 第二层：pdfminer 提取
    markdown = pdfminer.high_level.extract_text(pdf_bytes)

# 最终回退：如果仍然为空
if not markdown:
    markdown = pdfminer.high_level.extract_text(pdf_bytes)
```

---

## 📝 输出示例

### 1. 普通文本页面

**输入 PDF**：
```
Introduction

This is a paragraph of text that spans
multiple lines in the PDF document.
```

**输出 Markdown**：
```markdown
# Introduction

This is a paragraph of text that spans multiple lines in the PDF document.
```

---

### 2. 表格页面

**输入 PDF**：
```
Sales Report

Product    Q1      Q2      Q3
Widget A   $100    $120    $150
Widget B   $200    $220    $250
```

**输出 Markdown**：
```markdown
# Sales Report

| Product  | Q1   | Q2   | Q3   |
|----------|------|------|------|
| Widget A | $100 | $120 | $150 |
| Widget B | $200 | $220 | $250 |
```

---

### 3. 混合内容页面

**输入 PDF**：
```
Figure 1: Sales Trends

Year    Q1    Q2    Q3    Q4
2023    $10M  $12M  $15M  $18M
2024    $20M  $22M  $25M  $28M

The chart shows steady growth...
```

**输出 Markdown**：
```markdown
## Figure 1: Sales Trends

| Year | Q1   | Q2   | Q3   | Q4   |
|------|------|------|------|------|
| 2023 | $10M | $12M | $15M | $18M |
| 2024 | $20M | $22M | $25M | $28M |

The chart shows steady growth...
```

---

## 💡 关键技术亮点

### 1. 基于位置的表格识别

**创新点**：不依赖表格线，仅通过单词位置识别表格

**优势**：
- ✅ 处理无框线表格
- ✅ 处理复杂布局
- ✅ 适应不同 PDF 格式

---

### 2. 自适应容差算法

**创新点**：基于统计的自适应容差计算

**优势**：
- ✅ 适应不同 PDF 分辨率
- ✅ 减少手动调参
- ✅ 提高识别准确率

---

### 3. 双层提取策略

**创新点**：pdfplumber + pdfminer 双重保障

**优势**：
- ✅ 优先使用 pdfplumber（更好的结构识别）
- ✅ 回退到 pdfminer（更好的文本提取）
- ✅ 保证提取成功率

---

## 📋 局限性

### 1. 图表图像处理

**当前限制**：
- ❌ 不提取图表图像本身
- ❌ 不识别图表类型（柱状图、折线图等）
- ❌ 不提取图表中的数据点

**原因**：
- MarkItDown 定位为**文本转换工具**
- 图表图像提取需要 OCR 和图像分析
- 超出项目范围

---

### 2. 复杂表格

**当前限制**：
- ❌ 跨页表格识别不准确
- ❌ 嵌套表格支持有限
- ❌ 旋转表格识别困难

**原因**：
- 基于单页分析
- 列对齐算法假设简单结构

---

### 3. 公式和数学符号

**当前限制**：
- ❌ LaTeX 公式不识别
- ❌ 数学符号可能丢失
- ❌ 上标/下标处理不准确

**原因**：
- PDF 中公式通常作为图像或特殊字体
- 需要专门的公式识别引擎

---

## 🔗 相关资源

### 依赖库
- **pdfplumber**: https://github.com/jsvine/pdfplumber
- **pdfminer.six**: https://github.com/pdfminer/pdfminer.six

### 代码位置
- **PDF 转换器**: [`converters/_pdf_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_pdf_converter.py)
- **表格提取**: `_extract_form_content_from_words()` (L120-L360)
- **Markdown 生成**: `_to_markdown_table()` (L78-L119)

---

**研究人**：Jarvis  
**日期**：2026-02-28  
**方法**：代码深度分析  
**状态**：✅ 完成
