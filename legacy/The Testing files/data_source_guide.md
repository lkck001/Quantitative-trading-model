# EURUSD历史数据获取指南

本指南说明如何从多个数据源获取EURUSD 2024-01-01至2025-01-01的H1历史数据。

---

## 🚀 快速开始（推荐）

### 方法1：自动获取（最简单）

程序会自动尝试多个数据源，按优先级顺序：

```python
from forex_data_fetcher import ForexDataFetcher

# 自动尝试所有可用数据源
df = ForexDataFetcher.fetch_auto(
    symbol='EURUSD',
    timeframe='H1',
    start_date='2024-01-01',
    end_date='2025-01-01'
)

# 保存数据
df.to_csv('EURUSD_H1.csv')
```

**优先级顺序：**
1. MetaTrader5（最准确）
2. investpy（免费）
3. yfinance（免费）
4. yahooquery（免费）
5. Polygon.io（需要API key）

---

## 📊 各数据源详细说明

### 1. MetaTrader5（⭐⭐⭐⭐⭐ 最推荐）

**优点：**
- ✅ 数据最准确，与MT5终端完全一致
- ✅ 支持所有货币对和时间周期
- ✅ 完全免费（只需安装MT5终端）

**安装步骤：**

```bash
# 1. 安装Python库
pip install MetaTrader5

# 2. 下载并安装MT5终端
# 下载地址：https://www.metatrader5.com/zh/download

# 3. 登录任意MT5账户（模拟账户即可）
```

**使用方法：**

```python
from forex_data_fetcher import ForexDataFetcher

df = ForexDataFetcher.fetch_from_mt5(
    symbol='EURUSD',
    timeframe='H1',
    start_date='2024-01-01',
    end_date='2025-01-01'
)
```

**注意事项：**
- 运行前确保MT5终端已启动并登录
- 货币对名称：`EURUSD`（无斜杠）
- 时间周期：`H1`, `H4`, `D1` 等

---

### 2. investpy（⭐⭐⭐⭐ 免费推荐）

**优点：**
- ✅ 完全免费
- ✅ 数据质量好
- ✅ 无需注册

**缺点：**
- ⚠️ 有时因网站更新而失效

**安装：**

```bash
pip install investpy
```

**使用方法：**

```python
from forex_data_fetcher import ForexDataFetcher

df = ForexDataFetcher.fetch_from_investpy(
    symbol='EUR/USD',  # 注意：需要斜杠
    timeframe='1hour',  # 或 '4hours', 'daily'
    start_date='2024-01-01',
    end_date='2025-01-01'
)
```

**时间周期映射：**
- `H1` → `'1hour'`
- `H4` → `'4hours'`
- `D1` → `'daily'`

---

### 3. yfinance（⭐⭐⭐ 备选方案）

**优点：**
- ✅ 免费
- ✅ 安装简单

**缺点：**
- ⚠️ 外汇数据可能不完整
- ⚠️ 历史数据可能有缺失

**安装：**

```bash
pip install yfinance
```

**使用方法：**

```python
from forex_data_fetcher import ForexDataFetcher

df = ForexDataFetcher.fetch_from_yfinance(
    symbol='EURUSD=X',  # 注意：需要 =X 后缀
    start_date='2024-01-01',
    end_date='2025-01-01',
    interval='1h'  # '1h', '4h', '1d'
)
```

---

### 4. yahooquery（⭐⭐⭐ 备选方案）

**优点：**
- ✅ 免费
- ✅ 有时比yfinance更稳定

**安装：**

```bash
pip install yahooquery
```

**使用方法：**

```python
from forex_data_fetcher import ForexDataFetcher

df = ForexDataFetcher.fetch_from_yahooquery(
    symbol='EURUSD=X',
    start_date='2024-01-01',
    end_date='2025-01-01',
    interval='1h'
)
```

---

### 5. Polygon.io（⭐⭐⭐⭐ 需要API key）

**优点：**
- ✅ 数据质量高
- ✅ 支持高频数据
- ✅ 免费版可用（有调用限制）

**缺点：**
- ⚠️ 需要注册获取API key

**安装：**

```bash
pip install polygon-api-client
```

**获取API key：**
1. 访问 https://polygon.io/
2. 注册免费账户
3. 在Dashboard中获取API key

**使用方法：**

```python
from forex_data_fetcher import ForexDataFetcher

# 替换为你的API key
API_KEY = 'your_api_key_here'

df = ForexDataFetcher.fetch_from_polygon(
    api_key=API_KEY,
    symbol='C:EURUSD',  # 注意：需要 C: 前缀
    start_date='2024-01-01',
    end_date='2025-01-01',
    timespan='hour',  # 'hour', 'day'
    multiplier=1
)
```

---

## 🔧 完整使用示例

### 示例1：直接运行数据获取脚本

```bash
# 运行数据获取脚本
python forex_data_fetcher.py
```

脚本会自动尝试所有数据源，并将数据保存为 `EURUSD_H1.csv`

### 示例2：在能量系统程序中使用

```python
# energy_system_detector.py 已自动集成
# 直接运行主程序即可
python energy_system_detector.py
```

程序会：
1. 自动尝试从网络获取数据
2. 如果失败，使用模拟数据（用于测试）
3. 识别交易机会并生成截图

### 示例3：手动指定数据源

```python
from forex_data_fetcher import ForexDataFetcher

# 优先尝试MT5
df = ForexDataFetcher.fetch_from_mt5('EURUSD', 'H1', '2024-01-01', '2025-01-01')

# 如果MT5失败，尝试investpy
if df is None:
    df = ForexDataFetcher.fetch_from_investpy('EUR/USD', '1hour', '2024-01-01', '2025-01-01')

# 保存数据
if df is not None:
    df.to_csv('EURUSD_H1.csv')
    print(f"成功获取 {len(df)} 条数据")
```

---

## 📋 数据格式要求

所有数据源返回的数据格式统一为：

```python
# DataFrame格式
            Open    High     Low    Close  Volume
Time                                              
2024-01-01  1.10465  1.10520  1.10400  1.10480    5000
2024-01-02  1.10480  1.10550  1.10460  1.10530    4500
...
```

**列名要求：**
- `Time` 或 `time`：时间索引
- `Open`, `High`, `Low`, `Close`：OHLC价格
- `Volume`：成交量（可选）

---

## ⚠️ 常见问题

### Q1: MT5连接失败怎么办？

**可能原因：**
1. MT5终端未启动
2. 未登录MT5账户
3. 网络问题

**解决方案：**
- 确保MT5终端正在运行
- 登录任意MT5账户（模拟账户即可）
- 检查防火墙设置

### Q2: investpy获取失败？

**原因：**
- investpy依赖的网站可能更新，导致API失效

**解决方案：**
- 使用MT5（最可靠）
- 或尝试其他数据源（yfinance, yahooquery）

### Q3: 数据不完整怎么办？

**检查：**
1. 时间范围内是否有数据（排除周末）
2. 数据源是否支持该时间范围
3. 网络连接是否正常

**解决方案：**
- 使用MT5（数据最完整）
- 分段获取数据后合并

### Q4: 如何验证数据质量？

```python
# 检查数据
print(f"数据量: {len(df)}")
print(f"时间范围: {df.index[0]} 至 {df.index[-1]}")
print(f"缺失值: {df.isnull().sum()}")
print(f"价格范围: {df['Low'].min():.5f} - {df['High'].max():.5f}")

# 检查是否有异常值
print(f"异常值检查:")
print(df.describe())
```

---

## 🎯 推荐方案

### 最佳方案（推荐）：

1. **安装MT5终端** + 使用 `MetaTrader5` 库
   - 数据最准确
   - 完全免费
   - 与交易平台一致

2. **备选方案**：使用 `investpy`
   - 无需安装软件
   - 完全免费
   - 数据质量好

### 快速测试：

```bash
# 1. 安装依赖
pip install MetaTrader5 investpy yfinance yahooquery

# 2. 运行数据获取脚本
python forex_data_fetcher.py

# 3. 检查生成的数据文件
# EURUSD_H1.csv
```

---

## 📝 数据保存

获取数据后，建议保存为CSV文件：

```python
# 保存数据
df.to_csv('EURUSD_H1.csv', index=True)

# 或保存为其他格式
df.to_excel('EURUSD_H1.xlsx')
df.to_pickle('EURUSD_H1.pkl')  # 更快，但文件更大
```

---

## 🔗 相关资源

- **MT5下载**：https://www.metatrader5.com/zh/download
- **Polygon.io**：https://polygon.io/
- **investpy文档**：https://investpy.readthedocs.io/
- **yfinance文档**：https://github.com/ranaroussi/yfinance

---

祝您数据获取顺利！🚀

