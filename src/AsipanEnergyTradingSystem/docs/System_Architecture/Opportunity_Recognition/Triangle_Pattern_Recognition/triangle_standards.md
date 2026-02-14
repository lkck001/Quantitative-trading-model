# 爱思潘交易系统 - 三角形形态标准 (Triangle Pattern Standards)

## 1. 核心定义 (Core Definition)
三角形交易机会是指一段强劲的“能量释放”和随后的“三角形积累”按照特定规则组成的行情走势。

---

## 2. 上三交易机会 (Upper Triangle Opportunity)

### 2.1 结构图解
![上三交易机会标准结构图](../../Triangle_Pattern_Recognition/images/Examples/Upper_Triangle/Standard/Standard-Structure-Model.png)

### 2.2 结构特征 (Geometric Features)
基于图 4-12，标准上三交易机会具备以下量化特征：

1.  **释放段 (Release Phase)**:
    *   **方向**: 向上。
    *   **角度 (Angle)**: 必须陡峭，**不小于 45°** (如图左下角标注)。
    *   **力度**: K线特征为阳盛阴衰，甚至接近 90° 的垂直拉升。

2.  **积累段 (Accumulation Phase)**:
    *   **形态**: 收敛三角形。
        *   上轨 (1-3-5): 高点逐渐降低。
        *   下轨 (2-4): 低点逐渐升高。
    *   **回撤极限 (Retracement Limit)**: 第一个回撤点 (2) 的位置不能低于释放段高度的 **1/2** (如图左侧标注 `1/2`)。这意味着多头力量依然主导，回调被有效支撑。
    *   **内部结构**: 均匀，具备完整的初 (1-2)、中 (3-4)、末 (5) 期特征。触及点间距比例接近 1:1。

3.  **时间关系 (Time Ratio)**:
    *   `积累时间` (Accumulation Time) 显著长于 `释放时间` (Release Time)。
    *   规则要求：**积累时间 > 2 * 释放时间**。这是“横有多长，竖有多高”的量化体现。

---

## 3. 下三交易机会 (Lower Triangle Opportunity)

### 3.1 结构图解
![下三交易机会标准结构图](../../Triangle_Pattern_Recognition/images/Examples/Lower_Triangle/Standard/Standard-Structure-Model.png)

### 3.2 结构特征 (Geometric Features)
基于图 4-17，标准下三交易机会具备以下量化特征：

1.  **释放段 (Release Phase)**:
    *   **方向**: 向下。
    *   **角度 (Angle)**: 必须陡峭，**不大于 135°** (相对于水平线的补角，即垂直向下的锐角)。
    *   **力度**: K线特征为阴盛阳衰，如瀑布般下跌。

2.  **积累段 (Accumulation Phase)**:
    *   **形态**: 收敛三角形。
        *   上轨 (2-4): 高点逐渐降低。
        *   下轨 (1-3-5): 低点逐渐升高。
    *   **回撤极限 (Retracement Limit)**: 第一个反弹点 (2) 的位置不能超过释放段高度的 **1/2** (如图标注 `1/2`)。这意味着空头力量极其强大，反弹无力。
    *   **内部结构**: 均匀完整。注意：如果触及点 1 和 3 在同一水平位置，下边线需从点 3 开始绘制。

3.  **时间关系 (Time Ratio)**:
    *   同上三，要求 **积累时间 > 2 * 释放时间**。

---

## 4. 算法实现清单 (Algorithm Checklist)

在编写 `TriangleRecognizer` 时，必须实现以下检测逻辑：

- [ ] **Trend Identification**: 识别一段连续的 ZigZag 线段，其斜率绝对值 > 阈值 (45°)。
- [ ] **Retracement Check**: 计算随后的第一波回调/反弹幅度，必须 < 50% Trend Height。
- [ ] **Convergence Check**: 
    - 至少找到 4 个极值点 (P1, P2, P3, P4)。
    - 验证 `Highs` 的线性回归斜率 < 0。
    - 验证 `Lows` 的线性回归斜率 > 0。
- [ ] **Duration Check**: 积累区的时间跨度 / 趋势段时间跨度 > 2.0。
