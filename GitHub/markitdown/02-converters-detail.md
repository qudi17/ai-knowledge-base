# MarkItDown 转换器详解

**研究日期**：2026-02-28  
**研究内容**：25+ 个转换器实现详解

---

## 📊 转换器总览

| 类型 | 转换器数量 | 总代码行 |
|------|-----------|---------|
| **文档类** | 6 个 | ~1,200 行 |
| **图片/音频** | 2 个 | ~150 行 |
| **Web 类** | 4 个 | ~400 行 |
| **数据类** | 3 个 | ~200 行 |
| **其他** | 10 个 | ~1,350 行 |
| **总计** | **25+ 个** | **~3,300 行** |

---

## 1️⃣ PDF 转换器

**文件**：[`converters/_pdf_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_pdf_converter.py) (~500 行)

**依赖**：`pdfminer.six`, `pillow`, `ollama` (可选)

**核心方法**：
```python
class PdfConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info):
        return stream_info.mimetype == "application/pdf"
    
    def convert(self, file_stream, stream_info):
        # 1. 使用 pdfminer.six 提取文本
        # 2. 识别页面结构（标题、列表、表格）
        # 3. 可选：使用 LLM 标注图片
        # 4. 生成 Markdown
```

**关键特性**：
- ✅ 保留文档结构（标题、列表、表格）
- ✅ 支持 OCR（可选）
- ✅ 支持 LLM 图片标注（可选）
- ✅ 处理复杂布局

**代码片段**：
```python
from pdfminer.high_level import extract_pages
from pdfminer.layout import LTTextContainer, LTTable

def convert(self, file_stream, stream_info):
    markdown_content = ""
    
    for page in extract_pages(file_stream):
        for element in page:
            if isinstance(element, LTTextContainer):
                # 提取文本
                text = element.get_text()
                markdown_content += text + "\n"
            elif isinstance(element, LTTable):
                # 提取表格
                table_md = self._convert_table(element)
                markdown_content += table_md + "\n"
    
    return DocumentConverterResult(markdown=markdown_content)
```

---

## 2️⃣ Word 转换器

**文件**：[`converters/_docx_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_docx_converter.py) (~60 行)

**依赖**：`python-docx`

**核心方法**：
```python
class DocxConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info):
        return stream_info.extension == ".docx"
    
    def convert(self, file_stream, stream_info):
        from docx import Document
        doc = Document(file_stream)
        
        markdown_lines = []
        for para in doc.paragraphs:
            if para.style.name.startswith('Heading'):
                # 标题
                level = int(para.style.name.split(' ')[-1])
                markdown_lines.append(f"{'#' * level} {para.text}")
            else:
                # 普通段落
                markdown_lines.append(para.text)
        
        return DocumentConverterResult(markdown="\n".join(markdown_lines))
```

**关键特性**：
- ✅ 保留标题层级
- ✅ 保留段落结构
- ✅ 简洁实现（60 行）

---

## 3️⃣ Excel 转换器

**文件**：[`converters/_xlsx_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_xlsx_converter.py) (~160 行)

**依赖**：`openpyxl`

**核心方法**：
```python
class XlsxConverter(DocumentConverter):
    def convert(self, file_stream, stream_info):
        from openpyxl import load_workbook
        wb = load_workbook(file_stream, read_only=True)
        
        markdown_sheets = []
        for sheet_name in wb.sheetnames:
            sheet = wb[sheet_name]
            
            # 转换为 Markdown 表格
            markdown_table = self._convert_sheet(sheet)
            markdown_sheets.append(f"## {sheet_name}\n\n{markdown_table}")
        
        return DocumentConverterResult(markdown="\n\n".join(markdown_sheets))
    
    def _convert_sheet(self, sheet):
        # 提取数据
        rows = []
        for row in sheet.iter_rows(values_only=True):
            rows.append("| " + " | ".join(str(cell) for cell in row) + " |")
        
        # 添加表头分隔符
        if rows:
            rows.insert(1, "| " + " | ".join(["---"] * len(rows[0])) + " |")
        
        return "\n".join(rows)
```

**关键特性**：
- ✅ 每个工作表一个 Markdown 表格
- ✅ 保留表头
- ✅ 处理大文件（read_only=True）

---

## 4️⃣ PowerPoint 转换器

**文件**：[`converters/_pptx_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_pptx_converter.py) (~240 行)

**依赖**：`python-pptx`

**核心方法**：
```python
class PptxConverter(DocumentConverter):
    def convert(self, file_stream, stream_info):
        from pptx import Presentation
        prs = Presentation(file_stream)
        
        markdown_slides = []
        for i, slide in enumerate(prs.slides):
            slide_md = f"## Slide {i+1}\n\n"
            
            # 提取形状
            for shape in slide.shapes:
                if hasattr(shape, "text"):
                    slide_md += shape.text + "\n"
                elif shape.shape_type == MSO_SHAPE_TYPE.TABLE:
                    # 提取表格
                    table_md = self._convert_table(shape.table)
                    slide_md += table_md + "\n"
            
            markdown_slides.append(slide_md)
        
        return DocumentConverterResult(markdown="\n\n".join(markdown_slides))
```

**关键特性**：
- ✅ 每张幻灯片一个章节
- ✅ 提取文本和表格
- ✅ 保留顺序

---

## 5️⃣ HTML 转换器

**文件**：[`converters/_html_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_html_converter.py) (~70 行)

**依赖**：`markdownify`

**核心方法**：
```python
class HtmlConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info):
        return stream_info.mimetype.startswith("text/html")
    
    def convert(self, file_stream, stream_info):
        from markdownify import markdownify
        html_content = file_stream.read().decode('utf-8')
        
        markdown = markdownify(
            html_content,
            heading_style="ATX",  # 使用 # 标题
            bullets="-",          # 使用 - 列表
            escape_underscores=False,
        )
        
        return DocumentConverterResult(markdown=markdown)
```

**关键特性**：
- ✅ 使用 markdownify 库
- ✅ 保留 HTML 结构
- ✅ 简洁实现（70 行）

---

## 6️⃣ 图片转换器

**文件**：[`converters/_image_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_image_converter.py) (~70 行)

**依赖**：`pillow`, `ollama` (可选)

**核心方法**：
```python
class ImageConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info):
        return stream_info.mimetype.startswith("image/")
    
    def convert(self, file_stream, stream_info):
        from PIL import Image
        img = Image.open(file_stream)
        
        markdown_parts = []
        
        # 1. 提取 EXIF 元数据
        exif_data = self._extract_exif(img)
        if exif_data:
            markdown_parts.append("## EXIF Metadata\n\n" + exif_data)
        
        # 2. 可选：LLM 标注
        if self._llm_client:
            caption = self._caption_image(img)
            markdown_parts.append(f"\n## Image Caption\n\n{caption}")
        
        return DocumentConverterResult(markdown="\n\n".join(markdown_parts))
```

**关键特性**：
- ✅ 提取 EXIF 元数据
- ✅ 可选 LLM 标注
- ✅ 支持多种图片格式

---

## 7️⃣ YouTube 转换器

**文件**：[`converters/_youtube_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_youtube_converter.py) (~170 行)

**依赖**：`youtube-transcript-api`, `pytube`

**核心方法**：
```python
class YouTubeConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info):
        # 检查是否是 YouTube URL
        return "youtube.com" in stream_info.url or "youtu.be" in stream_info.url
    
    def convert(self, file_stream, stream_info):
        from youtube_transcript_api import YouTubeTranscriptApi
        from pytube import YouTube
        
        # 提取视频 ID
        video_id = self._extract_video_id(stream_info.url)
        
        # 获取字幕
        transcript = YouTubeTranscriptApi.get_transcript(video_id)
        
        # 获取视频信息
        yt = YouTube(stream_info.url)
        title = yt.title
        author = yt.author
        
        # 生成 Markdown
        markdown = f"# {title}\n\n"
        markdown += f"**Author**: {author}\n\n"
        markdown += "## Transcript\n\n"
        
        for entry in transcript:
            markdown += f"{entry['text']}\n"
        
        return DocumentConverterResult(markdown=markdown)
```

**关键特性**：
- ✅ 提取视频字幕
- ✅ 获取视频元数据
- ✅ 生成完整转录稿

---

## 8️⃣ ZIP 转换器

**文件**：[`converters/_zip_converter.py`](https://github.com/qudi17/markitdown/blob/main/packages/markitdown/src/markitdown/converters/_zip_converter.py) (~90 行)

**依赖**：`zipfile` (标准库)

**核心方法**：
```python
class ZipConverter(DocumentConverter):
    def accepts(self, file_stream, stream_info):
        return stream_info.mimetype == "application/zip"
    
    def convert(self, file_stream, stream_info):
        import zipfile
        import io
        
        with zipfile.ZipFile(file_stream, 'r') as zip_file:
            markdown_parts = []
            
            for name in zip_file.namelist():
                # 读取文件内容
                content = zip_file.read(name)
                
                # 递归转换
                result = self._markitdown.convert_stream(io.BytesIO(content))
                markdown_parts.append(f"## {name}\n\n{result.markdown}")
            
            return DocumentConverterResult(markdown="\n\n".join(markdown_parts))
```

**关键特性**：
- ✅ 递归转换 ZIP 内容
- ✅ 保留文件结构
- ✅ 支持嵌套 ZIP

---

## 🎯 转换器优先级

**注册顺序**（后注册的优先级更高）：

```python
# 1. 通用转换器（先试）
PlainTextConverter()      # PRIORITY_GENERIC_FILE_FORMAT
HtmlConverter()           # PRIORITY_GENERIC_FILE_FORMAT
ZipConverter()            # PRIORITY_GENERIC_FILE_FORMAT

# 2. 特定转换器（后试，覆盖通用）
DocxConverter()
XlsxConverter()
PptxConverter()
PdfConverter()
ImageConverter()
AudioConverter()
# ...
```

**优先级逻辑**：
```python
# 低优先级先试（0.0）
PRIORITY_SPECIFIC_FILE_FORMAT = 0.0

# 高优先级后试（10.0）
PRIORITY_GENERIC_FILE_FORMAT = 10.0

# 排序：低优先级在前
self._converters.sort(key=lambda reg: reg.priority)

# 结果：
# [PdfConverter(0.0), DocxConverter(0.0), ..., HtmlConverter(10.0), PlainTextConverter(10.0)]
```

---

## 💡 设计亮点

### 1. 流式处理

所有转换器都接受 `BinaryIO`，不创建临时文件：

```python
def convert(self, file_stream: BinaryIO, stream_info: StreamInfo):
    # 直接从流中读取
    data = file_stream.read()
    
    # 处理完后重置位置（如果需要）
    file_stream.seek(0)
```

**优势**：
- ✅ 无临时文件
- ✅ 支持大文件
- ✅ 内存友好

---

### 2. 异常处理

```python
try:
    result = converter.convert(file_stream, stream_info)
    return result
except MissingDependencyException:
    # 缺少依赖，尝试下一个转换器
    continue
except FileConversionException:
    # 转换失败，尝试下一个转换器
    continue
```

---

### 3. 插件系统

```python
# 通过 entry_points 加载插件
for entry_point in entry_points(group="markitdown.plugin"):
    plugin = entry_point.load()
    plugin.register_converters(self)
```

**插件示例**：
```python
# setup.py
entry_points={
    'markitdown.plugin': [
        'my_plugin = my_plugin:MyPlugin',
    ],
}

# my_plugin.py
class MyPlugin:
    def register_converters(self, markitdown):
        markitdown.register_converter(MyCustomConverter())
```

---

## 📝 待研究分支

- [ ] **详细分析每个转换器的 accepts() 逻辑**
- [ ] **研究错误处理机制**
- [ ] **分析测试覆盖率**
- [ ] **性能基准测试**
- [ ] **对比其他工具（textract 等）**

---

**研究人**：Jarvis  
**日期**：2026-02-28  
**方法**：毛线团研究法  
**状态**：🔄 进行中
