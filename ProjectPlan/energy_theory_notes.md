# Energy Trading System (爱思潘交易系统) Theory Notes

## Core Philosophy
- **Undirected Theory (无向论)**: Do not predict market direction. Follow the "Energy" state.
- **Energy States**:
  - **Release (释放)**: Kinetic energy release, manifests as a strong trend/impulse wave.
  - **Accumulation (积累)**: Potential energy buildup, manifests as consolidation/correction (Flags, Triangles).

## Trading Flowchart (Process)
1.  **Mindset & Risk**: Check mental state, calculate position size.
2.  **Energy Analysis**: Identify if market is in Release or Accumulation.
3.  **Opportunity Identification**: Find specific patterns (e.g., Flags) within Accumulation.
4.  **Entry**: Execute on structural breakout.
5.  **Protection**: Manage risk after entry (e.g., move stop loss).

## Key Technical Patterns

### 1. Standard Flag (下旗/上旗)
*   **Context**: Occurs after a "Standard Release".
*   **Structure**:
    *   **Pole (Release)**: Strong move.
    *   **Flag (Accumulation)**: Retracement channel.
*   **Rules**:
    *   **Retracement Depth**: Must be $\le 50\%$ of the Release segment.
    *   **Structure**: Inside the accumulation channel, price must touch boundaries at least **4 times** (ABCD points).
*   **Entry Signal**:
    *   Breakout of the channel boundary (e.g., for Lower Flag, break below lower line).
*   **Stop Loss**:
    *   Placed at the **middle** (50%) of the Accumulation range (not necessarily the high/low).

## Implementation Roadmap (Architecture Mapping)

### Module 1: `EnergyAnalyzer`
- **Goal**: Segment price history into "Release" and "Accumulation" phases.
- **Algorithm**:
  - Use **ZigZag** to identify swings.
  - Filter swings by magnitude and speed (slope) to classify as Impulse (Release) vs Correction (Accumulation).
  - **DTW** (Dynamic Time Warping) could be used to compare current shape to ideal "Flag" templates.

### Module 2: `PatternRecognizer`
- **Goal**: Validate "Accumulation" segments against rules.
- **Checks**:
  - `retracement_ratio <= 0.5`
  - `touch_points >= 4`
  - `parallelism`: Are channel lines roughly parallel?

### Module 3: `TradeExecutor`
- **Goal**: Handle Entry, Stop Loss, and Protection.
- **Logic**:
  - **Entry**: Stop-Limit order at channel breakout.
  - **SL**: Calculate 50% level of the flag structure.
  - **TP/Protection**: Defined by Risk:Reward or subsequent structures.

## Reference
- **Source**: `docs/爱思潘交易系统.pdf` (Pages 238-243)
- **Example**: Rebar (螺纹钢) M15 Chart.
