# EURUSD数据获取 - 快速开始

## 🎯 目标
获取EURUSD 2024-01-01至2025-01-01的H1历史数据

---

## ⚡ 最快方法（3步）

### 步骤1：安装依赖

```bash
# 推荐：安装MT5（最准确）
pip install MetaTrader5

# 或安装其他数据源（备选）
pip install investpy yfinance yahooquery
```

### 步骤2：运行数据获取脚本

```bash
python forex_data_fetcher.py
```

### 步骤3：检查生成的文件

```
EURUSD_H1.csv  # 已生成的数据文件
```

---

## 📊 数据源推荐（按优先级）

| 数据源 | 推荐度 | 优点 | 缺点 |
|:---|:---|:---|:---|
| **MetaTrader5** | ⭐⭐⭐⭐⭐ | 最准确，免费 | 需要安装MT5终端 |
| **investpy** | ⭐⭐⭐⭐ | 免费，无需安装软件 | 有时会失效 |
| **yfinance** | ⭐⭐⭐ | 免费，简单 | 外汇数据可能不完整 |
| **Polygon.io** | ⭐⭐⭐⭐ | 数据质量高 | 需要API key |

---

## 🔧 如果MT5连接失败

### 方案A：使用investpy（推荐）

```python
from forex_data_fetcher import ForexDataFetcher

df = ForexDataFetcher.fetch_from_investpy(
    symbol='EUR/USD',
    timeframe='1hour',
    start_date='2024-01-01',
    end_date='2025-01-01'
)
df.to_csv('EURUSD_H1.csv')
```

### 方案B：使用yfinance

```python
from forex_data_fetcher import ForexDataFetcher

df = ForexDataFetcher.fetch_from_yfinance(
    symbol='EURUSD=X',
    start_date='2024-01-01',
    end_date='2025-01-01',
    interval='1h'
)
df.to_csv('EURUSD_H1.csv')
```

---

## 📖 详细文档

查看 `data_source_guide.md` 获取完整说明。

---

## ✅ 验证数据

```python
import pandas as pd

df = pd.read_csv('EURUSD_H1.csv', index_col=0, parse_dates=True)
print(f"数据量: {len(df)}")
print(f"时间范围: {df.index[0]} 至 {df.index[-1]}")
print(f"价格范围: {df['Low'].min():.5f} - {df['High'].max():.5f}")
```

---

## 🚀 下一步

数据获取后，运行能量系统识别程序：

```bash
python energy_system_detector.py
```

程序会自动使用获取的数据识别交易机会！

