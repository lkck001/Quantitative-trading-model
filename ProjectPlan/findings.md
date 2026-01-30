# 发现日志 (Findings Log)

## 研究与发现 (Research & Discoveries)
<!-- 在此记录关键发现、文档片段和研究笔记。 -->

### 2026-01-24: 技能生态系统 (Skill Ecosystem)
- **技能加载器 (Skill Loader)**: 一个强大的元技能 (Meta-Skill)，用于动态加载其他技能。
- **可用库**:
  - `K-Dense-AI/claude-scientific-skills`: 包含 140+ 科学工具，包括 `scikit-learn`, `statsmodels`, `pymoo`。
  - `sickn33/antigravity-awesome-skills`: 包含 220+ 工程/流程技能，包括 TDD, 调试, 架构模式。
  - `SKE-Labs/agent-trading-skills`: **包含 51 个专业交易技能**，如 `head-and-shoulders`, `market-structure-shift`, `order-blocks`, `risk-management`。
- **Windows 文件锁定**: 在 Windows 上扫描/删除 git 仓库时，`shutil.rmtree` 可能会因为文件锁或只读属性而失败。解决方案是在 `onerror` 处理程序中使用 `os.chmod`。

### 遗留代码分析 (Legacy Code Analysis)
- **能量系统**: 之前的尝试包括一个 "能量系统探测器" (`energy_system_detector.py`)。
- **数据**: 使用 `ccxt` 获取加密/外汇数据。
- **模式**: 关注 "上三" (Upper Three) 和 ZigZag 结构。

### 爱思潘交易系统 (Aspen Trading System) 理论笔记
*(详细内容见 `energy_theory_notes.md`)*
- **核心**: 无向论 (Undirected Theory) - 跟随能量，不预测方向。
- **能量状态**: 释放 (Release) vs 积累 (Accumulation)。
- **关键形态**: 下旗/上旗 (Flag)。
  - 规则 1: 回撤 <= 50%。
  - 规则 2: 通道内至少 4 个触点 (ABCD)。
- **止损逻辑**: 放在积累区间的 **50% 中间位置**。
