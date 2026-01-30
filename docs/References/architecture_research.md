# 开源量化框架调研与架构借鉴报告 (Architecture Research Report)

## 1. 核心目标
本报告旨在分析主流开源量化框架（Backtrader, Vn.py, Freqtrade, Lean, Vectorbt）的架构设计，提炼其核心流程（策略、执行、回测）的实现模式，并为“爱思潘能量交易系统”的架构设计提供借鉴。

## 2. 主流框架架构解构

### 2.1 Backtrader (Python 经典)
*   **核心哲学**: **LineIterator (线迭代器)**。一切数据（价格、指标）都是时间序列线。
*   **流程**:
    *   **Strategy**: 用户重写 `next()` 方法。系统按时间步推进，每一步调用一次 `next()`。
    *   **Execution**: 策略调用 `self.buy()` -> 生成 `Order` 对象 -> 发送给 `Broker` -> `Broker` 在下一根 Bar 撮合 -> 回调 `notify_order`。
    *   **Backtest**: `Cerebro` 引擎负责时间轴的循环和数据馈送。
*   **优点**: 极其灵活，适合复杂的逻辑。
*   **缺点**: 循环速度较慢，不适合超大规模参数扫描。

### 2.2 Vn.py (国内实盘之王)
*   **核心哲学**: **Event Engine (事件引擎)**。
*   **流程**:
    *   **Strategy**: 基于回调 (`on_tick`, `on_bar`)。
    *   **Execution**: 策略发出指令 -> `OMS` (订单管理系统) -> 调用底层 C++ API (CTP等)。
    *   **Backtest**: `BacktestingEngine` 加载历史数据，模拟推送 `on_bar` 事件，并在本地维护撮合逻辑（不发网）。
*   **优点**: “所见即所得”，回测代码即实盘代码。

### 2.3 Freqtrade (加密货币/配置驱动)
*   **核心哲学**: **Vectorized Signal + Iterative Backtest (向量化信号 + 迭代回测)**。
*   **流程**:
    *   **Strategy**: 通过 Pandas 向量化计算一次性生成所有买卖信号列（极快）。
    *   **Execution**: 机器人轮询交易所，检查当前时间点是否有信号。
    *   **Backtest**: 虽然信号是预生成的，但回测引擎依然会逐行遍历以处理复杂的止损/保护逻辑。
*   **优点**: 工程化程度极高，开箱即用。

### 2.4 Vectorbt (极速回测)
*   **核心哲学**: **Pure Vectorization (纯向量化)**。
*   **流程**:
    *   无 `for` 循环。利用 NumPy 广播机制，一次性计算成千上万组参数的 PnL。
*   **缺点**: 难以实现复杂的路径依赖逻辑（如“移动止损取决于前三笔交易的平均值”）。

---

## 3. 对本项目 (爱思潘/ZigZag) 的关键启示

### 3.1 核心痛点：ZigZag 的“未来函数”问题
*   **问题**: ZigZag 是一个“重绘 (Repainting)”指标。当前的“高点”在未来价格更高时会消失并移动。
*   **框架挑战**:
    *   **Vectorbt/Freqtrade**: 很难直接用。因为它们倾向于预计算全量指标。如果在 T 时刻预计算了整个 ZigZag，T 时刻的信号其实利用了 T+N 时刻的信息（未来函数），回测结果会严重虚高。
    *   **Backtrader/Vn.py**: 可行，但需要技巧。必须在 `next()` 或 `on_bar()` 内部，**仅基于截至当前的数据**动态计算 ZigZag。这极其消耗算力（每根 Bar 都要重算过去 N 根 Bar 的 ZigZag）。

### 3.2 架构借鉴：我们需要什么样的“回测”？
鉴于爱思潘系统依赖 **模式识别 (Pattern Recognition)**，我们需要一个 **混合型架构**：

1.  **数据层 (Data Layer)**:
    *   借鉴 **Backtrader** 的 `DataFeed` 概念，统一 CSV 和 实时 API 的接口。
    *   **关键**: 必须支持“快照”式获取，或者增量更新 ZigZag 状态。

2.  **策略层 (Strategy Layer) - 状态机**:
    *   借鉴 **Vn.py** 的回调模式。
    *   不要写成一坨 `if-else`。爱思潘系统本质是一个 **状态机 (State Machine)**。
    *   状态: `Neutral` -> `Release_Detected` (释放) -> `Accumulation_Wait` (积累中) -> `Signal_Triggered` (突破)。

3.  **回测引擎 (Backtest Engine)**:
    *   **自定义轻量级引擎**。
    *   **核心逻辑**:
        ```python
        for t in range(start, end):
            # 1. 获取截至 t 的历史窗口 window = data[:t]
            # 2. 在 window 上计算 ZigZag (模拟当时的视角，杜绝未来函数)
            # 3. 识别形态 (旗形/三角)
            # 4. 生成信号 -> 虚拟撮合
        ```
    *   虽然慢（因为每步重算），但是**唯一准确**的方法。

## 4. 建议的技术路线 (Phase 1.5 & 2)

1.  **不直接使用 Backtrader**: 对于 ZigZag 这种极其特殊的重绘指标，Backtrader 的 LineIterator 机制不仅难以调试，而且容易无意中引入未来函数。
2.  **构建 "Event-Driven Loop" (自定义事件循环)**:
    *   手写一个简单的 `for` 循环引擎。
    *   手动控制 ZigZag 的计算窗口。
    *   这样能确保我们完全掌控“Agent 到底看到了什么”。

## 5. 下一步讨论议题
*   确认是否同意采用“自定义轻量级回测引擎”方案？
*   确认“状态机”设计模式是否符合您对爱思潘系统的理解？
