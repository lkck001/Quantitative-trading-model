# Triangle Recognition Algorithm（三角形机会识别算法）

## 0. 目标与边界（当前版本）
- 总目标：识别三角形机会，不做交易执行。
- 当前开发策略：先做最小可运行功能（MVP），再逐步叠加复杂识别。
- 当前阶段输出：先输出“积累区域预筛结果”，暂不输出最终三角机会。

## 1. 分阶段实现策略（先小后大）

### 阶段 A（现在就做，MVP）
只实现 `2.1 ~ 2.3`：
1) 输入与预处理。  
2) 滑动窗口扫描。  
3) 积累区预筛并标记。  

阶段 A 的目标不是“最终识别三角形”，而是先验证：
- 预筛规则是否能把“疑似积累区”稳定标出来。
- MT5 上的可视化是否直观。
- 参数调节是否符合交易直觉。

### 阶段 B（A 稳定后再做）
再接入 `2.4 ~ 2.8`：
- ZigZag 枢轴提取
- 三角结构判定
- 分类与置信度
- 最终 `triangle_labels.csv` 输出

> 结论：先把阶段 A 做稳，能明显降低一次性实现过多功能带来的 Bug 风险。

## 2. 阶段 A（MVP）详细算法

### 2.1 输入与预处理
- 输入字段：`time, open, high, low, close, volume`。
- 统一处理：
  - `time` 升序、去重、时区统一。
  - 周期固定（例如 M15）。
  - 缺失值做标记，不强行补价。
- 预计算：
  - `ATR(14)`（用于尺度归一化）
  - `mid=(high+low)/2`（可用于辅助稳定性判断）

### 2.2 滑动窗口扫描
- 窗口宽度：默认 `2天`。
- 步长：每次右移 `1 根 K 线`。
- 最小样本：`min_window_bars`（建议 120）。
- 说明：
  - 每个窗口内独立计算预筛指标。
  - 扫描全年时，本质是“局部窗口连续滑动 + 重复判定”。

### 2.3 积累区预筛（阶段 A 的核心输出）
先做轻量判定，只筛出“疑似积累区”。

- 指标 1：振幅压缩
  - `range = max(high)-min(low)`
  - `range_atr_ratio = range / mean(ATR)`
  - 条件：`range_atr_ratio <= thr_range`
- 指标 2：趋势平缓
  - 对 `close` 线性回归得到 `slope`
  - 条件：`abs(slope_norm) <= thr_slope`
- 指标 3：来回震荡
  - 统计方向切换次数 `flip_count`
  - 条件：`flip_count >= thr_flip`

判定策略（建议先用宽松版）：
- 满足 3 条中的任意 2 条，即记为 `pass_flag=1`。
- 否则 `pass_flag=0`。

## 3. 阶段 A 输出文件（先不用 triangle_labels.csv）
输出独立文件：`accumulation_labels.csv`

建议字段：
- `window_start`
- `window_end`
- `range_atr_ratio`
- `slope_norm`
- `flip_count`
- `pass_flag`（0/1）
- `score`（可选，0~1）

说明：
- 该文件只表达“积累区预筛结果”。
- 它是后续 ZigZag 与三角判定的输入基础，不是最终交易机会标签。

## 4. MT5 可视化（阶段 A）
- EA 读取 `MQL5/Files/accumulation_labels.csv`。
- 对 `pass_flag=1` 的窗口绘制半透明背景区（例如淡黄色矩形）。
- 对象命名建议：`ACC_<index>`，便于刷新与清理。
- 控件建议：`LOAD ACC` / `CLEAR ACC`。

## 5. 阶段 A 验收标准（Done）
- 同一输入重复运行，输出一致（可复现）。
- MT5 能稳定显示积累区，且位置与时间对齐。
- 调整阈值后，标记范围变化符合直觉。
- 人工抽样检查后，明显错误标记可控。

## 6. 参数基线（阶段 A）
- `window_days = 2`
- `min_window_bars = 120`
- `atr_period = 14`
- `thr_range = 6 ~ 12`
- `thr_slope = 0.05 ~ 0.20`（需按归一化定义细调）
- `thr_flip = 6 ~ 15`（与窗口大小相关）

## 7. 阶段 B 预告（暂不实现）
当阶段 A 达标后，再进入：
1) `2.4` ZigZag 枢轴提取。  
2) `2.5` 三角结构判定。  
3) `2.6` 分类与置信度。  
4) `2.7` 输出 `triangle_labels.csv`。  
5) `2.8` 最终识别验收。  
