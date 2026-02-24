# SESSION LOG

## General Protocols (通用约定)
- Language: 中文交流，英文代码/注释。
- Execution: 未收到明确指令（"执行/开始/继续"）不修改代码、不执行命令。
- Discussion Only: 以 `!` 开头的输入，仅讨论，不动手。

## System Overview (系统概览)
- Project: AsipanEnergyTradingSystem
- Python Brain: `src/AsipanEnergyTradingSystem/modules/replay/src/feed_replay.py`
- MT5 EA: `MT5_Integration/MQL5_Link/MT5_EnergyTrading.mq5`
- Pipe: `\\.\pipe\MT5_Python_Bridge`
- Core Commands: `ADD_BAR|...`, `SPEED|...`, `BATCH|...`

## Entry Points (关键入口)
- Launcher: `src/AsipanEnergyTradingSystem/modules/replay/launch_feed.bat`
- Manual Run: `python src/AsipanEnergyTradingSystem/modules/replay/src/feed_replay.py`

## Current Focus
- 交易机会识别（opportunity_detection）模块设计与实现；优先完成图文资料提炼与规则化总结。

## Latest Progress
- opportunity_detection/triangle 目录建立；`docs_resources_triangle` 已按逻辑顺序重命名为：`1.basic_rules`、`2.trade_opportunity_definition`、`3.trading_opportunity_identification_process`、`4.triangle`、`5.resonant_trading_opportunities`。
- 已完成书中关键章节截图归档：交易机会定义（4.1）、交易机会识别流程（4.14）、上三/下三交易机会及实例（4.4/4.5）、第5章共振交易机会，以及第3章基础规则（3.1–3.5）。
- `1.basic_rules` 内已细分子目录：`3.1-3.2_market_basics`、`3.4_energy_theory`、`3.5_analysis_method`。
- 已完成 `3.1-3.2_market_basics/summary_market_basics.md` 图文结合提炼，并补充图面要点。
- AsipanEnergyTradingSystem 目录结构已完成重组（modules/replay, opportunity_detection, docs）。
- replay 模块已整理：脚本移入 `modules/replay/src/`，入口 `launch_feed.bat` 保持可用。
- project/strategies/Agent_Core 已移除或停止维护；单点记忆使用 `SESSION_LOG.md`。
- References & System_Architecture 已迁入 `src/AsipanEnergyTradingSystem/docs/`，PDF 不入库（.gitignore）。
- MT5 映射已恢复：`D:\mt5\MQL5\Experts\MT5_EnergyTrading` -> `E:\Quantitative trading model\MT5_Integration\MQL5_Link`。

## Next Steps
- 继续完成 `3.4_energy_theory` 与 `3.5_analysis_method` 的图文提炼（summary_*）。
- 依次提炼 `2.trade_opportunity_definition`、`3.trading_opportunity_identification_process`、`4.triangle`、`5.resonant_trading_opportunities`。
- 统一输出“机会识别流程 + 可执行规则清单 + 参数待确认项”。
- 在 `modules/opportunity_detection/src/` 建立基础代码骨架与接口（基于上述规则）。

## Blockers / Risks
- 需要确认机会识别的最小需求与输出格式（信号字段、触发时机）。
- 部分量化阈值（如振幅、角度、时间占比）需在后续章节提炼后统一确认。

## Notes
- 避免手动复制到 MT5 目录，保持 junction 单一代码源。
- PDF 本地路径：`src/AsipanEnergyTradingSystem/docs/References/爱思潘交易系统.pdf`（已忽略提交）。

## Last Updated
- 2026-02-23
