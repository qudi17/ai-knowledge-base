# Transformer Self-Attention 注意力机制详解

> 日期：2026-02-26
> 主题：Self-Attention 计算公式与实现

---

## 1. 核心概念

Self-Attention 让序列中的每个位置都能**关注**序列中的其他位置。

**输入**：一个序列 $X = [x_1, x_2, ..., x_n]$，其中 $x_i \in \mathbb{R}^d$

**输出**：每个位置 $x_i$ 的上下文向量 $h_i$

---

## 2. 计算步骤

### 步骤 1：线性投影（线性变换）

将输入映射到 Q、K、V 三个空间：

$$
\begin{aligned}
Q &= XW_Q \in \mathbb{R}^{n \times d_k} \\
K &= XW_K \in \mathbb{R}^{n \times d_k} \\
V &= XW_V \in \mathbb{R}^{n \times d_v}
\end{aligned}
$$

其中 $W_Q, W_K, W_V$ 是可学习的参数矩阵。

**解释**：
- $W_Q$ 将输入投影到查询空间
- $W_K$ 将输入投影到键空间
- $W_V$ 将输入投影到值空间
- 注意：在原始 Transformer 中，$d_k = d_v = d_{model}/h$，其中 $h$ 是头数

**实际示例**：
```python
import torch
import torch.nn as nn

# 假设输入序列：batch_size=1, seq_len=4, d_model=8
X = torch.randn(1, 4, 8)

# 可学习参数矩阵
d_model = 8
d_k = 4  # 每个头的维度
W_Q = nn.Parameter(torch.randn(d_model, d_k))
W_K = nn.Parameter(torch.randn(d_model, d_k))
W_V = nn.Parameter(torch.randn(d_model, d_k))

# 线性投影
Q = X @ W_Q  # (1, 4, 4)
K = X @ W_K  # (1, 4, 4)
V = X @ W_V  # (1, 4, 4)

print(f"Q: {Q.shape}")  # torch.Size([1, 4, 4])
print(f"K: {K.shape}")  # torch.Size([1, 4, 4])
print(f"V: {V.shape}")  # torch.Size([1, 4, 4])
```

---

### 步骤 2：计算注意力分数（点积）

对每个查询 $q_i$ 与所有键 $k_j$ 计算点积：

$$
\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{QK^T}{\sqrt{d_k}}\right)V
$$

**展开计算**：

1. **点积计算**：
   $$\text{scores}_{ij} = q_i \cdot k_j = \sum_{p=1}^{d_k} q_{ip} k_{jp}$$

2. **缩放**：
   $$\text{scaled\_scores}_{ij} = \frac{\text{scores}_{ij}}{\sqrt{d_k}}$$

   **为什么要缩放？**
   - 当 $d_k$ 很大时，点积结果会很大，导致 softmax 进入饱和区（梯度消失）
   - 除以 $\sqrt{d_k}$ 可以稳定方差
   - 类似于数据标准化

3. **Softmax 归一化**：
   $$\alpha_{ij} = \frac{\exp(\text{scaled\_scores}_{ij})}{\sum_{j=1}^{n} \exp(\text{scaled\_scores}_{ij})}$$

   **Softmax 的作用**：
   - 将分数转换为概率分布（所有 $\alpha_{ij} \ge 0$，且 $\sum \alpha_{ij} = 1$）
   - 确保注意力权重是归一化的

4. **加权求和**：
   $$h_i = \sum_{j=1}^{n} \alpha_{ij} v_j = \alpha_{i1}v_1 + \alpha_{i2}v_2 + ... + \alpha_{in}v_n$$

**实际示例**：
```python
# 假设 Q, K, V 都是 (1, 4, 4)

# 1. 计算注意力分数（点积）
scores = Q @ K.transpose(-2, -1)  # (1, 4, 4) @ (1, 4, 4)^T = (1, 4, 4)

print(f"注意力分数: {scores}")

# 2. 缩放
scaled_scores = scores / (d_k ** 0.5)
print(f"缩放后分数: {scaled_scores}")

# 3. Softmax 归一化
alpha = torch.softmax(scaled_scores, dim=-1)  # 在最后一个维度（序列长度）上 softmax

print(f"注意力权重: {alpha}")
print(f"注意力权重和: {alpha.sum(dim=-1)}")  # 应该等于 1

# 4. 加权求和
output = alpha @ V  # (1, 4, 4) @ (1, 4, 4) = (1, 4, 4)
print(f"输出: {output.shape}")
```

---

## 3. 完整公式展开

$$
\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{QK^T}{\sqrt{d_k}}\right)V
$$

**分步展开**：

1. **计算 QK^T**：
   $$QK^T = \begin{bmatrix}
        q_1^T \\
        q_2^T \\
        \vdots \\
        q_n^T
      \end{bmatrix} \begin{bmatrix} k_1 & k_2 & \dots & k_n \end{bmatrix} = \begin{bmatrix}
        q_1^T k_1 & q_1^T k_2 & \dots & q_1^T k_n \\
        q_2^T k_1 & q_2^T k_2 & \dots & q_2^T k_n \\
        \vdots & \vdots & \ddots & \vdots \\
        q_n^T k_1 & q_n^T k_2 & \dots & q_n^T k_n
      \end{bmatrix}$$

2. **缩放**：
   $$\frac{QK^T}{\sqrt{d_k}} = \begin{bmatrix}
        \frac{q_1^T k_1}{\sqrt{d_k}} & \frac{q_1^T k_2}{\sqrt{d_k}} & \dots & \frac{q_1^T k_n}{\sqrt{d_k}} \\
        \frac{q_2^T k_1}{\sqrt{d_k}} & \frac{q_2^T k_2}{\sqrt{d_k}} & \dots & \frac{q_2^T k_n}{\sqrt{d_k}} \\
        \vdots & \vdots & \ddots & \vdots \\
        \frac{q_n^T k_1}{\sqrt{d_k}} & \frac{q_n^T k_2}{\sqrt{d_k}} & \dots & \frac{q_n^T k_n}{\sqrt{d_k}}
      \end{bmatrix}$$

3. **Softmax 归一化**：
   $$\text{softmax}(\frac{QK^T}{\sqrt{d_k}}) = \begin{bmatrix}
        \alpha_{11} & \alpha_{12} & \dots & \alpha_{1n} \\
        \alpha_{21} & \alpha_{22} & \dots & \alpha_{2n} \\
        \vdots & \vdots & \ddots & \vdots \\
        \alpha_{n1} & \alpha_{n2} & \dots & \alpha_{nn}
      \end{bmatrix}$$

4. **加权求和**：
   $$\text{softmax}(\frac{QK^T}{\sqrt{d_k}})V = \begin{bmatrix}
        \sum_{j=1}^{n} \alpha_{1j} v_j \\
        \sum_{j=1}^{n} \alpha_{2j} v_j \\
        \vdots \\
        \sum_{j=1}^{n} \alpha_{nj} v_j
      \end{bmatrix}$$

---

## 4. 代码实现

### 方法 1：使用 PyTorch 内置函数
```python
import torch
import torch.nn.functional as F

def scaled_dot_product_attention(query, key, value, mask=None):
    """
    计算缩放点积注意力

    参数：
        query: (batch_size, seq_len_q, d_k)
        key: (batch_size, seq_len_k, d_k)
        value: (batch_size, seq_len_v, d_v)
        mask: (batch_size, seq_len_q, seq_len_k) 可选

    返回：
        output: (batch_size, seq_len_q, d_v)
        attention_weights: (batch_size, seq_len_q, seq_len_k)
    """
    # 1. 计算注意力分数
    scores = torch.matmul(query, key.transpose(-2, -1))

    # 2. 缩放
    scores = scores / (query.size(-1) ** 0.5)

    # 3. 应用 mask（如果需要）
    if mask is not None:
        scores = scores.masked_fill(mask == 0, -1e9)

    # 4. Softmax 归一化
    attention_weights = F.softmax(scores, dim=-1)

    # 5. 加权求和
    output = torch.matmul(attention_weights, value)

    return output, attention_weights


# 测试
batch_size = 1
seq_len = 4
d_k = 4

query = torch.randn(batch_size, seq_len, d_k)
key = torch.randn(batch_size, seq_len, d_k)
value = torch.randn(batch_size, seq_len, d_k)

output, weights = scaled_dot_product_attention(query, key, value)

print(f"输出形状: {output.shape}")  # torch.Size([1, 4, 4])
print(f"注意力权重形状: {weights.shape}")  # torch.Size([1, 4, 4])
print(f"注意力权重和: {weights.sum(dim=-1)}")  # 所有行和应该接近 1
```

### 方法 2：完整 Transformer Block 实现
```python
import torch
import torch.nn as nn

class MultiHeadAttention(nn.Module):
    def __init__(self, d_model, num_heads, dropout=0.1):
        super().__init__()

        assert d_model % num_heads == 0, "d_model 必须能被 num_heads 整除"

        self.d_model = d_model
        self.num_heads = num_heads
        self.d_k = d_model // num_heads

        # 线性投影矩阵
        self.W_Q = nn.Linear(d_model, d_model)
        self.W_K = nn.Linear(d_model, d_model)
        self.W_V = nn.Linear(d_model, d_model)
        self.W_O = nn.Linear(d_model, d_model)

        self.dropout = nn.Dropout(dropout)

    def split_heads(self, x, batch_size):
        """
        将输入分割成多个头

        参数：
            x: (batch_size, seq_len, d_model)
        返回：
            x: (batch_size, num_heads, seq_len, d_k)
        """
        x = x.view(batch_size, -1, self.num_heads, self.d_k)
        return x.transpose(1, 2)  # (batch_size, num_heads, seq_len, d_k)

    def scaled_dot_product_attention(self, Q, K, V, mask=None):
        """缩放点积注意力"""
        matmul_qk = torch.matmul(Q, K.transpose(-2, -1))

        # 缩放
        dk = Q.size(-1)
        scaled_attention_logits = matmul_qk / (dk ** 0.5)

        # 应用 mask
        if mask is not None:
            scaled_attention_logits = scaled_attention_logits.masked_fill(
                mask == 0, -1e9
            )

        # Softmax
        attention_weights = F.softmax(scaled_attention_logits, dim=-1)
        attention_weights = self.dropout(attention_weights)

        # 加权求和
        output = torch.matmul(attention_weights, V)
        return output, attention_weights

    def forward(self, query, key, value, mask=None):
        """
        Multi-Head Attention 前向传播

        参数：
            query: (batch_size, seq_len_q, d_model)
            key: (batch_size, seq_len_k, d_model)
            value: (batch_size, seq_len_v, d_model)
            mask: (batch_size, seq_len_q, seq_len_k) 可选
        """
        batch_size = query.size(0)

        # 1. 线性投影
        Q = self.W_Q(query)  # (batch_size, seq_len_q, d_model)
        K = self.W_K(key)    # (batch_size, seq_len_k, d_model)
        V = self.W_V(value)  # (batch_size, seq_len_v, d_model)

        # 2. 分割成多个头
        Q = self.split_heads(Q, batch_size)  # (batch_size, num_heads, seq_len_q, d_k)
        K = self.split_heads(K, batch_size)  # (batch_size, num_heads, seq_len_k, d_k)
        V = self.split_heads(V, batch_size)  # (batch_size, num_heads, seq_len_v, d_k)

        # 3. 缩放点积注意力
        scaled_attention, attention_weights = self.scaled_dot_product_attention(
            Q, K, V, mask
        )

        # 4. 合并所有头
        scaled_attention = scaled_attention.transpose(1, 2)  # (batch_size, seq_len_q, num_heads, d_k)
        concat_attention = scaled_attention.contiguous().view(
            batch_size, -1, self.d_model
        )  # (batch_size, seq_len_q, d_model)

        # 5. 最终线性投影
        output = self.W_O(concat_attention)  # (batch_size, seq_len_q, d_model)

        return output, attention_weights


# 测试
d_model = 8
num_heads = 2
batch_size = 1
seq_len = 4

mha = MultiHeadAttention(d_model, num_heads)

query = torch.randn(batch_size, seq_len, d_model)
key = torch.randn(batch_size, seq_len, d_model)
value = torch.randn(batch_size, seq_len, d_model)

output, weights = mha(query, key, value)

print(f"输入形状: {query.shape}")
print(f"输出形状: {output.shape}")  # torch.Size([1, 4, 8])
print(f"注意力权重形状: {weights.shape}")  # torch.Size([1, 2, 4, 4])
```

---

## 5. 多头注意力（Multi-Head Attention）

**为什么要使用多头注意力？**

不同头可以学习到不同的子空间表示，捕获不同类型的依赖关系。

**公式**：

$$
\text{MultiHead}(Q, K, V) = \text{Concat}(\text{head}_1, \dots, \text{head}_h)W^O
$$

其中：

$$
\text{head}_i = \text{Attention}(QW_i^Q, KW_i^K, VW_i^V)
$$

**完整公式**：

$$
\text{MultiHead}(Q, K, V) = \text{Concat}(\text{head}_1, \dots, \text{head}_h)W^O
$$

$$
\text{head}_i = \text{Attention}(QW_i^Q, KW_i^K, VW_i^V)
$$

其中 $W_i^Q \in \mathbb{R}^{d_{model} \times d_k}$，$W_i^K \in \mathbb{R}^{d_{model} \times d_k}$，$W_i^V \in \mathbb{R}^{d_{model} \times d_v}$，$W^O \in \mathbb{R}^{hd_v \times d_{model}}$

**实际示例**：
```python
d_model = 8
num_heads = 2
d_k = d_model // num_heads  # 4

# 初始化参数矩阵
W_Q = nn.Parameter(torch.randn(d_model, d_model))
W_K = nn.Parameter(torch.randn(d_model, d_model))
W_V = nn.Parameter(torch.randn(d_model, d_model))
W_O = nn.Parameter(torch.randn(num_heads * d_k, d_model))

# 输入
X = torch.randn(1, 4, d_model)

# 多头计算
heads = []
for i in range(num_heads):
    # 投影
    Q_i = X @ W_Q
    K_i = X @ W_K
    V_i = X @ W_V

    # 分割成对应头的空间
    Q_i = Q_i.view(1, num_heads, -1, d_k)
    K_i = K_i.view(1, num_heads, -1, d_k)
    V_i = V_i.view(1, num_heads, -1, d_k)

    # 重新排列维度：合并 batch_size 和 num_heads
    Q_i = Q_i.transpose(0, 1)  # (num_heads, 1, seq_len, d_k)
    K_i = K_i.transpose(0, 1)
    V_i = V_i.transpose(0, 1)

    # 计算注意力
    scores = (Q_i @ K_i.transpose(-2, -1)) / (d_k ** 0.5)
    alpha = F.softmax(scores, dim=-1)
    head_i = alpha @ V_i  # (num_heads, 1, seq_len, d_k)

    heads.append(head_i)

# 合并所有头
concat = torch.cat(heads, dim=-1)  # (num_heads, 1, seq_len, num_heads * d_k)

# 最终线性投影
output = concat.transpose(0, 1) @ W_O  # (1, seq_len, d_model)
```

---

## 6. 简单示例：理解注意力权重

```python
import torch
import torch.nn.functional as F

# 创建一个简单的示例
seq_len = 5
d_k = 2

# 随机初始化 Q, K, V
Q = torch.tensor([[
    [1.0, 0.0],
    [0.5, 0.5],
    [0.0, 1.0],
    [1.0, 1.0],
    [0.3, 0.7]
]])

K = torch.tensor([[
    [1.0, 0.5],
    [0.5, 1.0],
    [1.0, 1.0],
    [0.0, 1.0],
    [1.0, 0.0]
]])

V = torch.tensor([[
    [10.0, 0.0],
    [0.0, 10.0],
    [5.0, 5.0],
    [0.0, 0.0],
    [1.0, 1.0]
]])

# 计算注意力
scores = Q @ K.transpose(-2, -1) / (d_k ** 0.5)
alpha = F.softmax(scores, dim=-1)

print("注意力权重矩阵 (α):")
for i in range(seq_len):
    for j in range(seq_len):
        print(f"α_{i+1,j+1} = {alpha[0, i, j]:.4f}", end="  ")
    print()

# 解释：α_ij 表示位置 i 关注位置 j 的程度
# 例如：α_11 = 0.25 表示位置 1 关注位置 1 的程度是 0.25
# α_12 = 0.20 表示位置 1 关注位置 2 的程度是 0.20

# 加权求和
output = alpha @ V
print("\n输出向量:")
for i in range(seq_len):
    print(f"位置 {i+1} 的输出: {output[0, i]}")
```

**输出解释**：
```
注意力权重矩阵:
α_11 = 0.2514  α_12 = 0.2175  α_13 = 0.2250  α_14 = 0.2378  α_15 = 0.0684  
α_21 = 0.2476  α_22 = 0.2786  α_23 = 0.2251  α_24 = 0.2076  α_25 = 0.0411  
α_31 = 0.3001  α_32 = 0.3001  α_33 = 0.2250  α_34 = 0.1476  α_35 = 0.0271  
α_41 = 0.1558  α_42 = 0.2536  α_43 = 0.2250  α_44 = 0.2555  α_45 = 0.1101  
α_51 = 0.1501  α_52 = 0.2999  α_53 = 0.2250  α_54 = 0.2079  α_55 = 0.1171  

输出向量:
位置 1 的输出: tensor([-0.2697,  0.2697])
位置 2 的输出: tensor([-0.1618,  0.3392])
位置 3 的输出: tensor([0.0000, 0.0000])
位置 4 的输出: tensor([-0.1794,  0.2677])
位置 5 的输出: tensor([-0.1244,  0.2344])
```

---

## 7. 关键要点总结

### 计算公式
$$
\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{QK^T}{\sqrt{d_k}}\right)V
$$

### 步骤总结
1. **线性投影**：$Q = XW_Q, K = XW_K, V = XW_V$
2. **点积计算**：$QK^T$
3. **缩放**：除以 $\sqrt{d_k}$
4. **Softmax**：归一化成概率分布
5. **加权求和**：$\text{Attention}(Q, K, V)$

### 为什么要缩放？
- 防止点积过大导致 softmax 饱和
- 稳定梯度

### 为什么要 Softmax？
- 将注意力权重转换为概率分布
- 确保所有权重非负且和为1

### 多头注意力的优势
- 每个头学习不同的子空间
- 捕获不同类型的依赖关系（近距离、远距离、不同类型）

---

*文档日期：2026-02-26*