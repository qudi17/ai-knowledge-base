---
tags: [AI/RAG, AI/缓存，架构/性能优化，LiteLLM]
created: 2026-02-28
modified: 2026-02-28
status: 实施中
owner: Eddy
priority: P0
---

# LiteLLM 缓存实施指南

**目标**：在公司 RAG 系统中实施 LiteLLM 缓存，降低 70%+ LLM 成本，提升 2-3 倍响应速度

**预计时间**：2-3 天（POC）+ 1 周（生产）

---

## 📋 目录

1. [环境准备](#1-环境准备)
2. [安装配置](#2-安装配置)
3. [代码实现](#3-代码实现)
4. [测试方案](#4-测试方案)
5. [监控方案](#5-监控方案)
6. [故障排查](#6-故障排查)
7. [成本估算](#7-成本估算)

---

## 1. 环境准备

### 1.1 硬件要求

| 组件 | 最低配置 | 推荐配置 | 说明 |
|------|---------|---------|------|
| **Redis 服务器** | 2 核 4GB | 4 核 8GB | 根据缓存量调整 |
| **应用服务器** | 2 核 4GB | 4 核 8GB | LiteLLM + 应用 |
| **网络** | 100Mbps | 1Gbps | 低延迟连接 |

### 1.2 软件要求

```bash
# 必需
Python >= 3.9
Redis >= 7.0
LiteLLM >= 1.40.0

# 可选（语义缓存）
OpenAI API Key（Embedding）
```

### 1.3 API Keys 准备

```bash
# .env 文件
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
REDIS_PASSWORD=your-redis-password
```

---

## 2. 安装配置

### 2.1 安装依赖

```bash
# 创建虚拟环境
python -m venv venv
source venv/bin/activate

# 安装 LiteLLM 及缓存依赖
pip install litellm[redis]
pip install redis
pip install openai  # 语义缓存需要

# 或使用 requirements.txt
cat > requirements.txt << EOF
litellm[redis]>=1.40.0
redis>=5.0.0
openai>=1.12.0
python-dotenv>=1.0.0
EOF

pip install -r requirements.txt
```

### 2.2 部署 Redis

#### 方案 A：Docker（推荐开发/测试）

```bash
# 启动 Redis
docker run -d \
  --name redis-cache \
  -p 6379:6379 \
  -v redis-data:/data \
  redis:7-alpine \
  redis-server --appendonly yes

# 验证
docker exec -it redis-cache redis-cli ping
# 输出：PONG
```

#### 方案 B：Docker Compose（生产推荐）

```yaml
# docker-compose.yml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: rag-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
      - ./redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  rag-service:
    build: .
    container_name: rag-service
    environment:
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    depends_on:
      redis:
        condition: service_healthy
    restart: unless-stopped

volumes:
  redis-data:
```

```conf
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
requirepass your-redis-password
bind 0.0.0.0
protected-mode yes
port 6379
```

#### 方案 C：云 Redis（生产推荐）

| 服务商 | 产品 | 价格 | 说明 |
|-------|------|------|------|
| AWS | ElastiCache | ~$50/月 | 托管服务 |
| 阿里云 | Redis 版 | ~¥300/月 | 国内推荐 |
| 腾讯云 | CKV | ~¥280/月 | 国内备选 |

---

### 2.3 配置文件

```python
# config.py
import os
from dotenv import load_dotenv

load_dotenv()

class CacheConfig:
    """LiteLLM 缓存配置"""
    
    # Redis 配置
    REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
    REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "")
    REDIS_DB = int(os.getenv("REDIS_DB", 0))
    
    # 缓存 TTL（秒）
    CACHE_TTL = int(os.getenv("CACHE_TTL", 3600))  # 1 小时
    
    # 语义缓存配置
    SEMANTIC_CACHE_ENABLED = os.getenv("SEMANTIC_CACHE_ENABLED", "false").lower() == "true"
    SEMANTIC_THRESHOLD = float(os.getenv("SEMANTIC_THRESHOLD", 0.9))
    EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-3-small")
    
    # Provider 配置
    ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-20250514")
    OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o")
    
    # 日志配置
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

# 生产环境配置示例
# .env.production
REDIS_HOST=redis.internal.company.com
REDIS_PORT=6379
REDIS_PASSWORD=strong-password-here
CACHE_TTL=7200  # 2 小时
SEMANTIC_CACHE_ENABLED=true
SEMANTIC_THRESHOLD=0.85
ANTHROPIC_MODEL=claude-sonnet-4-20250514
OPENAI_MODEL=gpt-4o
LOG_LEVEL=WARNING
```

---

## 3. 代码实现

### 3.1 基础缓存实现

```python
# cache_basic.py
import litellm
from litellm import completion
from config import CacheConfig

# 配置 Redis 缓存
litellm.cache = litellm.CacheConfig(
    type="redis",
    host=f"redis://{CacheConfig.REDIS_HOST}:{CacheConfig.REDIS_PORT}",
    password=CacheConfig.REDIS_PASSWORD if CacheConfig.REDIS_PASSWORD else None,
    db=CacheConfig.REDIS_DB,
    ttl=CacheConfig.CACHE_TTL
)

def basic_rag_query(query: str, context: str) -> str:
    """
    基础 RAG 查询（启用 LiteLLM 缓存）
    
    Args:
        query: 用户问题
        context: 检索到的上下文文档
    
    Returns:
        LLM 生成的回答
    """
    response = completion(
        model=f"anthropic/{CacheConfig.ANTHROPIC_MODEL}",
        messages=[
            {
                "role": "user",
                "content": f"基于以下文档回答问题：\n\n{context}\n\n问题：{query}"
            }
        ],
        max_tokens=1024,
        caching=True  # 启用缓存
    )
    
    return response.choices[0].message.content

# 测试
if __name__ == "__main__":
    context = "公司是 2020 年成立的，专注于 AI 技术研发..."
    query = "公司什么时候成立的？"
    
    # 第一次调用（缓存未命中）
    answer1 = basic_rag_query(query, context)
    print(f"答案 1: {answer1}")
    
    # 第二次调用（缓存命中）
    answer2 = basic_rag_query(query, context)
    print(f"答案 2: {answer2}")
```

---

### 3.2 进阶：三层缓存实现

```python
# cache_advanced.py
import litellm
from litellm import completion
from config import CacheConfig
import time
import hashlib

class RAGCache:
    """RAG 三层缓存系统"""
    
    def __init__(self):
        # 配置 LiteLLM Redis 缓存
        litellm.cache = litellm.CacheConfig(
            type="redis",
            host=f"redis://{CacheConfig.REDIS_HOST}:{CacheConfig.REDIS_PORT}",
            password=CacheConfig.REDIS_PASSWORD if CacheConfig.REDIS_PASSWORD else None,
            db=CacheConfig.REDIS_DB,
            ttl=CacheConfig.CACHE_TTL
        )
        
        # 语义缓存配置
        self.semantic_cache_config = {
            "type": "semantic",
            "similarity_threshold": CacheConfig.SEMANTIC_THRESHOLD,
            "embedding_model": CacheConfig.EMBEDDING_MODEL
        } if CacheConfig.SEMANTIC_CACHE_ENABLED else None
    
    def _generate_cache_key(self, query: str, context: str) -> str:
        """生成缓存键"""
        content = f"{query}:{context}"
        return f"rag:{hashlib.md5(content.encode()).hexdigest()}"
    
    def query(self, query: str, context: str, use_provider_cache: bool = True) -> dict:
        """
        RAG 查询（三层缓存）
        
        Args:
            query: 用户问题
            context: 检索到的上下文文档
            use_provider_cache: 是否启用 Provider 原生缓存
        
        Returns:
            dict: {
                "answer": str,  # 回答
                "cache_hit": str,  # 缓存命中层级 (redis/semantic/provider/miss)
                "latency_ms": float,  # 延迟（毫秒）
                "tokens": dict  # token 使用统计
            }
        """
        start_time = time.time()
        
        # 构建消息
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": f"基于以下文档回答问题：\n\n{context}"
                    },
                    {
                        "type": "text",
                        "text": f"问题：{query}"
                    }
                ]
            }
        ]
        
        # 构建 completion 参数
        completion_kwargs = {
            "model": f"anthropic/{CacheConfig.ANTHROPIC_MODEL}",
            "messages": messages,
            "max_tokens": 1024,
            "caching": True,  # LiteLLM 缓存
        }
        
        # Provider 原生缓存（Prompt Caching）
        if use_provider_cache:
            # 为上下文内容添加 cache_control
            messages[0]["content"][0]["cache_control"] = {"type": "ephemeral"}
            
            # 透传 Anthropic beta header
            completion_kwargs["extra_headers"] = {
                "anthropic-beta": "prompt-caching-2024-07-31"
            }
        
        # 语义缓存
        if self.semantic_cache_config:
            completion_kwargs["cache"] = self.semantic_cache_config
        
        # 执行查询
        response = completion(**completion_kwargs)
        
        # 计算延迟
        latency_ms = (time.time() - start_time) * 1000
        
        # 提取缓存信息
        cache_hit = self._extract_cache_info(response)
        
        return {
            "answer": response.choices[0].message.content,
            "cache_hit": cache_hit,
            "latency_ms": latency_ms,
            "tokens": {
                "input": response.usage.prompt_tokens,
                "output": response.usage.completion_tokens,
                "total": response.usage.total_tokens
            }
        }
    
    def _extract_cache_info(self, response) -> str:
        """从响应中提取缓存命中信息"""
        # 检查 LiteLLM 缓存命中
        if hasattr(response, '_hidden_params') and response._hidden_params.get('cache_hit'):
            return "redis"
        
        # 检查语义缓存
        if hasattr(response, '_hidden_params'):
            metadata = response._hidden_params.get('metadata', {})
            if metadata.get('cache_hit') == 'semantic':
                return "semantic"
        
        # 检查 Provider 缓存
        if hasattr(response, 'usage'):
            # Anthropic 缓存读取会有 cache_read_input_tokens
            if hasattr(response.usage, 'cache_read_input_tokens'):
                return "provider"
        
        return "miss"

# 使用示例
if __name__ == "__main__":
    cache = RAGCache()
    
    context = "公司是 2020 年成立的，总部位于北京..."
    query = "公司什么时候成立的？"
    
    # 第一次查询（缓存未命中）
    result1 = cache.query(query, context)
    print(f"查询 1: {result1['cache_hit']}, 延迟：{result1['latency_ms']:.0f}ms")
    
    # 第二次查询（Redis 缓存命中）
    result2 = cache.query(query, context)
    print(f"查询 2: {result2['cache_hit']}, 延迟：{result2['latency_ms']:.0f}ms")
    
    # 相似问题（语义缓存可能命中）
    result3 = cache.query("公司成立时间？", context)
    print(f"查询 3: {result3['cache_hit']}, 延迟：{result3['latency_ms']:.0f}ms")
```

---

### 3.3 生产封装：FastAPI 服务

```python
# app.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from cache_advanced import RAGCache
from config import CacheConfig
import logging

# 配置日志
logging.basicConfig(level=getattr(logging, CacheConfig.LOG_LEVEL))
logger = logging.getLogger(__name__)

app = FastAPI(title="RAG Cache Service", version="1.0.0")

# 初始化缓存
rag_cache = RAGCache()

class RAGQuery(BaseModel):
    query: str
    context: str
    use_provider_cache: bool = True

class RAGResponse(BaseModel):
    answer: str
    cache_hit: str
    latency_ms: float
    tokens: dict

@app.post("/rag/query", response_model=RAGResponse)
async def rag_query(request: RAGQuery):
    """
    RAG 查询接口
    
    三层缓存：
    1. Redis 缓存（完全相同查询）
    2. 语义缓存（相似问题）
    3. Provider 缓存（相同文档）
    """
    try:
        result = rag_cache.query(
            query=request.query,
            context=request.context,
            use_provider_cache=request.use_provider_cache
        )
        
        logger.info(f"查询完成，缓存命中：{result['cache_hit']}, 延迟：{result['latency_ms']:.0f}ms")
        
        return RAGResponse(**result)
    
    except Exception as e:
        logger.error(f"查询失败：{str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """健康检查"""
    return {"status": "healthy", "version": "1.0.0"}

@app.get("/metrics")
async def metrics():
    """监控指标（可扩展）"""
    return {
        "cache_enabled": True,
        "cache_ttl": CacheConfig.CACHE_TTL,
        "semantic_cache": CacheConfig.SEMANTIC_CACHE_ENABLED
    }

# 运行：uvicorn app:app --host 0.0.0.0 --port 8000
```

---

### 3.4 批量处理脚本

```python
# batch_process.py
"""
批量处理脚本 - 用于离线数据处理和缓存预热
"""
import litellm
from cache_advanced import RAGCache
from config import CacheConfig
import json
import time
from concurrent.futures import ThreadPoolExecutor

class BatchProcessor:
    """批量处理器"""
    
    def __init__(self, max_workers: int = 10):
        self.cache = RAGCache()
        self.max_workers = max_workers
        self.stats = {
            "total": 0,
            "cache_hit": 0,
            "cache_miss": 0,
            "errors": 0,
            "total_latency_ms": 0
        }
    
    def process_query(self, item: dict) -> dict:
        """处理单个查询"""
        try:
            result = self.cache.query(
                query=item["query"],
                context=item["context"],
                use_provider_cache=True
            )
            
            self.stats["total"] += 1
            if result["cache_hit"] != "miss":
                self.stats["cache_hit"] += 1
            else:
                self.stats["cache_miss"] += 1
            self.stats["total_latency_ms"] += result["latency_ms"]
            
            return {
                "query": item["query"],
                "answer": result["answer"],
                "cache_hit": result["cache_hit"],
                "latency_ms": result["latency_ms"]
            }
        
        except Exception as e:
            self.stats["errors"] += 1
            return {
                "query": item["query"],
                "error": str(e)
            }
    
    def process_batch(self, queries: list, output_file: str):
        """
        批量处理查询
        
        Args:
            queries: 查询列表 [{"query": "...", "context": "..."}, ...]
            output_file: 输出文件路径
        """
        results = []
        start_time = time.time()
        
        # 线程池并发处理
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = [executor.submit(self.process_query, q) for q in queries]
            
            for i, future in enumerate(futures):
                result = future.result()
                results.append(result)
                
                # 进度日志
                if (i + 1) % 100 == 0:
                    elapsed = time.time() - start_time
                    avg_latency = self.stats["total_latency_ms"] / max(1, self.stats["total"])
                    hit_rate = self.stats["cache_hit"] / max(1, self.stats["total"]) * 100
                    
                    print(f"进度：{i+1}/{len(queries)}, "
                          f"命中率：{hit_rate:.1f}%, "
                          f"平均延迟：{avg_latency:.0f}ms, "
                          f"耗时：{elapsed:.1f}s")
        
        # 保存结果
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump({
                "results": results,
                "stats": self.stats,
                "summary": {
                    "total_queries": self.stats["total"],
                    "cache_hit_rate": f"{self.stats['cache_hit']/max(1, self.stats['total'])*100:.1f}%",
                    "avg_latency_ms": f"{self.stats['total_latency_ms']/max(1, self.stats['total']):.0f}",
                    "errors": self.stats["errors"],
                    "total_time_s": time.time() - start_time
                }
            }, f, ensure_ascii=False, indent=2)
        
        print(f"\n批量处理完成！")
        print(f"总查询数：{self.stats['total']}")
        print(f"缓存命中率：{self.stats['cache_hit']/max(1, self.stats['total'])*100:.1f}%")
        print(f"平均延迟：{self.stats['total_latency_ms']/max(1, self.stats['total']):.0f}ms")
        print(f"错误数：{self.stats['errors']}")
        print(f"结果已保存至：{output_file}")

# 使用示例
if __name__ == "__main__":
    # 加载测试数据
    with open("test_queries.json", "r", encoding="utf-8") as f:
        queries = json.load(f)
    
    # 批量处理
    processor = BatchProcessor(max_workers=10)
    processor.process_batch(queries, "batch_results.json")
```

---

## 4. 测试方案

### 4.1 单元测试

```python
# test_cache.py
import pytest
from cache_advanced import RAGCache

@pytest.fixture
def cache():
    return RAGCache()

def test_cache_hit(cache):
    """测试缓存命中"""
    context = "测试文档内容" * 100  # 确保超过最小缓存长度
    query = "测试问题"
    
    # 第一次查询（未命中）
    result1 = cache.query(query, context)
    assert result1["cache_hit"] == "miss"
    
    # 第二次查询（应命中）
    result2 = cache.query(query, context)
    assert result2["cache_hit"] in ["redis", "semantic", "provider"]
    assert result2["latency_ms"] < result1["latency_ms"]

def test_semantic_cache(cache):
    """测试语义缓存"""
    context = "测试文档" * 100
    
    # 原始问题
    result1 = cache.query("公司成立时间？", context)
    
    # 相似问题（应触发语义缓存）
    result2 = cache.query("公司什么时候成立的？", context)
    
    # 答案应相似
    assert result1["answer"][:50] == result2["answer"][:50]

def test_provider_cache(cache):
    """测试 Provider 缓存"""
    context = "长文档" * 1000  # 大文档
    
    # 相同文档，不同问题
    result1 = cache.query("问题 1", context, use_provider_cache=True)
    result2 = cache.query("问题 2", context, use_provider_cache=True)
    
    # 第二次应命中 Provider 缓存
    assert result2["cache_hit"] == "provider"
    assert result2["tokens"]["input"] < result1["tokens"]["input"]  # 输入 token 减少
```

### 4.2 性能测试

```python
# performance_test.py
"""
性能测试脚本
"""
import time
import statistics
from cache_advanced import RAGCache

def benchmark_cache(cache: RAGCache, query: str, context: str, iterations: int = 10):
    """
    基准测试
    
    Returns:
        dict: 性能指标
    """
    latencies = []
    cache_hits = []
    
    for i in range(iterations):
        result = cache.query(query, context)
        latencies.append(result["latency_ms"])
        cache_hits.append(result["cache_hit"])
    
    return {
        "min_ms": min(latencies),
        "max_ms": max(latencies),
        "avg_ms": statistics.mean(latencies),
        "median_ms": statistics.median(latencies),
        "p95_ms": sorted(latencies)[int(len(latencies) * 0.95)],
        "cache_hit_rate": f"{cache_hits.count('redis') + cache_hits.count('semantic') + cache_hits.count('provider')}/{iterations}",
        "cache_types": {
            "redis": cache_hits.count("redis"),
            "semantic": cache_hits.count("semantic"),
            "provider": cache_hits.count("provider"),
            "miss": cache_hits.count("miss")
        }
    }

if __name__ == "__main__":
    cache = RAGCache()
    
    # 测试场景 1：完全相同查询
    print("=" * 50)
    print("场景 1：完全相同查询（Redis 缓存）")
    print("=" * 50)
    result1 = benchmark_cache(cache, "公司成立时间？", "公司文档" * 100)
    print(f"最小延迟：{result1['min_ms']:.0f}ms")
    print(f"平均延迟：{result1['avg_ms']:.0f}ms")
    print(f"P95 延迟：{result1['p95_ms']:.0f}ms")
    print(f"缓存命中：{result1['cache_hit_rate']}")
    print(f"缓存类型：{result1['cache_types']}")
    
    # 测试场景 2：相似问题
    print("\n" + "=" * 50)
    print("场景 2：相似问题（语义缓存）")
    print("=" * 50)
    # ... 类似测试
    
    # 测试场景 3：相同文档不同问题
    print("\n" + "=" * 50)
    print("场景 3：相同文档不同问题（Provider 缓存）")
    print("=" * 50)
    # ... 类似测试
```

### 4.3 测试数据生成

```python
# generate_test_data.py
"""
生成测试数据
"""
import json

test_queries = [
    {
        "query": "公司什么时候成立的？",
        "context": "公司成立于 2020 年，总部位于北京中关村..." * 50
    },
    {
        "query": "公司的主要产品是什么？",
        "context": "公司主要产品包括 AI 助手、RAG 系统、数据分析平台..." * 50
    },
    {
        "query": "如何优化 RAG 系统的检索速度？",
        "context": "RAG 系统优化方法：1.使用向量数据库 2.实现缓存层 3.优化检索策略..." * 50
    },
    # ... 更多测试查询
]

with open("test_queries.json", "w", encoding="utf-8") as f:
    json.dump(test_queries, f, ensure_ascii=False, indent=2)

print(f"已生成 {len(test_queries)} 条测试数据")
```

---

## 5. 监控方案

### 5.1 监控指标

| 指标 | 说明 | 告警阈值 |
|------|------|---------|
| **Cache Hit Rate** | 缓存命中率 | <30% |
| **平均延迟** | 平均响应时间 | >3s |
| **P95 延迟** | 95% 请求延迟 | >5s |
| **错误率** | 请求失败率 | >1% |
| **Redis 内存使用** | 缓存占用内存 | >80% |
| **Token 使用量** | LLM Token 消耗 | 突增 50% |

### 5.2 Prometheus + Grafana

```python
# metrics.py
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time

# 定义指标
CACHE_REQUESTS = Counter('rag_cache_requests_total', 'Total cache requests', ['cache_type'])
CACHE_LATENCY = Histogram('rag_cache_latency_seconds', 'Cache latency', ['cache_type'])
CACHE_HITS = Counter('rag_cache_hits_total', 'Total cache hits', ['cache_type'])
TOKENS_USED = Counter('rag_tokens_total', 'Total tokens used', ['type'])

class MetricsCollector:
    def __init__(self):
        start_http_server(8000)  # Prometheus 抓取端口
    
    def record_request(self, result: dict):
        """记录请求指标"""
        cache_type = result.get('cache_hit', 'miss')
        CACHE_REQUESTS.labels(cache_type=cache_type).inc()
        CACHE_LATENCY.labels(cache_type=cache_type).observe(result['latency_ms'] / 1000)
        
        if cache_type != 'miss':
            CACHE_HITS.labels(cache_type=cache_type).inc()
        
        TOKENS_USED.labels(type='input').inc(result['tokens']['input'])
        TOKENS_USED.labels(type='output').inc(result['tokens']['output'])

# 使用
metrics = MetricsCollector()
result = cache.query(query, context)
metrics.record_request(result)
```

### 5.3 日志记录

```python
# logging_config.py
import logging
import json
from datetime import datetime

class CacheLogger:
    def __init__(self, log_file: str = "cache.log"):
        self.logger = logging.getLogger("rag_cache")
        self.logger.setLevel(logging.INFO)
        
        handler = logging.FileHandler(log_file)
        handler.setFormatter(logging.Formatter('%(asctime)s - %(message)s'))
        self.logger.addHandler(handler)
    
    def log_query(self, result: dict):
        """记录查询日志"""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "cache_hit": result["cache_hit"],
            "latency_ms": result["latency_ms"],
            "tokens": result["tokens"],
            "cost_estimate": self._estimate_cost(result["tokens"])
        }
        self.logger.info(json.dumps(log_entry))
    
    def _estimate_cost(self, tokens: dict) -> float:
        """估算成本（Claude Sonnet 定价）"""
        input_cost = tokens["input"] * 3 / 1_000_000
        output_cost = tokens["output"] * 15 / 1_000_000
        return input_cost + output_cost

# 使用
logger = CacheLogger()
result = cache.query(query, context)
logger.log_query(result)
```

---

## 6. 故障排查

### 6.1 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| **缓存不命中** | Redis 连接失败 | 检查 Redis 服务和网络 |
| **缓存命中率低** | TTL 太短 | 增加 CACHE_TTL |
| **延迟未降低** | 上下文太短 | 确保>1K tokens（最小缓存长度） |
| **Provider 缓存未生效** | 未添加 beta header | 检查 extra_headers 配置 |
| **Redis 内存溢出** | 缓存数据过多 | 配置 maxmemory 和淘汰策略 |

### 6.2 诊断脚本

```python
# diagnose.py
"""
缓存系统诊断脚本
"""
import redis
import litellm
from config import CacheConfig

def diagnose():
    print("=" * 50)
    print("LiteLLM 缓存系统诊断")
    print("=" * 50)
    
    # 1. 检查 Redis 连接
    print("\n1. Redis 连接检查")
    try:
        r = redis.Redis(
            host=CacheConfig.REDIS_HOST,
            port=CacheConfig.REDIS_PORT,
            password=CacheConfig.REDIS_PASSWORD
        )
        r.ping()
        print(f"   ✅ Redis 连接成功 ({CacheConfig.REDIS_HOST}:{CacheConfig.REDIS_PORT})")
        
        # Redis 信息
        info = r.info()
        print(f"   - Redis 版本：{info['redis_version']}")
        print(f"   - 已用内存：{info['used_memory_human']}")
        print(f"   - 连接数：{info['connected_clients']}")
    
    except Exception as e:
        print(f"   ❌ Redis 连接失败：{str(e)}")
        return
    
    # 2. 检查 LiteLLM 缓存配置
    print("\n2. LiteLLM 缓存配置")
    if litellm.cache:
        print(f"   ✅ 缓存已启用")
        print(f"   - 类型：{litellm.cache.type}")
        print(f"   - TTL: {litellm.cache.ttl}s")
    else:
        print(f"   ❌ 缓存未启用")
    
    # 3. 测试缓存写入
    print("\n3. 缓存写入测试")
    try:
        r.set("test:key", "test_value", ex=60)
        value = r.get("test:key")
        if value == b"test_value":
            print(f"   ✅ 缓存写入/读取成功")
        else:
            print(f"   ❌ 缓存读取失败")
    except Exception as e:
        print(f"   ❌ 缓存测试失败：{str(e)}")
    
    # 4. 检查 API Keys
    print("\n4. API Keys 检查")
    import os
    if os.getenv("ANTHROPIC_API_KEY"):
        print(f"   ✅ Anthropic API Key 已配置")
    else:
        print(f"   ❌ Anthropic API Key 未配置")
    
    if os.getenv("OPENAI_API_KEY"):
        print(f"   ✅ OpenAI API Key 已配置")
    else:
        print(f"   ❌ OpenAI API Key 未配置")
    
    print("\n" + "=" * 50)
    print("诊断完成")
    print("=" * 50)

if __name__ == "__main__":
    diagnose()
```

---

## 7. 成本估算

### 7.1 假设条件

| 参数 | 值 |
|------|-----|
| 日查询量 | 10,000 次 |
| 平均输入 tokens | 10,000 |
| 平均输出 tokens | 2,000 |
| 模型 | Claude Sonnet |
| 工作日 | 22 天/月 |

### 7.2 成本对比

#### 无缓存

```
输入成本：10,000 查询 × 22 天 × 10K tokens × $3/1M = $6,600/月
输出成本：10,000 查询 × 22 天 × 2K tokens × $15/1M = $6,600/月
总计：$13,200/月
```

#### 有缓存（70% 命中率）

```
LLM 调用：10,000 × 22 × 30% = 66,000 次/月

输入成本：66,000 × 10K tokens × $3/1M = $1,980/月
输出成本：66,000 × 2K tokens × $15/1M = $1,980/月

缓存成本：
- Redis: ~$50/月
- Embedding（语义缓存）: ~$20/月

总计：$4,030/月

节省：$13,200 - $4,030 = $9,170/月 (69.5%)
```

### 7.3 ROI 分析

| 项目 | 成本 |
|------|------|
| **实施成本** | |
| - 开发时间（3 天） | ¥15,000 |
| - 测试时间（2 天） | ¥10,000 |
| - 部署时间（1 天） | ¥5,000 |
| **月度成本** | |
| - Redis 服务器 | ¥350 |
| - 应用服务器 | ¥500 |
| - Embedding API | ¥150 |
| **月度节省** | **¥66,000** ($9,170) |
| **投资回收期** | **<1 周** |

---

## 8. 部署检查清单

### 8.1 部署前

- [ ] Redis 服务器已部署并测试
- [ ] API Keys 已配置
- [ ] 配置文件已更新
- [ ] 测试数据已准备
- [ ] 监控已配置

### 8.2 部署中

- [ ] 代码已部署到服务器
- [ ] 依赖已安装
- [ ] 服务已启动
- [ ] 健康检查通过
- [ ] 日志正常

### 8.3 部署后

- [ ] 性能测试通过
- [ ] 缓存命中率>30%
- [ ] 平均延迟<3s
- [ ] 错误率<1%
- [ ] 监控告警配置完成

---

## 9. 下一步行动

### 本周（POC 阶段）

- [ ] 部署 Redis（Docker）
- [ ] 实现基础缓存代码
- [ ] 运行性能测试
- [ ] 编写测试报告

### 下周（试点阶段）

- [ ] 集成到现有 RAG 系统
- [ ] 配置监控告警
- [ ] 小流量测试（10%）
- [ ] 收集性能数据

### 下月（生产阶段）

- [ ] 全量上线
- [ ] 优化缓存策略
- [ ] 编写运维文档
- [ ] 团队培训

---

## 🔗 相关资源

| 资源 | 链接 |
|------|------|
| LiteLLM 文档 | https://docs.litellm.ai |
| LiteLLM 缓存 | https://docs.litellm.ai/docs/caching |
| Redis 文档 | https://redis.io/docs |
| Anthropic Prompt Caching | https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching |

---

**文档版本**：1.0  
**最后更新**：2026-02-28  
**负责人**：Eddy
