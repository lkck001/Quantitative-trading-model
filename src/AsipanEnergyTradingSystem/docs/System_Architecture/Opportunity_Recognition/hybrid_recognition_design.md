# 机会识别子系统设计 (Opportunity Recognition Subsystem)

## 1. 核心理念：混合识别 (Hybrid Recognition)
爱思潘系统的核心挑战在于**形态的泛化**。为了解决“死板算法”无法适应市场变形的问题，本系统采用 **"算法粗筛 + AI 确权"** 的双层架构。

---

## 2. 架构分层 (Layered Architecture)

### 第一层：机械筛选层 (The Mechanical Filter)
*   **角色**: 勤劳的“实习生”。
*   **职责**: 实时扫描全量数据，基于几何规则筛选出所有“疑似”机会。
*   **核心技术**:
    *   **ZigZag (去噪)**: 使用 `jbn/ZigZag` 库，将 K 线简化为波峰/波谷 (Peaks/Valleys)。
        *   *关键约束*: 必须在 Event-Driven 循环中运行，仅使用 `data[:t]` 计算，严禁使用未来数据。
    *   **Pattern Recognition (连线)**: 使用 `chart_patterns` 库或自定义几何逻辑。
        *   *Flag (旗形)*: 识别“平行通道”结构，允许一定角度偏差 (e.g., ±15度)。
        *   *Triangle (三角形)*: 识别“收敛”结构。
*   **输出**: 候选信号列表 (Candidate List)。
    *   例: `{"time": "2024-01-05 14:00", "pattern": "Bullish_Flag", "confidence": "Medium"}`

### 第二层：智能决策层 (The Intelligent Judge)
*   **角色**: 资深的“交易员”。
*   **职责**: 对“实习生”提交的候选信号进行模糊逻辑判断，解决泛化问题。
*   **核心技术**:
    *   **LLM Analysis**: 调用大模型 API (Gemini/Claude)。
    *   **Context Injection**: 将 ZigZag 坐标序列、近期成交量、趋势强度指标作为 Prompt 输入。
*   **Prompt 逻辑**:
    > "这里检测到一个疑似旗形。虽然下轨有轻微刺破，但考虑到前方主升浪极其强劲（斜率>60度），且整理期成交量显著萎缩，请判断这是否为一个有效的蓄势结构？"
*   **输出**: 最终决策 (Final Verdict)。
    *   `VALID` (有效，执行交易) / `INVALID` (无效，噪音)

---

## 3. 实现路线图 (Implementation Roadmap)

### Phase 1: 机械层原型 (The Player)
构建一个**带 ZigZag 的行情播放器**，直观验证“去噪”效果。
1.  **MarketReplayer**: 读取 CSV，逐根 K 线推送。
2.  **LiveZigZag**: 在播放器中实时重算 ZigZag，观察重绘现象。
3.  **SimplePattern**: 实现最基础的“平行线”识别逻辑。

### Phase 2: 智能层接入 (The AI Connection)
1.  **Snapshot Generator**: 当机械层报警时，截取当前数据窗口。
2.  **Agent Interface**: 编写 Python 函数调用 LLM 进行二次确认。

---

## 4. 数据流图 (Data Flow)

```text
[ MT4 / CSV ] 
      | (Tick/Bar)
      v
[ Market Replayer ] -> (Current Window)
      |
      v
[ ZigZag Engine ] -> (Peaks & Valleys)
      |
      v
[ Geometric Filter ] -> (Is it a Flag?) --NO--> [ Discard ]
      | (YES - Candidate)
      v
[ AI Agent Judge ] -> (Context Analysis)
      |
      v
[ Execution System ] -> (Buy/Sell)
```
