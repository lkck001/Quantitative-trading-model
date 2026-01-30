| 项目名称            | 链接                                                  | 核心功能                                          | 架构简评                                | 适用性打分 |
| :-------------- | :-------------------------------------------------- | :-------------------------------------------- | :---------------------------------- | :---- |
| **jbn/ZigZag**  | [GitHub](https://github.com/jbn/ZigZag)             | 提供极速的波段高低点识别算法，是 Python 社区最常用的 ZigZag 库。      | 纯 Python。基于向量化计算，运行效率极高，但直接使用会产生重绘。 | ★★★★☆ |
| **true-zigzag** | [GitHub](https://github.com/JaktensTid/true-zigzag) | 复现了 TradingView 的 ZigZag 逻辑，旨在提供更符合交易直觉的波段识别。 | 纯 Python。结构清晰，适合作为策略逻辑中“实时波段确认”的参考。 | ★★★☆☆ |
架构师建议：ZigZag 的防重绘核心不在于算法本身，而在于回测引擎的逻辑封装。在事件驱动回测中，您必须引入“延迟确认”机制。只有当价格回撤超过 X% 且后续确认了新的 Peak/Valley 后，信号才生效。建议参考 jbn/ZigZag 的核心计算逻辑，但在您的 Event-Driven 引擎中，仅允许访问“已确认”的历史波段点

2. 复杂形态识别算法 (Advanced Pattern Recognition)
| 项目名称                           | 链接                                                                      | 核心功能                                                | 架构简评                                                  | 适用性打分 |
| :----------------------------- | :---------------------------------------------------------------------- | :-------------------------------------------------- | :---------------------------------------------------- | :---- |
| **chart\_patterns**            | [GitHub](https://github.com/zeta-zetra/chart_patterns)                  | **强烈推荐**。实现了旗形 (Flag)、三角形 (Triangle)、头肩顶等几何形态的自动识别。 | 纯 Python。基于规则 (Rule-based) 的几何算法，通过识别高低点连线的斜率关系来定义形态。 | ★★★★★ |
| **triangle-pattern-detection** | [GitHub](https://github.com/AmirRezaFarokhy/triangle-pattern-detection) | 专注于三角形态识别，使用线性回归拟合局部极值点。                            | 纯 Python。结合了 `scikit-learn` 的线性模型，对于形态的“收敛性”判断非常精准。   | ★★★★☆ |
| **PatternPy**                  | [GitHub](https://github.com/keithorange/PatternPy)                      | 利用 Pandas 和 Numpy 进行高性能形态扫描，支持多种经典技术形态。             | 纯 Python。注重向量化性能，适合在大规模历史数据中进行形态预筛。                   | ★★★☆☆ |

架构师建议：对于旗形和三角形，推荐优先采用 chart_patterns。它的几何识别逻辑与您的 ZigZag 波段识别能完美结合——先通过 ZigZag 确定“旗杆”的幅度，再通过该库识别“整理区”的斜率和平行度。


3. Python 与 MT4 的高性能桥接 (Python-MT4 Bridge)
| 项目名称                     | 链接                                                                                                 | 核心功能                                          | 架构简评                                                         | 适用性打分 |
| :----------------------- | :------------------------------------------------------------------------------------------------- | :-------------------------------------------- | :----------------------------------------------------------- | :---- |
| **dwx-zeromq-connector** | [GitHub](https://github.com/darwinex/dwx-zeromq-connector)                                         | **行业标准方案**。基于 ZeroMQ 实现 Python 与 MT4 的双向异步通信。 | MQL4 (EA) + Python Wrapper。支持行情订阅 (PUB/SUB) 和指令执行 (REQ/REP)。 | ★★★★★ |
| **PyTrader**             | [GitHub](https://github.com/TheSnowGuru/PyTrader-python-mt4-mt5-trading-api-connector-drag-n-drop) | 基于 WebSockets 的轻量级桥接，支持“拖拽式”部署，活跃度极高。         | 包含 EX4/EX5 编译文件。配置比 ZMQ 更简单，适合需要快速实盘上线的场景。                   | ★★★★☆ |










整体报告

Aspen System Research Notes

1. ZigZag Anti-Repainting

•
jbn/ZigZag: 纯 Python 实现，基于向量化。

•
风险: 直接用于回测会重绘。

•
对策: 需要配合 lookback 逻辑。只有当价格突破前高/前低一定比例且后续确认后，才标记为 Peak/Valley。



•
True-ZigZag (JaktensTid): 尝试复现 TradingView 的逻辑。

•
核心逻辑: 在事件驱动回测中，必须使用“延迟确认”机制。例如，当一个新的波段点出现时，不立即下单，而是等待 N 根 K 线确认或价格回调 X%。

2. Pattern Recognition

•
zeta-zetra/chart_patterns:

•
核心: 规则驱动（Rule-based）。

•
支持: Flag, Triangle, Head and Shoulders.

•
架构: 纯 Python, 基于 OHLC 数据帧。



•
TA-Lib: 提供蜡烛图形态，但不支持复杂的几何形态（如旗形）。

•
DTW 方案: 考虑 fastdtw 或 dtaidistance 库，通过与标准“旗形”模板匹配来识别。

3. Python-MT4 Bridge

•
dwx-zeromq-connector (Darwinex):

•
地位: 行业标准级。

•
技术: ZeroMQ (REQ/REP + PUB/SUB)。

•
组件: MQL4 EA + Python Wrapper.



•
PyTrader (TheSnowGuru):

•
技术: WebSockets.

•
优点: 支持 MT4/MT5，拖拽式部署，活跃度高。



•
OTMql4Zmq: 备选方案。

4. Top Picks for Aspen

1.
dwx-zeromq-connector: 桥接首选。

2.
chart_patterns: 形态识别首选（几何算法）。

3.
jbn/ZigZag: 算法核心参考，需自行封装 Event-driven 逻辑。

4.
PyTrader: 如果 ZMQ 配置复杂，可作为快速原型方案。

5.
fastdtw: 用于进阶的形态模糊匹配。

5. 几何形态识别逻辑补充 (Geometric Logic)

•
Flag/Pennant 识别逻辑:

1.
旗杆 (Flagpole): 识别一段急促的趋势运动（通常是 ZigZag 的一个长波段）。

2.
整理区 (Consolidation):

•
旗形：高点连线与低点连线几乎平行，且斜率与旗杆相反。

•
三角形/尖旗形：高低点连线呈现收敛状态（斜率绝对值逐渐减小）。



3.
量化指标:

•
能量：旗杆的垂直高度。

•
突破确认：价格突破整理区上/下轨，且带有动量确认。





•
参考实现: AmirRezaFarokhy/triangle-pattern-detection 使用线性回归（Linear Regression）拟合局部高低点，通过斜率关系判断形态。

