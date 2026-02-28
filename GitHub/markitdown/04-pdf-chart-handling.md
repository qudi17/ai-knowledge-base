# MarkItDown - PDF 图表处理机制详解

**研究日期**：2026-02-28  
**研究内容**：饼图、柱状图、线图等图表的提取与处理  
**核心发现**：标准 PDF 转换器**不直接处理图表图像**

---

## 📊 核心结论

### 简短回答

**MarkItDown 的标准 PDF 转换器不直接处理图表图像**（饼图、柱状图、线图等）。

**处理方式**：
1. ✅ 提取图表标题和说明文字
2. ✅ 提取图表中的数据表格（如果有）
3. ❌ 不提取图表图像本身
4. ❌ 不识别图表类型
5. ❌ 不提取图表中的数据点

---

## 🔍 详细分析

### 1. 标准 PDF 转换器的能力边界

**代码位置**：`converters/_pdf_converter.py`

**核心函数**：
```python
def convert(self, file_stream, stream_info):
    # 使用 pdfplumber 提取文本
    with pdfplumber.open(pdf_bytes) as pdf:
        for page in pdf.pages:
            # 基于单词位置分析
            page_content = _extract_form_content_from_words(page)
```

**处理对象**：
- ✅ 文本内容
- ✅ 表格结构
- ✅ 段落布局
- ❌ 图像/图表

**原因**：
- pdfplumber 主要处理**文本层**
- 图表在 PDF 中通常作为**图像对象**嵌入
- 需要专门的图像处理能力

---

### 2. 对比：PPTX 转换器的图表处理

**有趣发现**：MarkItDown 的 **PPTX 转换器**支持图表处理！

**代码位置**：`converters/_pptx_converter.py`

**核心函数**：
```python
# packages/markitdown/src/markitdown/converters/_pptx_converter.py#L159-L160
if shape.has_chart:
    md_content += self._convert_chart_to_markdown(shape.chart)
```

**图表转换逻辑**：
```python
# packages/markitdown/src/markitdown/converters/_pptx_converter.py#L235-L264
def _convert_chart_to_markdown(self, chart):
    md = "\n\n### Chart"
    
    # 提取图表标题
    if chart.has_title:
        md += f": {chart.chart_title.text_frame.text}"
    
    md += "\n\n"
    
    try:
        # 提取分类和数据系列
        category_names = [c.label for c in chart.plots[0].categories]
        series_names = [s.name for s in chart.series]
        
        # 构建表格
        md += "| Category | " + " | ".join(series_names) + " |\n"
        md += "|----------|" + "|".join(["---"] * len(series_names)) + "|\n"
        
        # 提取数据点
        for i, category in enumerate(category_names):
            row_data = [str(series.values[i]) for series in chart.series]
            md += f"| {category} | " + " | ".join(row_data) + " |\n"
        
        return md
    
    except Exception as e:
        # 不支持的图表类型
        return "\n\n[unsupported chart]\n\n"
```

**输出示例**：
```markdown
### Chart: Sales Trends

| Category | Q1 | Q2 | Q3 | Q4 |
|----------|----|----|----|----|
| Product A | $10M | $12M | $15M | $18M |
| Product B | $20M | $22M | $25M | $28M |
```

**关键差异**：
- PPTX 中的图表是**结构化数据对象**（可访问数据点）
- PDF 中的图表通常是**渲染后的图像**（无原始数据）

---

### 3. PDF 中图表的存储形式

#### 3.1 常见情况

**PDF 中的图表通常以以下形式存在**：

1. **嵌入图像**（最常见）
   - 图表被渲染为 PNG/JPEG 嵌入 PDF
   - 丢失原始数据
   - 只能通过 OCR 或视觉分析提取

2. **矢量图形**
   - 使用 PDF 绘图指令绘制
   - 保留部分结构信息
   - 需要解析 PDF 图形指令

3. **LaTeX/公式**
   - 学术文档常见
   - 需要专门的公式识别

**MarkItDown 的处理**：
```python
# 标准 PDF 转换器仅提取文本层
text = page.extract_text()

# 不处理图像对象
# 不处理矢量图形
# 不处理公式
```

---

### 4. 可选方案：Document Intelligence 转换器

MarkItDown 提供**可选的 Azure Document Intelligence 转换器**，支持更强大的分析。

**代码位置**：`converters/_doc_intel_converter.py`

**启用方式**：
```python
from markitdown import MarkItDown

md = MarkItDown(
    docintel_endpoint="https://your-resource.cognitiveservices.azure.com/",
    docintel_credential=credential,
    docintel_file_types=["pdf", "docx", "xlsx", "jpeg", "png"]
)
```

**核心功能**：
```python
# packages/markitdown/src/markitdown/converters/_doc_intel_converter.py#L197-L217
def convert(self, file_stream, stream_info):
    # 使用 Azure Document Intelligence 分析
    poller = self.doc_intel_client.begin_analyze_document(
        model_id="prebuilt-layout",  # 布局分析模型
        body=AnalyzeDocumentRequest(bytes_source=file_stream.read()),
        features=self._analysis_features(stream_info),
        output_content_format="markdown",
    )
    result: AnalyzeResult = poller.result()
    
    # 提取 Markdown
    markdown_text = re.sub(r"<!--.*?-->", "", result.content, flags=re.DOTALL)
    return DocumentConverterResult(markdown=markdown_text)
```

**支持的分析特性**：
```python
# packages/markitdown/src/markitdown/converters/_doc_intel_converter.py#L207-L214
def _analysis_features(self, stream_info):
    # PDF 支持的特性
    return [
        DocumentAnalysisFeature.FORMULAS,  # 公式提取
        DocumentAnalysisFeature.OCR_HIGH_RESOLUTION,  # 高分辨率 OCR
        DocumentAnalysisFeature.STYLE_FONT,  # 字体样式提取
    ]
```

**能力对比**：

| 特性 | 标准 PDF 转换器 | Document Intelligence |
|------|----------------|----------------------|
| **文本提取** | ✅ | ✅ |
| **表格识别** | ✅ | ✅ |
| **图表标题** | ✅ | ✅ |
| **图表数据** | ❌ | ⚠️ 部分支持 |
| **公式识别** | ❌ | ✅ |
| **OCR** | ⚠️ 基础 | ✅ 高分辨率 |
| **成本** | 免费 | Azure 计费 |

---

### 5. 图像转换器的 LLM 标注能力

**代码位置**：`converters/_image_converter.py`

**核心功能**：使用多模态 LLM 描述图像

```python
# packages/markitdown/src/markitdown/converters/_image_converter.py#L77-L132
def _get_llm_description(self, file_stream, stream_info, *, client, model, prompt=None):
    if prompt is None:
        prompt = "Write a detailed caption for this image."
    
    # 转换为 base64
    base64_image = base64.b64encode(file_stream.read()).decode("utf-8")
    
    # 调用多模态 LLM
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:{content_type};base64,{base64_image}"},
                },
            ],
        }
    ]
    
    response = client.chat.completions.create(model=model, messages=messages)
    return response.choices[0].message.content
```

**输出示例**：
```markdown
# Description:
This is a bar chart showing quarterly sales data. The x-axis represents four quarters 
(Q1-Q4), and the y-axis shows revenue in millions of dollars. Blue bars represent 
Product A, starting at $10M in Q1 and growing to $18M in Q4. Orange bars represent 
Product B, starting at $20M and reaching $28M. The chart demonstrates consistent 
growth for both products throughout the year.
```

**限制**：
- 需要配置 LLM 客户端（OpenAI 等）
- 增加处理成本和时间
- 描述准确性依赖模型能力

---

## 📋 实际测试场景

### 场景 1：PDF 包含柱状图

**输入 PDF**：
```
[柱状图图像]
Figure 1: Quarterly Sales
```

**MarkItDown 输出（标准转换器）**：
```markdown
Figure 1: Quarterly Sales
```

**缺失内容**：
- ❌ 柱状图数据
- ❌ 坐标轴信息
- ❌ 趋势描述

---

### 场景 2：PDF 包含数据表格 + 图表

**输入 PDF**：
```
Sales Report

| Product | Q1 | Q2 | Q3 | Q4 |
|---------|----|----|----|----|
| A       | 10 | 12 | 15 | 18 |
| B       | 20 | 22 | 25 | 28 |

[柱状图基于上述数据]
```

**MarkItDown 输出**：
```markdown
Sales Report

| Product | Q1 | Q2 | Q3 | Q4 |
|---------|----|----|----|----|
| A       | 10 | 12 | 15 | 18 |
| B       | 20 | 22 | 25 | 28 |
```

**处理结果**：
- ✅ 提取了数据表格
- ❌ 未处理图表图像

---

### 场景 3：使用 Document Intelligence

**输入 PDF**：
```
[柱状图]
Figure 1: Sales Trends
```

**输出（Azure Document Intelligence）**：
```markdown
Figure 1: Sales Trends

[图表可能被描述为图像或提取部分数据]
```

**改进**：
- ✅ 更好的 OCR 质量
- ✅ 可能识别图表中的文本
- ⚠️ 仍不保证提取完整数据

---

## 💡 解决方案对比

### 方案 1：MarkItDown 标准转换器

**优点**：
- ✅ 免费
- ✅ 快速
- ✅ 本地处理

**缺点**：
- ❌ 不处理图表图像
- ❌ 仅提取文本层

**适用场景**：文本为主的 PDF

---

### 方案 2：MarkItDown + Document Intelligence

**优点**：
- ✅ 更好的 OCR
- ✅ 公式识别
- ✅ 布局分析

**缺点**：
- ❌ 需要 Azure 账户
- ❌ 按页计费
- ❌ 网络延迟

**适用场景**：企业级文档处理

---

### 方案 3：MarkItDown + LLM 图像标注

**优点**：
- ✅ 自然语言描述
- ✅ 可定制 prompt
- ✅ 理解图表语义

**缺点**：
- ❌ 需要 LLM API
- ❌ 成本较高
- ❌ 描述可能不准确

**适用场景**：需要图表理解的场景

---

### 方案 4：专用图表提取工具

**推荐工具**：

1. **ChartOCR**
   - 专门提取图表数据
   - 支持柱状图、折线图、饼图
   - GitHub: https://github.com/chanind/chart-ocr

2. **DePlot**（Google）
   - 将图表转换为结构化数据
   - 基于视觉语言模型
   - Paper: https://arxiv.org/abs/2212.10505

3. **PlotDigitizer**
   - 手动/自动提取图表数据点
   - 开源工具
   - Website: https://plotdigitizer.com/

**工作流**：
```
PDF → 提取图像 → 图表 OCR → 结构化数据 → Markdown
```

---

## 🔧 自定义扩展方案

### 扩展 MarkItDown 处理图表

**思路**：创建自定义转换器

```python
from markitdown import MarkItDown
from markitdown._base_converter import DocumentConverter, DocumentConverterResult
import pdfplumber
import io

class ChartExtractingPdfConverter(DocumentConverter):
    """扩展的 PDF 转换器，支持图表提取"""
    
    def accepts(self, file_stream, stream_info):
        return stream_info.mimetype == "application/pdf"
    
    def convert(self, file_stream, stream_info):
        pdf_bytes = io.BytesIO(file_stream.read())
        markdown_chunks = []
        
        with pdfplumber.open(pdf_bytes) as pdf:
            for page_num, page in enumerate(pdf.pages):
                # 1. 提取文本
                text = page.extract_text()
                if text:
                    markdown_chunks.append(text)
                
                # 2. 提取图像
                images = page.images
                for img in images:
                    # 检查是否是图表（基于位置、大小等）
                    if self._is_likely_chart(img):
                        # 提取图像
                        chart_img = page.crop(img).to_image()
                        
                        # 使用 LLM 描述
                        if self._llm_client:
                            description = self._describe_chart(chart_img)
                            markdown_chunks.append(f"\n\n**Chart {page_num}**: {description}\n")
        
        return DocumentConverterResult(markdown="\n\n".join(markdown_chunks))
    
    def _is_likely_chart(self, img):
        # 启发式判断：宽高比、大小等
        aspect_ratio = img["width"] / img["height"]
        return 0.5 < aspect_ratio < 2.0 and img["width"] > 200
    
    def _describe_chart(self, chart_img):
        # 调用多模态 LLM
        # ...
        pass

# 使用
md = MarkItDown()
md.register_converter(ChartExtractingPdfConverter(), priority=0.0)
```

---

## 📊 总结对比表

| 方案 | 图表标题 | 图表数据 | 图表描述 | 成本 | 速度 |
|------|---------|---------|---------|------|------|
| **MarkItDown 标准** | ✅ | ❌ | ❌ | 免费 | 快 |
| **Document Intelligence** | ✅ | ⚠️ 部分 | ⚠️ 部分 | $$ | 中 |
| **LLM 图像标注** | ✅ | ❌ | ✅ | $$ | 中 |
| **专用图表工具** | ✅ | ✅ | ⚠️ | $-$$ | 慢 |
| **自定义扩展** | ✅ | ✅ | ✅ | 可变 | 可变 |

---

## 🎯 最佳实践建议

### 对于文本为主的 PDF

**推荐**：MarkItDown 标准转换器

```python
from markitdown import MarkItDown

md = MarkItDown()
result = md.convert("document.pdf")
```

---

### 对于包含图表的 PDF

**推荐组合方案**：

1. **第一步**：使用 MarkItDown 提取文本和表格
   ```python
   result = md.convert("document.pdf")
   ```

2. **第二步**：使用 pdfplumber 提取图像
   ```python
   import pdfplumber
   
   with pdfplumber.open("document.pdf") as pdf:
       for page in pdf.pages:
           for img in page.images:
               # 提取图像
               pass
   ```

3. **第三步**：使用 DePlot/ChartOCR 处理图表
   ```python
   # 使用专用工具提取图表数据
   ```

4. **第四步**：合并结果
   ```python
   # 文本 + 表格 + 图表数据 → 完整 Markdown
   ```

---

### 对于企业级应用

**推荐**：Azure Document Intelligence

```python
md = MarkItDown(
    docintel_endpoint="https://your-resource.cognitiveservices.azure.com/",
    docintel_credential=credential
)
result = md.convert("document.pdf")
```

**优势**：
- 一站式解决方案
- 支持多种文档类型
- 企业级 SLA

---

## 🔗 相关资源

### MarkItDown 代码
- **PDF 转换器**: [`converters/_pdf_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_pdf_converter.py)
- **PPTX 转换器**: [`converters/_pptx_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_pptx_converter.py)
- **图像转换器**: [`converters/_image_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_image_converter.py)
- **Document Intelligence**: [`converters/_doc_intel_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_doc_intel_converter.py)

### 图表提取工具
- **ChartOCR**: https://github.com/chanind/chart-ocr
- **DePlot**: https://arxiv.org/abs/2212.10505
- **PlotDigitizer**: https://plotdigitizer.com/

### Azure Document Intelligence
- **文档**: https://learn.microsoft.com/azure/ai-services/document-intelligence/
- **定价**: https://azure.microsoft.com/pricing/details/form-recognizer/

---

**研究人**：Jarvis  
**日期**：2026-02-28  
**方法**：代码深度分析 + 对比研究  
**状态**：✅ 完成
