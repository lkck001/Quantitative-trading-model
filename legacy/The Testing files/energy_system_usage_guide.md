# 能量系统交易机会识别程序 - 使用指南

## 程序概述

本程序根据"能量系统"交易方法，自动识别EURUSD H1级别的**标准上三**和**标准下三**交易机会。

---

## 核心识别规则

### 上三交易机会（做多信号）

| 条件 | 要求 |
|:---|:---|
| **释放方向** | 向上 |
| **释放幅度** | ≥ 50点（可调） |
| **释放角度** | ≥ 45°（接近90°更佳） |
| **K线特征** | 阳盛阴衰（阳线数 > 阴线数） |
| **回撤幅度** | ≤ 释放幅度的 50% |
| **积累形态** | 收敛三角形（高点递降，低点递升） |
| **触及点** | ≥ 5个，间距比例接近 1:1 |
| **时间比例** | 积累时间 ≥ 释放时间 × 2 |

### 下三交易机会（做空信号）

| 条件 | 要求 |
|:---|:---|
| **释放方向** | 向下 |
| **释放幅度** | ≥ 50点（可调） |
| **释放角度** | ≤ 135°（接近90°更佳，即向下陡峭） |
| **K线特征** | 阴盛阳衰（阴线数 > 阳线数） |
| **回撤幅度** | ≤ 释放幅度的 50% |
| **积累形态** | 收敛三角形（高点递降，低点递升） |
| **触及点** | ≥ 5个，间距比例接近 1:1 |
| **时间比例** | 积累时间 ≥ 释放时间 × 2 |

---

## 快速开始

### 1. 安装依赖

```bash
pip install pandas numpy matplotlib
```

### 2. 准备数据

程序需要EURUSD H1的历史数据，格式要求：

```csv
Time,Open,High,Low,Close,Volume
2024-01-02 00:00:00,1.10465,1.10520,1.10400,1.10480,5000
2024-01-02 01:00:00,1.10480,1.10550,1.10460,1.10530,4500
...
```

**数据获取方式：**

| 来源 | 说明 |
|:---|:---|
| **MT4/MT5** | 历史数据中心导出CSV |
| **TradingView** | 导出功能 |
| **Dukascopy** | 免费Tick数据下载 |
| **Yahoo Finance** | `yfinance` 库（但外汇数据有限） |

### 3. 运行程序

```python
# 修改数据路径后运行
python energy_system_detector.py
```

---

## 参数详解

```python
detector = EnergySystemDetector(
    df,
    min_release_pips=50,          # 最小释放幅度（点）
    min_release_angle=45,          # 上三最小角度（度）
    max_release_angle=135,         # 下三最大角度（度）
    max_retrace_ratio=0.5,         # 最大回撤比例
    min_time_ratio=2.0,            # 最小时间比例
    touch_ratio_tolerance=0.4,     # 触及点间距容差
    min_touch_points=5             # 最小触及点数
)
```

### 参数调整建议

| 场景 | 调整方向 |
|:---|:---|
| 机会太少 | 降低 `min_release_pips` 到 30-40，提高 `max_retrace_ratio` 到 0.55 |
| 机会太多（质量低） | 提高 `min_release_pips` 到 60-80，降低 `max_retrace_ratio` 到 0.45 |
| 三角形识别不准 | 调整 `touch_ratio_tolerance` 和 `min_touch_points` |

---

## 输出结果

程序会在指定目录生成：

```
energy_system_results/
├── 上三_20240315_1400.png      # 上三机会截图
├── 下三_20240420_0900.png      # 下三机会截图
├── ...
└── trading_opportunities_summary.csv  # 汇总表
```

### 截图示例说明

每张截图包含：
- **K线图**：显示释放和积累阶段
- **蓝色箭头**：上三的释放方向
- **红色箭头**：下三的释放方向
- **橙色圆点**：三角形触及点
- **紫色虚线**：三角形上下边界
- **绿色/红色三角**：入场信号点

---

## 从MT4/MT5导出数据

### MT4导出步骤

1. 打开MT4，进入 `工具` → `历史数据中心`
2. 选择 `EURUSD`，双击 `H1`（1小时）
3. 点击 `导出`，保存为CSV文件
4. 将文件放到程序目录，修改代码中的路径

### MT5导出步骤（推荐）

```python
# 使用MetaTrader5 Python库
import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime

# 连接MT5
mt5.initialize()

# 获取EURUSD H1数据
rates = mt5.copy_rates_range(
    "EURUSD", 
    mt5.TIMEFRAME_H1,
    datetime(2024, 1, 1),
    datetime(2025, 1, 1)
)

# 转换为DataFrame
df = pd.DataFrame(rates)
df['time'] = pd.to_datetime(df['time'], unit='s')
df.columns = ['Time', 'Open', 'High', 'Low', 'Close', 'tick_volume', 'spread', 'real_volume']

# 保存
df.to_csv('EURUSD_H1.csv', index=False)

mt5.shutdown()
```

---

## 代码结构

```
energy_system_detector.py
├── ZigZag类              # 波峰波谷识别
├── EnergySystemDetector类
│   ├── __init__()        # 初始化参数
│   ├── _calculate_angle() # 计算释放角度
│   ├── _is_valid_release() # 验证释放阶段
│   ├── _find_triangle_touches() # 寻找三角形触及点
│   ├── _validate_triangle() # 验证三角形形态
│   ├── detect_opportunities() # 主检测函数
│   ├── plot_opportunity() # 绘制单个机会
│   └── export_results()  # 导出所有结果
└── main()               # 主程序入口
```

---

## 进阶：集成到实盘监控

```python
# 伪代码示例：实时监控
import time

while True:
    # 获取最新数据
    df = get_latest_data('EURUSD', 'H1', bars=500)
    
    # 检测机会
    detector = EnergySystemDetector(df)
    opportunities = detector.detect_opportunities()
    
    # 检查是否有新信号
    latest = opportunities[-1] if opportunities else None
    if latest and is_new_signal(latest):
        send_alert(f"发现{latest['type']}机会！价格: {latest['entry_price']}")
    
    # 每小时检查一次
    time.sleep(3600)
```

---

## 常见问题

### Q1: 为什么识别不到任何机会？

**可能原因：**
1. 数据时间范围内没有明显的趋势行情
2. 筛选条件过于严格
3. 数据格式不正确

**解决方案：**
- 先用模拟数据测试程序是否正常
- 逐步放宽参数
- 检查数据的列名是否正确

### Q2: 如何提高识别准确率？

1. **增加K线特征判断**：加入更多的K线形态识别（如十字星、吞没等）
2. **结合成交量**：在释放阶段要求成交量放大
3. **多周期验证**：在H4或D1级别确认大趋势方向

### Q3: 程序运行很慢怎么办？

- 减少数据量（缩短时间范围）
- 使用 `polars` 替代 `pandas`
- 优化ZigZag算法（使用Numba加速）

---

## 后续改进方向

1. **添加止损止盈计算**：根据ATR或三角形高度自动计算
2. **添加成功率统计**：回测历史机会的盈亏情况
3. **支持更多品种**：扩展到其他货币对或黄金
4. **实时监控模块**：接入MT5 API实现自动报警
5. **机器学习增强**：用ML模型进一步筛选高质量机会

---

## 联系与反馈

如果在使用过程中遇到问题，可以：
1. 检查数据格式是否正确
2. 调整参数重新运行
3. 查看程序输出的错误信息

祝交易顺利！🚀

