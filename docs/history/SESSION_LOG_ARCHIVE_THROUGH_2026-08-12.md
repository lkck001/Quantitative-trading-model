# SESSION LOG

## General Protocols (通用约定)
- Language: 中文交流，英文代码/注释。
- Execution: 未收到明确指令（"执行/开始/继续"）不修改代码、不执行命令。
- Discussion Only: 以 `!` 开头的输入，仅讨论，不动手。
- Debug: 关键流程必须有 Print 日志，并检查 Experts 输出是否一致。
- Debug: 每次阶段收尾都更新 SESSION_LOG.md。

## Session Management (Session 管理)
- 每个新 Session 的第一步必须读取项目根目录 `SESSION_LOG.md`，之后才能分析项目、执行命令、修改文件或提出下一步。
- `SESSION_LOG.md` 是项目当前状态、设计决策、验证结果、风险和交接信息的唯一事实来源；聊天记录不能替代本文档。
- 助手需要主动判断是否适合切换 Session，而不是等待用户提醒。
- 建议切换的条件：当前大型阶段已经完成；讨论方向明显变化；上下文过长；已积累较多代码修改或关键决策；开始遗漏、混淆或重复已有信息。
- 切换前必须先更新本文档，并向用户提供可直接交给新 Session 的交接摘要。
- 交接摘要至少包含：当前目标与完成状态、已确定的设计决策、修改文件、验证结果、未解决问题与风险、下一步操作、项目启动方式与环境要求。
- 不能只说“建议切换 Session”；在交接信息没有更新完整之前，不建议切换。

## Debug & Logging (调试与日志)
- 每次新增/修改功能后，至少核对 4 类日志信息（初始化、流程、错误ID、结果状态），避免“看起来运行但实际失败”。
- MT5（前端）所有 EA 关键动作统一写入 MT5 -> Experts。
- Python（后端）日志需包含时间戳、模块名、级别和关键参数/路径。
- 建议日志前缀：MT5 用 [EA|模块|动作]，Python 用 [FEED|模块|动作]；统一包含 FULL/PIPE/UI/REPLAY/CSV/SYMBOL；级别用 INFO/WARN/ERROR。
- 重点覆盖 OnTimer/ReadPipeCommand/AddBarToChart 的调用频率、每 N 条采样、异常重试与超时处理。
- 任何 MT5 平台 API 调用失败必须打印 GetLastError()；Python 异常必须记录 exception + traceback。
- Debug 开关统一可控：MT5 使用 InpDebug；Python 使用 --log-level 或配置文件。
- 提交前做一次最小回放验证并截图留档（启动/暂停/恢复），确保日志可追溯。

## System Overview (系统概览)
- Project: AsipanEnergyTradingSystem
- Python Brain: `src/AsipanEnergyTradingSystem/modules/replay/src/feed_replay.py`
- MT5 EA: `MT5_Integration/MQL5_Link/MT5_EnergyTrading.mq5`
- Pipe: `\\.\pipe\MT5_Python_Bridge`
- Core Commands: `ADD_BAR|...`, `SPEED|...`, `BATCH|...`

## Entry Points (关键入口)
- Launcher: `src/AsipanEnergyTradingSystem/modules/replay/launch_feed.bat`
- Python Environment: `Trading/`（Python 3.11.9；不要使用或恢复 `Trading_broken/`）
- Manual Run: `.\Trading\Scripts\python.exe "src\AsipanEnergyTradingSystem\modules\replay\src\feed_replay.py"`
- 根目录 `main.py` 当前为空，不是有效启动入口。

## Current Focus
- EURUSD 2002 全年数据的 MT5 `FULL LOAD` 已完成编译和实机验证；当前 MT5 以 FULL-only 模式运行，只保留 `EURUSD@_2002_FULL` H1 全量图表。
- 当前优先级为使用已完成的 MT5 精确绘图/标注工具建立“标准交易机会总真值库”；用户已在 2002 H1 行情中识别首个候选上升通道，准备将其作为第一条端到端案例。
- 下一阶段按用户方向继续导出 2003–2009，或回到三角形识别器；识别工作的第一步是依据 `docs_resources_triangle` 定义并识别积累区间。
- 三角形机会按“普通能量积累 -> 有结构积累 -> 三角形几何识别 -> 突破确认”逐层实现。
- 释放段与积累段都属于完整机会，但当前先把积累区识别器做成可靠的候选区域生成器。
- 更长期主线仍是统一提取 12 大标准交易机会的共同特征、家族特征和镜像规则，再按结构家族分阶段开发与测试。

## Latest Progress
- Python 3.11.9 已安装；项目虚拟环境已重建为 `Trading/`，依赖已安装并验证。`.gitignore` 已忽略 `Trading/` 和 `Trading_broken/`。
- 根目录 `requirements.txt` 已移除代码未使用且无法安装的 `ta-lib-bin`；replay 模块的 requirements 已改正非法注释。
- `MT5_EnergyTrading.mq5` 的 `FULL LOAD` 已从仅加载 `EURUSD_2024.csv` 改为按年份加载 `Data/Local_Data/split_by_year/EURUSD_2015.csv` 至 `EURUSD_2025.csv`。
- FULL LOAD 会先清空 `EURUSD@_2024_FULL` 旧历史，再按每 5000 根分块调用 `CustomRatesUpdate`，最后打开/刷新 FULL 图表并跳到历史起点。
- 新增 EA 输入：`InpFullLoadAllYears=true`、`InpFullStartYear=2015`、`InpFullEndYear=2025`、`InpFullAutoLoad=false`。
- 已对 FULL LOAD 做静态检查：仅有一份 `LoadFullHistory()`，括号数量平衡；本机尚未找到 `metaeditor64.exe`，因此还没有完成真实编译与 MT5 运行验证。
- 积累区 Phase A 脚本位于 `modules/opportunity_detection/triangle/src/build_accumulation_labels.py`，当前使用 `range_atr_ratio`、`slope_norm`、`flip_count` 三项基础特征。
- Phase A 已运行：扫描 24,995 根 K 线、24,804 个窗口，通过 2,533 个窗口，合并得到 34 个候选积累区。
- 文档定义的积累区核心特征包括：运行时间长、振幅小、整体角度接近 0、内部复杂反复、阴阳 K 线密集交错、价格受固定边界约束并在触边后折返。
- 已将人的视觉判断形式化为双通道：多尺度感知几何为主通道，标准化 OHLC 图像视觉为辅助通道；后者只用于候选重排和争议复核。
- 已规定视觉模型不得使用带入场线、盈利结果、文字标签和未来行情的现有截图直接训练，并加入配色、分辨率、K 线宽度变化的不变性测试。
- 已确定跨标的泛化原则：几何核心、品种/周期校准层、环境与交易层三层分离；几何核心只学习规范化关键点集合关系。
- 已将价格平移、价格缩放、时间拉伸、多空镜像、轻微噪声和留一标的测试列为共同识别引擎的强制验收门禁。
- 已建立 `standard_opportunity_work_plan.md`，定义从规则提取、总真值库、共同引擎、三类识别家族、盲测到 MT5 集成的阶段计划、交付物和验收门禁。
- 已建立 `standard_opportunity_feature_catalog.md` V0.1，统一 12 类机会的时间状态、ATR 归一化特征、枢轴/边线特征、结构矩阵和待确认问题。
- 已确定“12 类案例一次性标注、算法按三类家族分阶段开发”：释放加积累（矩形/三角/旗形）、趋势通道、反转结构（头肩/MW）。
- 已盘点 EURUSD 案例概览库：三角形 13、双顶底 13、头肩 8、旗形 10、通道 18；当前未发现矩形案例。
- 已确认案例集中于 2002–2009，而项目现有 OHLC 从 2015 开始；案例与原始 K 线映射列入总真值库阶段的前置任务。
- opportunity_detection/triangle 目录建立；`docs_resources_triangle` 已按逻辑顺序重命名为：`1.basic_rules`、`2.trade_opportunity_definition`、`3.trading_opportunity_identification_process`、`4.triangle`、`5.resonant_trading_opportunities`。
- 已完成书中关键章节截图归档：交易机会定义（4.1）、交易机会识别流程（4.14）、上三/下三交易机会及实例（4.4/4.5）、第5章共振交易机会，以及第3章基础规则（3.1–3.5）。
- `1.basic_rules` 内已细分子目录：`3.1-3.2_market_basics`、`3.4_energy_theory`、`3.5_analysis_method`。
- 已完成 `3.1-3.2_market_basics/summary_market_basics.md` 图文结合提炼，并补充图面要点。
- AsipanEnergyTradingSystem 目录结构已完成重组（modules/replay, opportunity_detection, docs）。
- replay 模块已整理：脚本移入 `modules/replay/src/`，入口 `launch_feed.bat` 保持可用。
- project/strategies/Agent_Core 已移除或停止维护；单点记忆使用 `SESSION_LOG.md`。
- References & System_Architecture 已迁入 `src/AsipanEnergyTradingSystem/docs/`，PDF 不入库（.gitignore）。
- MT5 映射已恢复：`D:\mt5\MQL5\Experts\MT5_EnergyTrading` -> `E:\Quantitative trading model\MT5_Integration\MQL5_Link`。
- MT5 EA 已实现双图表架构：回放图表用于慢播放（管道驱动），全量图表用于全年行情一次性展开（不接管道）。
- 已增加全量图表参数：InpFullSymbolName / InpFullTimeframe / InpFullCsvPath / InpFullAutoLoad / InpFullForceReload / InpReplayTimeframe。
- 已增加 `LoadFullHistory`：CSV 分块写入 `CustomRatesUpdate`，避免内存卡死；加载完成记录到 GlobalVariable `Energy_FullLoaded`。
- 回放图 UI 已统一 ASCII 文案（START/RESUME/PAUSE/WAIT，批量按钮为 -/+）。
- 已确认慢速回放默认读取 `Data/Local_Data/split_by_year/EURUSD_2024.csv`，FULL 图表按同目录 `EURUSD_YYYY.csv` 规则读取年度文件。
- 已确认 Forex Tester 的 `data/Ticks/EURUSD.dat` 实际只包含 2010 年逐笔数据；完整的 2002-01-01 至 2026-03-31 M1 合并行情位于 `data/EditMode/EURUSD/1/Bars.dat`。
- 已新增 `convert_forex_tester_bars.py`，解析 Forex Tester Bars.dat 并输出 MT5/回放共用的无表头 9 列年度 CSV。
- 已生成 `Data/Local_Data/split_by_year/EURUSD_2002.csv`：250,385 行，实际时间为 2002-01-01 23:01 至 2002-12-30 23:00。
- `EURUSD_2002.csv` 已通过回放加载、9 列格式、严格升序、无重复和 OHLC 合法性验证；源数据的 2002 年成交量全部为 4，转换时原样保留，点差按现有年度格式写为 30。
- `MT5_EnergyTrading.mq5` 已升级到 1.72，FULL 默认品种改为 `EURUSD@_2002_FULL`，年度范围改为 2002–2002，并启用首次启动自动加载和 FULL 图表置顶。
- FULL 加载状态现按自定义品种保存为 `Energy_FullLoaded_<InpFullSymbolName>`，避免旧的 2024 加载标记阻止新数据集导入。
- 已修复两处 `StringToLower()` 返回值误用；MetaEditor 最终编译结果为 0 errors、0 warnings，生成的 EX5 位于 junction 单一代码源目录。
- 已建立 `D:\mt5\MQL5\Files\split_by_year` junction，目标为项目的 `Data/Local_Data/split_by_year`，解决 MQL5 `FileOpen` 无法直接访问项目绝对路径的问题，未复制 CSV。
- 2002 FULL 实机加载已通过 Experts 日志验证：CSV 14,021,560 字节打开成功，50 个分块均 `ok=1`，共导入 250,385 根、1 个文件。
- `EURUSD@_2002_FULL` M15 图表生成 24,348 根 K 线，最早时间为 2002-01-01 23:00，`GO START` 返回 `ok=1`；MT5 历史文件 `Bases/Custom/history/EURUSD@_2002_FULL/2002.hcc` 已生成。
- 已新增 `MT5_Integration/load_eurusd_2002.ini`，用于以新默认参数启动 EA，且明确设置 `AllowLiveTrading=0`；2026-07-28 实测启动配置加载成功。
- `MT5_EnergyTrading.mq5` 已升级到 1.73，新增默认开启的 `InpFullOnlyMode=true`；FULL 实例不再创建 replay 图，也不会初始化 pipe/replay UI。
- `load_eurusd_2002.ini` 已改为直接启动 `EURUSD@_2002_FULL` H1，而不是先启动 `EURUSD@_2024` replay 图。
- FULL-only 初始化会调用 `CloseAllChartsExcept()`；Experts 实测关闭 3 个旧图表、失败 0 个，并记录每个图表的 symbol/timeframe 与错误码。
- FULL-only H1 实测共有 6,090 根 K 线，最早时间为 2002-01-01 23:00，`GO START` 返回 `ok=1`；MetaEditor 编译结果为 0 errors、0 warnings。
- 清理后的最终 MT5 启动日志只出现 `MT5_EnergyTrading (EURUSD@_2002_FULL,H1) loaded successfully`，不再加载任何 2024/replay EA。
- 已修复任务栏手动重开 MT5 后只显示灰色工作区的问题：固定快捷方式 `Windsor Brokers MT5.lnk` 现永久携带 `/portable /config:"E:\Quantitative trading model\MT5_Integration\load_eurusd_2002.ini"`。
- 2026-07-28 已从修复后的任务栏快捷方式完成重启验证：进程命令行包含专用配置，Terminal 日志确认加载 `EURUSD@_2002_FULL,H1`，窗口截图确认 2002 FULL H1 行情与控制面板正常显示。
- 已将 `D:\mt5\MQL5\Profiles\Templates\EN.tpl` 完整复制为 MT5 特殊默认模板 `default.tpl`；当前终端会在每次创建 2002 FULL 启动图表时自动应用 EN 样式。
- 直接在 `[StartUp]` 设置 `Template=EN` 经视觉验证会被当时的 MT5 build 5660 忽略，因此该无效字段未保留；改用 `default.tpl` 后重启视觉验证通过。当前终端已升级到 build 6061，浅色背景、红绿 K 线、H1 全量行情和 1.74 EA 面板仍正常。
- 已停止旧 replay 图遗留的两个 `feed_replay.py` 进程及其启动批处理；当前没有项目 replay 后台进程运行。
- `SESSION_LOG.md` 已修复编码为 UTF-8 with BOM，并清理乱码内容。

- `MT5_EnergyTrading.mq5` 已新增 FULL 自动挂载能力：`InpFullAutoAttachEA` + `InpFullEATemplateName` + `InpFullEATemplateAltPath`（通过模板对 FULL 图表自动应用 EA）。
- FULL 左上角状态文字已默认关闭：`InpShowFullModeLabel=false`，并在更新状态时自动清理 `FullModeMsg`。
- FULL 图表已新增独立控制面板：`LOAD` + `GO START`；`GO START` 按钮可一键跳回该图表最早K线位置。

- 已修复控制面板白色虚线/可拖动问题：UI 对象统一设置为不可选中（`OBJPROP_SELECTABLE=false` + `OBJPROP_SELECTED=false`）。
- 已为按钮增加点击反馈：新增 `ClickFlash()`，点击时短暂按下再弹起。
- 已完成机会档案与标注工具的实现。截图只作为视觉证据，正式标注会保存 MT5 点击得到的精确时间、价格和结构角色，供后续程序与人工复核读取。
- 特征目录中的上升通道规则已作为首条案例的判定基准：向上推进与创新高、至少 5 个高低交替有效触点、上下边界同向向上且近似平行、回撤不破前低；第 5 个有效触点确认时才进入 `READY`，后续结果不得反向参与结构标注。
- `MT5_EnergyTrading.mq5` 已升级到 1.74。FULL 面板保留 `LOAD` 与 `GO START`，新增 `P1`–`P5`、`UPPER`、`LOWER`、`UNDO`、`CLEAR CASE`，并停止显示旧的 `LOAD ACC`、`CLEAR ACC`、`EXPORT`、`NEW BOX`、`FILL BOX`。
- P1–P5 会按点击位置自动吸附最近 H1 K 线的 High/Low，并绘制点名、纵向时间线和横向价格线；`UPPER` 强制吸附 High、`LOWER` 强制吸附 Low，各点击两次生成边线。
- 已实现 P1–P5 时间顺序、交替高低点、推进创新高/不破前低、上下轨同向上升和近似平行检查；P5 自动生成候选 `ready_time`，`future_outcome` 与结构字段保持分离。
- 已实现 250ms 按钮事件去重和选中按钮后 250ms 图表点击保护，避免对象事件与图表冒泡造成重复锚点；`UNDO` 回退最后锚点，`CLEAR CASE` 需在 5 秒内二次确认。
- 已建立 `Data/Local_Data/opportunity_annotations/opportunity_cases.csv`、`opportunity_anchors.csv` 和 `README.md`；首例 ID 为 `EURUSD-2002-H1-CHANNEL-001`，类型为 `ASCENDING_CHANNEL`。
- 已建立 `D:\mt5\MQL5\Files\opportunity_annotations` junction，目标为项目内 `Data/Local_Data/opportunity_annotations`，MT5 每次有效点击都会直接更新项目档案。
- 1.74 源码保持 CP936，严格字节往返检查通过；MetaEditor 编译结果为 0 errors、0 warnings，EX5 与源码时间一致。MT5 已自动升级到 build 6061，junction、源码和 EX5 均未被覆盖。
- 2026-07-28 已完成干净的单点实机验证：选择 P1 后等待 500ms 再点击行情，只写入一条 `P1`，吸附到 2002-01-11 03:00 的 Low 0.89210；图上点名、时间线、价格线和 `P 1/5` 状态可见。
- 同次验证中 `UNDO` 成功清除 P1，`CLEAR CASE` 二次确认成功清空案例；两个 CSV 最终均只保留表头，Experts 日志包含 mode/capture/archive/undo/clear 全流程且无错误。
- 最终验证截图位于 `Data/pattern_snapshots/mt5_annotation_p1_validation.png` 和 `mt5_annotation_panel_20260728.png`；空面板状态为 `P 0/5 | U 0/2 | L 0/2 | DRAFT`。

## Next Steps
- 下一 Session 先重做第一类结构标记的视觉：1.80 的拖动编辑已经通过，但 24 段 `OBJ_TREND` 圆环出现明显尖角/箭头状接缝，不能冻结。目标外观是平滑闭合圆、不同 `R` 下线宽恒定、序号数字 `1`、`2`、`3`……直接居中显示在圆内。
- 保留 1.80 已验证的交互语义：默认锁定，双击圆内数字进入/退出编辑并高亮，拖动数字按位移精确平移人工圆心，松开后重算并保存；CSV 结构角色仍保持 `S1`、`S2`……，仅图面显示去掉 `S` 前缀。
- 用户在当前 MT5 中目视确认只剩 `EURUSD@_2002_FULL` H1 一个图表，并核对首尾行情和缩放/滚动行为；日志层面的导入、起点跳转、图表清理和重启持久化已经通过。
- 当前阶段保持 `InpFullOnlyMode=true`；只有明确恢复慢速回放时才关闭该开关并重新启用 replay/Python 管道。
- 按数据计划继续从同一 Forex Tester M1 源导出 2003–2009，并聚合/核对 EURUSD H1/H4 与案例时区。
- 回到积累区定义时，先冻结候选区标签字段和文档规则，再扩展 Phase A 特征与人工复核工具。
- 为 12 类矩阵中的每条规则绑定书中页码、标准结构图和案例来源。
- 核对 OCR 矛盾、M/W 第二峰谷规则、头肩底颈线方向和“有效突破”定义，形成待确认清单。
- 用户审核并冻结特征目录 V1.0 后，进入总真值库设计与 MT5 通用标注工具阶段。
- 继续从同一 Forex Tester M1 源导出 2003–2009，并聚合/核对 EURUSD H1/H4 与案例时区。
- 收集上矩、下矩的标准、非标准和反例案例。
- 做一轮 MT5 回归：切换周期、重启终端、重新挂载 EA，确认 UI 与按钮行为稳定不回退。
- 统一梳理 FULL/REPLAY 控件代码，减少重复逻辑（面板创建、按钮反馈、状态同步）。
- 继续完成 `3.4_energy_theory` 与 `3.5_analysis_method` 的图文提炼。
- 依次提炼 `2.trade_opportunity_definition`、`3.trading_opportunity_identification_process`、`4.triangle`、`5.resonant_trading_opportunities`。
- 在 `modules/opportunity_detection/src/` 建立基础代码骨架与接口，并定义信号输出字段。

## Blockers / Risks
- `MT5_EnergyTrading.mq5` 不是标准 UTF-8 编码，后续编辑必须保留现有编码；该文件已有大量修改，不能回退无关内容。
- 1.80 已在 MT5 实机加载并验证拖动/保存，但 24 段趋势线圆环的尖角外观不合格；下一版不得重新使用会让全图 K 线发糊的 `OBJ_ELLIPSE`，也不能继续使用当前分段接缝外观。必须先找到平滑、恒定线宽且不改变 K 线渲染的圆形方案。
- 第一类结构圆的日志行为已验证，但新版前景空心圆尚需用户目视确认；MT5 硬件渲染不能用 Windows 后台截图验收，禁止再运行临时 `ChartScreenShot` 脚本。
- MT5 `FileOpen` 的绝对路径限制已通过 `D:\mt5\MQL5\Files\split_by_year` junction 解决；若移动 MT5 或项目目录，需要重建该 junction。
- 2002 FULL LOAD 已完成实机验证；其他年份尚未使用当前 1.72 路径逐年验证。
- `MT5_EnergyTrading_FULL.tpl` 当前不存在，但 FULL-only 通过启动配置直接挂载 1.73 EA，不依赖该模板；只有恢复旧双图表自动挂载方式时才需要处理。
- 现有案例库缺少上矩、下矩样本，矩形特征暂时只能依据书面标准和标准图起草。
- 2002 M1 原始行情已导出，但 2003–2009 尚未导出，案例也尚未完成同源时区映射，暂不能进入完整盲测。
- 书中 45°/90°角度依赖图表缩放，必须用 ATR 归一化斜率替代并通过案例确定阈值。
- MT5 对“跨图表自动挂 EA”存在平台限制，可能需要依赖模板或手工确认一次权限设置。
- `default.tpl` 当前是 `EN.tpl` 的精确副本；若以后重新保存或修改 EN 模板，需要再次同步到 `default.tpl` 才会影响后续自动启动。
- 若通过 `ChartApplyTemplate` 自动挂载，可能触发 EA 重启；需避免影响 REPLAY 图表实例。
- “回到起始日期”依赖 FULL 历史数据已加载；若 CSV 读取失败则按钮行为会退化。
- 需要确认机会识别最小需求与输出格式（信号字段、触发时机）。
- 部分量化阈值（振幅、角度、时间占比）需在后续章节提炼后统一确认。

## Notes
- 避免手动复制到 MT5 目录，保持 junction 单一代码源。
- 文档统一编码标准：UTF-8 with BOM（特别是 `SESSION_LOG.md`）。
- PDF 本地路径：`src/AsipanEnergyTradingSystem/docs/References/爱思潘交易系统.pdf`（已忽略提交）。

## Session Handoff (2026-07-29)
- 切换原因：用户已明确要求更新记录并切换 Session；本阶段“增加 MT5 绘图按钮并完成基础实机验证”已经结束。
- 当前目标状态：`MT5_EnergyTrading.mq5` 1.74 已实现并运行，FULL 面板包含 `LOAD`、`GO START`、`P1`–`P5`、`UPPER`、`LOWER`、`UNDO`、`CLEAR CASE`；旧积累区/矩形按钮不再显示。
- 已冻结交互语义：P1–P5 按时间顺序标记高低枢轴并自动吸附最近 K 线 High/Low；`UPPER` 选两次 High，`LOWER` 选两次 Low；P5 产生候选 `ready_time`；未来结果只写 `future_outcome`，不得参与结构判断。
- 本阶段主要文件：`MT5_Integration/MQL5_Link/MT5_EnergyTrading.mq5`、`Data/Local_Data/opportunity_annotations/opportunity_cases.csv`、`opportunity_anchors.csv`、`README.md`、`Data/pattern_snapshots/mt5_annotation_p1_validation.png`、`mt5_annotation_panel_20260728.png`、`SESSION_LOG.md`。
- 文件映射：`D:\mt5\MQL5\Files\opportunity_annotations` 是指向项目 `Data/Local_Data/opportunity_annotations` 的 junction；不要复制出第二份 CSV 数据源。
- 验证结果：MetaEditor 编译为 0 errors、0 warnings；源码 CP936 严格往返通过；单点 P1 吸附、点名/时间线/价格线、事件去重、`UNDO`、五秒二次确认 `CLEAR CASE` 均通过 Experts 日志和截图验证。
- 当前数据状态：截至 2026-07-29，两张 opportunity CSV 均只保留表头，没有测试锚点或案例污染；空面板应显示 `P 0/5 | U 0/2 | L 0/2 | DRAFT`。
- 当前运行环境：`D:\mt5\terminal64.exe` 正通过 `/portable /config:"E:\Quantitative trading model\MT5_Integration\load_eurusd_2002.ini"` 运行；图表应为唯一的 `EURUSD@_2002_FULL` H1，MT5 build 6061，FULL-only 模式开启，旧 replay/Python 后台未运行。
- 工作树注意：仓库仍有本阶段之前已存在的多项修改和未跟踪文件；新 Session 不得重置、覆盖或清理这些用户改动，也不要删除 `MT5_EnergyTrading.mq5.bak`，除非用户明确授权。
- 编码要求：EA 为 CP936。若继续修改，必须先 CP936 转临时 UTF-8、使用 `apply_patch`、转回 CP936、验证严格字节往返，再用 MetaEditor 编译；`SESSION_LOG.md` 必须保持 UTF-8 BOM。
- 下一 Session 第一优先级：先读取本文件；随后等待用户明确“执行/开始/继续”。收到执行后，用首个真实上升通道完成 P1–P5 与上下轨四端点的端到端标注，核对 `READY` 规则与 CSV，再冻结批量标注 schema。
- 尚未完成：完整上升通道的 P1–P5 + UPPER/LOWER 九锚点验证、批量 12 类案例标注、2003–2009 数据导出，以及三角形积累区识别器后续阶段。

## Session Continuation (2026-07-29, EA 1.75)
- 第一阶段范围已冻结为“完善第一类结构点标记工具”；第二类按钮明确延后，必须在第一类验收完成后再设计。
- `MT5_EnergyTrading.mq5` 已升级到 1.75：`P1`–`P5` 合并为单一 `STRUCT` 按钮，按成功捕获顺序自动生成 `S1`、`S2`、`S3`……，使用动态数组，不再限制五个点。
- 结构点保留人工点击得到的原始圆心时间和价格，不吸附单根 K 线；同一案例使用统一半径，面板通过 `SIZE -`、`SIZE +` 在 1–10 根 K 线范围内调节，默认 `R=2`。
- 每个结构圆保存圆心、半径、固定时间范围、圆形价格边界、区域 OHLC、自动判定的 `HIGH/LOW` 代表点及动作顺序；`formation_start` 取 `S1` 区域起点，`ready_time` 取 `S5` 区域终点。
- 原始标注周期是权威周期；切换到其他周期时案例只读，避免同一案例因周期变化被误改。`UPPER/LOWER` 旧逻辑保留，但不属于本轮第二类按钮设计。
- `opportunity_anchors.csv` 新 schema 使用 `STRUCT/LINE` 记录，同时兼容读取旧版 P1–P5；旧案例只有在下一次有效保存时才迁移，不会在加载时自动覆盖。
- 1.75 正式源码保持 CP936，严格字节往返通过；MetaEditor 正式编译为 `0 errors, 0 warnings`，EX5 与源码时间一致。
- 2026-07-29 用户实机回归已覆盖：半径在 R=2–5 间连续调整并重算保存、自动生成 S1–S6、超过五点继续编号、倒序中心时间拒绝、UNDO 删除并正确重新编号、250ms 重复按钮事件抑制、重启加载 `radius=4` 与新 schema。
- 用户最后连续执行 UNDO 至空案例；当前 `opportunity_cases.csv` 保留 `pivot_count=0` 的 DRAFT 快照，`opportunity_anchors.csv` 只保留新 schema 表头，当前没有测试锚点需要清理。
- 验收期间一次性 `CodexChartScreenshot` 脚本阻塞 MT5 主线程并造成卡死；该临时脚本、EX5、日志和无效截图已全部删除。正式 1.75 EA 不是该卡死原因，终端随后以正式启动配置恢复并保持响应。
- 后续禁止自动发送 MT5 鼠标/键盘输入，也禁止临时 `ChartScreenShot` 脚本；按钮与外观验收由用户手动操作，助手只读取 Experts 日志和 CSV。
- 当前终端通过 `/portable /config:"E:\Quantitative trading model\MT5_Integration\load_eurusd_2002.ini"` 运行，唯一正式实例为 `EURUSD@_2002_FULL` H1，1.75 EA 已加载。

## Session Continuation (2026-07-29, Structure Circle Center Fix)
- 已修复结构圆的实际圆心时间偏移：`RecalculateOpportunityStructure()` 不再用两端整点 K 线开盘时间作为椭圆边界，而是严格保存 `centerTime +/- PeriodSeconds(timeframe) * radiusBars`。例如 H1、`R=4`、人工圆心 `10:45` 现在保存 `06:45–14:45`，几何中心保持 `10:45`。
- 区域 OHLC 与 `HIGH/LOW` 代表点仍使用原有 `newestShift/oldestShift` K 线范围采样，本次没有改变代表点判定、按钮行为或 CSV schema；新增 `PeriodSeconds() <= 0` 错误日志和失败保护。
- 为区分终端缓存的新旧二进制，正式 `MT5_EnergyTrading.mq5` 已升级为 1.76，并保持 CP936；临时 UTF-8 文本与正式源码严格一致，CP936 字节往返通过。MetaEditor 于 11:58:48 编译正式源码，结果为 `0 errors, 0 warnings`，正式 EX5 已更新。
- 11:54:09–11:54:13 用户切换 H4/H1 后虽出现 `EA INIT | ver=1.75`，但随后 11:56 的实机标记仍执行旧边界：如 `center_time=23:30`、`R=2` 保存为 `21:00..01:00`，而正确值应为 `21:30..01:30`。这证明切换周期只会重新初始化缓存模块，不能代替完整终端重启；重开后必须先确认 `EA INIT | ver=1.76`。
- 当前标注数据保持空测试状态：用户在 11:56 完成 S1–S5 旧缓存验证后连续 UNDO 清空，`opportunity_cases.csv` 为 `pivot_count=0` 的 DRAFT 行（更新时间 11:56:31），`opportunity_anchors.csv` 只有新 schema 表头，不得恢复旧 P1–P5。

## Session Handoff (2026-07-29 Noon, Continue in Afternoon)
- 切换原因：用户要求午间更新记录并切换 Session，下午继续；上午阶段已完成第一类结构圆的圆心时间修复、版本标识、正式编译和旧缓存诊断。
- 当前代码状态：`MT5_EnergyTrading.mq5` 正式版本为 1.76。结构圆时间边界严格使用 `centerTime +/- PeriodSeconds(timeframe) * radiusBars`；区域 OHLC 与 `HIGH/LOW` 代表点采样逻辑未改变，第二类按钮没有开始设计。
- 构建状态：正式源码保持 CP936，严格文本一致与字节往返均通过；MetaEditor 11:58:48 编译结果为 `0 errors, 0 warnings`。E: 项目路径与 D: MT5 junction 下的 EX5 哈希一致，临时 UTF-8 和编译日志均已清理，`MT5_EnergyTrading.mq5.bak` 保留。
- 当前运行状态：MT5 仍为 PID 1504、响应正常、图表为 `EURUSD@_2002_FULL` H1。Experts 最后一次 H1 初始化发生在 11:58:24，明确为 `EA INIT | ver=1.75`；1.76 EX5 在 11:58:48 才生成，因此当前进程仍运行缓存的旧 1.75，尚未完成 1.76 实机验收。
- 旧缓存证据：11:56 的 H1 测试中，`center_time=23:30`、`R=2` 仍保存 `21:00..01:00`，正确值应为 `21:30..01:30`。用户随后连续 UNDO 清空 S1–S5，日志无 ERROR/WARN。
- 当前数据状态：`opportunity_cases.csv` 只有 `pivot_count=0` 的 DRAFT 行（更新时间 11:56:31）；`opportunity_anchors.csv` 只有新 schema 表头，没有测试锚点或旧 P1–P5 数据。
- 下午 Session 第一优先级：先读取本文件并等待用户明确“继续”；随后由用户完整关闭 MT5，并从固定快捷方式重新打开。助手只读确认新 PID 和 `EA INIT | ver=1.76`，不得代替用户操作界面。
- 1.76 验收方法：用户在 H1 选择 `R=2`，手动标记一个带非整点分钟的结构圆；例如圆心 `23:30` 必须记录为 `21:30..01:30`。助手核对 Experts 的初始化、捕获、错误 ID、保存结果和 CSV；用户目视确认圆心与点击位置一致，最后 UNDO 清空测试点。
- 验收门禁：上述行为与外观均通过后，才能冻结第一类结构点按钮并进入第二类按钮讨论；不要在下午 Session 一开始并行扩展 `UPPER/LOWER` 或其他交互。
- 主要修改文件：`MT5_Integration/MQL5_Link/MT5_EnergyTrading.mq5`、`SESSION_LOG.md`。工作树还有用户原有修改，禁止 reset、覆盖或清理无关文件。
- 安全约束继续有效：禁止自动发送 MT5 鼠标/键盘输入，禁止再次创建或运行 `ChartScreenShot` 临时脚本；用户负责界面操作，助手只读取 Experts 日志和 CSV。

## Session Continuation (2026-07-29, EA 1.77 Minimal Structure Marker)
- 用户重新冻结第一类 `STRUCT` 的目的：工具只负责忠实记录人工识别的结构特征与分析依据，为后续算法设计建立人工真值；自动判断不得替代人工标注。
- 正式人工真值是原始点击得到的 `center_time`、`center_price`、圆形范围、动作顺序和 `S#` 角色。点击坐标不吸附、不取整、不重新居中；半径调整只改变范围，圆心保持不变。
- `MT5_EnergyTrading.mq5` 已升级到 1.77。已修正 `OBJ_ELLIPSE` 三锚点的退化布置，改为围绕人工圆心对称的包围框锚点；圆形改为前景、空心、2 px 轮廓。
- 每个结构在图上只绘制圆形与 `S1`、`S2`……序号；已移除可见中心点、代表 K 线点以及 `S# HIGH/LOW` 文本。区域 OHLC 和代表 `HIGH/LOW` 仍可作为后台派生字段写入 CSV，但不影响人工圆心或可见标注。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步人工真值与派生字段的边界。第二类 `UPPER/LOWER` 逻辑未修改，也未开始扩展其他交互。
- 正式源码保持 CP936，临时 UTF-8 与正式源码文本一致，项目路径与 D: MT5 junction 源码哈希一致；MetaEditor 于 14:26:21 编译完成，结果为 `0 errors, 0 warnings`，正式 EX5 已更新。
- 当前运行中的 MT5 PID 22848 于 13:57:12 加载的是 1.76；必须由用户完整关闭并从固定快捷方式重开后，先核对 `EA INIT | ver=1.77`，再手动测试精确圆心、半径不移心、空心圆可见且只显示 `S#`。
- 当前标注数据仍为空测试状态：`opportunity_cases.csv` 为 `pivot_count=0` 的 DRAFT 行，`opportunity_anchors.csv` 只有新 schema 表头。验收测试完成后必须 `UNDO` 清空测试点。
- 安全约束继续有效：助手不得自动发送 MT5 鼠标/键盘输入，不得创建或运行临时 `ChartScreenShot` 脚本；外观由用户目视验收，助手只读取 Experts 日志与 CSV。

## Session Continuation (2026-07-29, EA 1.78 Background Circle Rendering Fix)
- 用户提供标注前后截图，确认 1.77 添加结构圆后整张图的 K 线边缘变粗、发黏；用户随后在不缩放、不滚动的情况下执行 `UNDO`，K 线立即恢复清晰，因此排除截图缩放与图表比例变化。
- 代码核对确认标注路径没有修改 `CHART_SCALE`、模板或颜色。1.77 相比旧版把修正后的 `OBJ_ELLIPSE` 设置为前景 `OBJPROP_BACK=false` 且宽度为 2 px，这是触发 MT5 前景合成重绘副作用的直接条件。
- 正式 `MT5_EnergyTrading.mq5` 已升级到 1.78：保留精确时间/价格椭圆锚点与 `OBJPROP_FILL=false`，将圆改为背景 `OBJPROP_BACK=true`、1 px 轮廓；`S#` 文本仍在前景。这样既保持人工圆心和范围精度，也避免圆形对象改变 K 线视觉清晰度。
- 1.78 源码保持 CP936；MetaEditor 正式编译结果为 `0 errors, 0 warnings`，EX5 已更新。`Data/Local_Data/opportunity_annotations/README.md` 已同步背景圆的渲染约束。
- 用户的 `UNDO` 已清空本轮测试点，`opportunity_anchors.csv` 当前只有新 schema 表头。运行中的 MT5 PID 22932 仍加载 1.77，必须完整重启并确认 `EA INIT | ver=1.78` 后再做一次前后清晰度对比。
- 验收标准：添加一个 `S1` 后，圆心与点击位置一致、圆轮廓可见、只显示 `S1`，且 K 线与添加前同样清晰；随后 `UNDO` 清空测试点。助手继续只读日志和 CSV，不操作 MT5 界面。

## Session Continuation (2026-07-29, EA 1.79 Text Circle Rendering Fix)
- 用户实测 1.78 后确认：即使 `OBJ_ELLIPSE` 设置为背景、空心和 1 px，只要圆形对象存在，整张图的 K 线仍会发糊；`UNDO` 删除后立即恢复。因此根因最终冻结为当前 MT5 build 对 `OBJ_ELLIPSE` 的整体渲染副作用，与前景/背景、填充或线宽无关。
- `MT5_EnergyTrading.mq5` 已升级到 1.79，并从结构标记路径彻底移除 `OBJ_ELLIPSE`；正式源码内 `OBJ_ELLIPSE` 计数为 0。结构圆改为精确中心上的 `OBJ_TEXT` 字符 `○`，字体为 `Segoe UI Symbol`，字号按保存的时间半径在当前图表对应的像素直径与终端 DPI 自动计算。
- 人工真值语义未改变：`center_time`、`center_price`、`radius_bars`、时间范围、价格范围和派生统计仍按原 schema 保存；文本圆环只负责无副作用显示，不替代 CSV 中的精确范围。
- MetaEditor 正式编译 1.79 的结果为 `0 errors, 0 warnings`；源码保持 CP936 且字符 `○` 可严格往返。编码临时文件与编译日志均放在项目目录外，避免再次产生项目内数千行临时删除统计。
- 用户已 `UNDO` 清空 1.78 测试点，`opportunity_anchors.csv` 当前只有新 schema 表头。运行中的 MT5 PID 828 仍加载 1.78，完整重启并确认 `EA INIT | ver=1.79` 后，再标记一个 `S1` 比较前后 K 线清晰度。
- 1.79 验收标准：添加 `S1` 后 K 线清晰度完全不变；圆环中心与点击位置一致；`SIZE -/+` 改变圆环大小但不移动中心；只显示圆环与 `S1`。通过后 `UNDO` 清空测试点并冻结第一类标记工具。

## Session Continuation (2026-07-29, EA 1.80 Fixed-Width Circle and Drag Editing)
- 用户确认 1.79 的文本圆环解决了 K 线发糊，但字体放大时圆环边线也会变粗；同时要求首次标记不准确时可反复调整位置。交互冻结为：默认锁定，双击 `S#` 进入/退出编辑，高亮后拖动标签平移整个结构，空白点击退出。
- `MT5_EnergyTrading.mq5` 已升级到 1.80。文本字符圆已移除，结构圆改为 24 段 `OBJ_TREND` 近似圆，每段固定 `STYLE_SOLID`、1 px；正式源码仍保持 `OBJ_ELLIPSE=0`、圆字符计数为 0，因此半径变化不会改变线宽，也不会重新引入椭圆渲染副作用。
- 新增编辑状态：双击间隔为 450ms；活动圆环和 `S#` 统一变为 `clrGold`，面板显示 `EDIT S# | DRAG`，仅活动标签设置为可选中和已选中。圆环线段始终不可选，避免误拖。
- 拖动采用标签位移而不是标签绝对位置：新圆心等于旧圆心加上标签时间/价格位移，因此标签仍保持在圆顶而不会造成圆心跳到文字位置。拖动不吸附 K 线，半径、角色、动作序号保持不变。
- 拖动释放后重新运行区域 OHLC/派生代表点计算并保存 CSV；日志包含旧圆心、新圆心、半径和保存结果。若新时间越过相邻结构、坐标无效、重算失败或保存失败，则恢复旧结构并记录 WARN/ERROR；保存失败时额外尝试将旧状态重新写回档案。
- 双击同一标签或点击空白区域退出编辑；点击任一标注按钮也会先退出编辑。`UNDO` 语义保持为删除最后一个标注，不作为位置移动历史撤销。
- 正式源码为 1.80、3953 行、156 个函数、括号 366/366；CP936 严格往返通过，项目路径与 D: MT5 junction 源码 SHA256 一致。MetaEditor 于 15:12:27 编译结果为 `0 errors, 0 warnings`，正式 EX5 已更新。
- 当前 MT5 PID 21588 仍运行 1.79。当前 CSV 保留一个测试 `S1`：中心 `2002.01.17 00:15 / 0.88488`、`R=2`、动作序号 2；重启 1.80 后可直接用它测试双击高亮、拖动保存、半径固定线宽和时间越界恢复，验收后再由用户决定是否 `UNDO` 清空。
- 安全约束继续有效：助手不得自动发送 MT5 鼠标/键盘输入，不得创建截图脚本；用户负责界面拖动与目视验收，助手只读取 Experts 日志和 CSV。

## Session Handoff (2026-07-29, After EA 1.80 Drag Validation)
- 切换原因：用户明确要求更新记录并切换 Session；本阶段已完成“固定线宽圆环 + 双击拖动编辑”的代码与实机行为验证，但圆形外观方向需要重做，适合在新 Session 单独处理。
- 当前代码状态：`MT5_EnergyTrading.mq5` 正式版本为 1.80，3953 行、156 个函数、括号 366/366；源码保持 CP936，项目路径与 D: MT5 junction 源码 SHA256 均为 `B1351B97ECC8BC6195060145D944EA1BB784FAAE53B4C518AC579F7A2032710B`。
- 构建状态：MetaEditor 于 15:12:27 编译结果为 `0 errors, 0 warnings`，正式 EX5 大小 171294 字节；临时 UTF-8 与编译日志均在项目目录外创建并已清理，没有项目内临时文件删除统计。
- 当前运行状态：MT5 PID 10816 于 15:14:57 实际加载 `EA INIT | ver=1.80`，命令行仍为 `/portable /config:"E:\Quantitative trading model\MT5_Integration\load_eurusd_2002.ini"`，图表为 `EURUSD@_2002_FULL` H1。
- 已通过的实机行为：用户确认圆内标记可进入编辑并拖动；Experts 多次记录 `label_double_click_enter`、`chart_click` 退出和 `structure move result`，S1/S2 的时间与价格均能移动并成功保存，日志未出现本轮拖动相关 ERROR。
- 尚未通过的外观：24 段 `OBJ_TREND` 组合圆在用户截图中出现明显尖角/向右箭头状突出；虽然代码固定为 1 px，也不再造成全图 K 线发糊，但不符合“简单圆形标记”要求，第一类标记工具仍未冻结。
- 用户冻结的新外观目标：参考带圈数字图片，圆必须平滑、闭合、线宽不随 `R` 改变；圆内只显示数字 `1`、`2`、`3`……，不再把 `S1` 放在圆上方。为兼容档案，CSV 的 `anchor_role` 继续保存 `S1`、`S2`……，仅视觉文本显示数字部分。
- 拖动目标保持不变：默认锁定；双击圆内数字后圆与数字高亮并变为可拖动；拖动数字按相对位移平移结构中心，不吸附 K 线；再次双击或点击空白退出；时间越过相邻结构时拒绝并恢复；`UNDO` 仍删除最后一个标注而不是撤销移动。
- 当前测试数据不是空档案：`opportunity_cases.csv` 为 `pivot_count=2` 的 DRAFT；`opportunity_anchors.csv` 保留 S1=`2002.01.17 07:00 / 0.88702`、S2=`2002.01.18 15:00 / 0.87949`，两者均为 `R=2`。这些是 1.80 拖动测试结果，下一 Session 不得擅自删除；可用于新视觉加载测试，最终是否清理由用户决定。
- 下一 Session 第一优先级：读取本文件后等待用户明确“继续”；随后只设计并实现圆形视觉/数字居中，不扩展第二类 `UPPER/LOWER`。新方案必须同时避开 `OBJ_ELLIPSE` 的全图模糊副作用和当前 `OBJ_TREND` 分段尖角，并保留 1.80 已验证的拖动与 CSV 保存逻辑。
- 主要文件：`MT5_Integration/MQL5_Link/MT5_EnergyTrading.mq5`、`Data/Local_Data/opportunity_annotations/README.md`、`opportunity_cases.csv`、`opportunity_anchors.csv`、`SESSION_LOG.md`。工作树仍有大量此前用户修改和未跟踪文件，禁止 reset、覆盖或清理无关内容，`MT5_EnergyTrading.mq5.bak` 必须保留。
- 安全约束继续有效：禁止自动操作 MT5 鼠标/键盘，禁止创建 `ChartScreenShot` 临时脚本；用户负责目视验收，助手只读取 Experts 日志与 CSV。EA 后续编辑必须继续使用“项目外临时 UTF-8 -> apply_patch -> 回写 CP936 -> 严格往返 -> MetaEditor 编译”的流程。

## Session Continuation (2026-07-29, EA 1.81 Smooth Circled Numbers)
- 用户再次确认 1.80 的拖动行为可用，但 24 段 `OBJ_TREND` 圆环在接缝处形成尖角/箭头状突出；新视觉目标冻结为参考图中的平滑空心圆，圆内仅显示 `1`、`2`、`3`……，不再在圆外显示 `S1`、`S2`。
- `MT5_EnergyTrading.mq5` 已升级到 1.81。结构标记改为单个透明 `OBJ_BITMAP_LABEL`，通过 `CCanvas::CircleAA()` 绘制抗锯齿固定宽度圆环，并在同一画布中心绘制数字；结构路径继续保持 `OBJ_ELLIPSE=0`，同时彻底移除 24 段结构圆，因此不会再有分段尖角，也不会重新触发 `OBJ_ELLIPSE` 的全图 K 线模糊副作用。
- 图面数字与档案角色明确分离：画布只显示 `1`、`2`、`3`……，CSV 的 `anchor_role` 仍保存 `S1`、`S2`、`S3`……；案例 schema、人工圆心、半径、时间/价格范围、动作顺序和派生字段均未改变。
- 1.80 的编辑语义保留：默认锁定，双击圆内数字进入/退出编辑并整体高亮为金色；拖动的是“圆 + 数字”组合标记，松开后将位图中心的屏幕坐标转换回精确时间/价格，再执行原有时间顺序校验、结构重算和 CSV 保存；跨越相邻结构仍拒绝并恢复。
- 新增图表视口同步：滚动时标记重新对齐保存的人工圆心，缩放时按 `radius_bars` 重算画布直径；圆环始终为抗锯齿固定像素线宽，保存的结构边界不随视口变化。
- 正式源码保持 CP936，项目外临时 UTF-8 补丁回写后严格文本/字节往返通过；源码与 D: junction SHA256 均为 `8EAE0FED3E391513E0BF0C259EAC2F3A568D466D97010853EE975A2CAD907CBE`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`，EX5 SHA256 为 `0582DB8934DE2D07E149897EF63D4A0CA2540412CE9FC21C40C67DE1D0869783`。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 1.81 的平滑圆内数字、视口刷新和拖动坐标语义。
- 当前 MT5 仍是 PID 10816，并继续运行缓存的 1.80；Experts 最后初始化为 15:14:57 的 `EA INIT | ver=1.80`。用户必须完整关闭终端并从固定快捷方式重开，先确认 `EA INIT | ver=1.81`，才能进行视觉与拖动实机验收；助手不得代替用户操作界面。
- 当前测试档案保持不变：案例为 `pivot_count=2` 的 DRAFT，S1=`2002.01.17 07:00 / 0.88702`、S2=`2002.01.18 15:00 / 0.87949`，两者均为 `R=2`。1.81 重启后可直接验证圆内数字 `1/2`、平滑闭合、K 线清晰度、双击高亮、拖动保存与缩放线宽；测试数据是否清理由用户决定，助手不得擅自删除。
- 1.81 验收门禁：圆环无尖角且平滑闭合；数字严格居中且无 `S` 前缀；添加/加载标记后 K 线清晰度不变；`SIZE -/+` 改变直径但不改变线宽；双击数字、拖动、退出编辑、时间越界恢复和 CSV 保存日志均正常。通过后才能冻结第一类标记并讨论第二类按钮。
- 安全约束继续有效：禁止自动发送 MT5 鼠标/键盘输入，禁止创建或运行 `ChartScreenShot` 临时脚本；外观由用户目视验收，助手只读取 Experts 日志与 CSV。

## Session Continuation (2026-07-30, EA 1.82 Key Bar Highlight)
- 用户已确认 1.81 的圆内数字结构点位置准确、可移动，正式案例当前保留 S1–S5；下一独立功能冻结为“高亮一根关键 K 线”，其出现代表行情从结构阶段进入释放/爆发阶段。
- `MT5_EnergyTrading.mq5` 已升级到 1.82，FULL 面板顶部新增 `KEY BAR` 按钮。选择后点击图表会通过 `iBarShift()` 吸附真实原始周期 K 线，而不是保存任意鼠标价格；每个案例当前只保留一根权威关键 K 线，档案角色为 `RELEASE_BAR`，重新选择会替换旧值。
- 关键 K 线保存 `bar_time`、`confirm_time`、高亮左右时间、完整 OHLC、原始 bar shift、`BULL/BEAR/DOJI` 方向和统一 `action_sequence`。`confirm_time=bar_time+PeriodSeconds(timeframe)`，明确表示该 K 线收盘后才可确认，避免在开盘时提前使用完整 K 线造成未来信息泄漏。
- 图面高亮使用 MT5 原生、前景、无填充的金色 `OBJ_RECTANGLE`，水平范围围绕该根 K 线中心，垂直范围在真实 High–Low 外增加 4%/最少 5 points 的视觉边距；正式真值仍是保存的 OHLC，不是矩形边距。
- 新增 `Data/Local_Data/opportunity_annotations/opportunity_key_bars.csv`，schema 为 `case_id,case_type,role,action_sequence,symbol,timeframe,bar_time,confirm_time,highlight_start_time,highlight_end_time,open,high,low,close,bar_shift,direction,updated_at`。当前文件只有表头，尚未写入测试关键 K 线。
- 启动时 1.82 会读取关键 K 线 CSV 并重建原生矩形；面板状态新增 `K 0/1`。关键 K 线已接入统一保存、只读周期保护、动作序列、`UNDO` 和五秒二次确认 `CLEAR CASE`；若关键 K 线是最后动作，`UNDO` 会只删除它并保留 S1–S5。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 KEY BAR 操作、确认时间、防未来泄漏、恢复和撤销语义。
- 正式源码保持 CP936，严格字节往返、括号 397/397、项目路径与 D: junction 源码一致；本轮精确差异空白检查无新增错误。源码 SHA256 为 `1B018733F63A16BC2791A703A803720BE11E8569AAB53230E88F7923F2E776C9`，MetaEditor 正式编译结果为 `0 errors, 0 warnings`，EX5 SHA256 为 `720C3A7BBF73419458171CAC4276FF7836141BCA07E63AFA5F6AE2094A80C0D1`。
- 当前正式案例数据未被本轮修改：`opportunity_cases.csv` 仍为 `pivot_count=5`、更新时间 `2026.07.30 15:22:42`；`opportunity_anchors.csv` 仍有且仅有 S1–S5 五行。
- 当前 MT5 PID 15680 仍运行缓存的 1.81，Experts 最后初始化为 `EA INIT | ver=1.81`。用户必须完整关闭终端并从固定快捷方式重开，先确认 `EA INIT | ver=1.82`，再手动选择 `KEY BAR` 点击一根测试 K 线；助手不得代替用户操作界面。
- 1.82 验收门禁：按钮点击只产生一条捕获；矩形准确框住目标 K 线且不遮挡/模糊蜡烛；Experts 包含初始化、mode、`key bar captured`、archive result 与错误 ID；CSV 的时间/OHLC 与 MT5 数据窗口一致；完整重启后矩形自动恢复；最后用 `UNDO` 验证只移除关键 K 线且 S1–S5 不变。是否保留正式关键 K 线由用户决定。
- 更完整的 MT5 原生绘图对象归档/恢复仍是后续独立阶段，本轮没有扫描或保存用户手动画出的任意趋势线、通道、竖线或矩形。
- 安全约束继续有效：禁止自动发送 MT5 鼠标/键盘输入，禁止创建或运行 `ChartScreenShot` 临时脚本；外观由用户目视验收，助手只读取 Experts 日志与 CSV。

## Session Continuation (2026-07-30, EA 1.83 Pixel-Accurate Key Bar Frame)
- 用户实测 1.82 后确认关键 K 线捕获时间与 OHLC 准确，但金色 `OBJ_RECTANGLE` 没有严格框住所点击的蜡烛。根因是左右锚点使用半周期时间（例如 H1 的 `16:30..17:30`），MT5 对非整柱时间的数据坐标映射会产生横向离散偏移；问题只在视觉渲染，不在 CSV 真值。
- `MT5_EnergyTrading.mq5` 已升级到 1.83。关键 K 线外框从数据坐标 `OBJ_RECTANGLE` 改为透明 `OBJ_BITMAP_LABEL + CCanvas`：使用 `ChartTimePriceToXY()` 获取目标柱时间中心及 High/Low 的精确屏幕位置，使用相邻真实 K 线中心距离计算柱间距，左右半宽为柱间距的 45%，上下在真实 High/Low 外各留 3 px，边框固定为 2 px。
- 新增 `RefreshOpportunityKeyBarMarker()` 并接入 `CHARTEVENT_CHART_CHANGE`。滚动时外框重新对齐保存的目标柱中心；缩放导致宽高变化时释放旧动态资源并重建画布，因此外框始终只围住目标 K 线，不再依赖半周期时间锚点。
- 正式数据语义和 schema 未改变：`bar_time`、`confirm_time`、OHLC、方向、`bar_shift`、动作序列及历史 `highlight_start_time/highlight_end_time` 继续保存；这些字段仍是恢复真值，像素外框只负责当前视口显示。
- 当前正式标注数据保持不变：`opportunity_key_bars.csv` 仍只有一根 `2002.01.23 17:00` 的 `RELEASE_BAR`，OHLC=`0.88330/0.88350/0.88080/0.88090`；`opportunity_anchors.csv` 仍有且仅有 S1–S5 五个结构点，未删除或重写用户数据。
- 正式源码保持 CP936 且严格字节往返通过，行数 4605，括号 412/412；项目路径与 D: MT5 junction 源码 SHA256 均为 `5CA473C0A1509D441E72C0605EFB7E3C0C629926C49E0F0E6587BD31F5A6E74F`。MetaEditor 于 16:10:58 编译结果为 `0 errors, 0 warnings`，EX5 SHA256 为 `874A014FFBA738340591A19E302079A34A23419E57B0A78D75A8F1945BB0B015`。
- 当前 MT5 仍为 PID 2596，Experts 最后初始化为 16:00:57 的 `EA INIT | ver=1.82`；编译后终端没有自动热重载。用户需完整关闭 MT5 并从固定快捷方式重开，确认 `EA INIT | ver=1.83` 后目视验收当前保留的关键 K 线外框。
- 1.83 验收门禁：外框严格水平居中于 `2002.01.23 17:00` 目标蜡烛；左右边线不跨入相邻 K 线且不压住目标蜡烛；上下边线完整包住 High/Low；滚动和缩放后仍保持对齐；重启恢复后 CSV 时间/OHLC 不变。助手继续不操作 MT5 界面，只读取 Experts 与 CSV，视觉结果由用户确认。

## Session Continuation (2026-07-30, EA 1.84 Key Bar Pixel Edge Correction)
- 用户重启并实测 1.83：Experts 于 16:14:07 确认 `EA INIT | ver=1.83`；随后重新标记 `2002.01.23 17:00`，捕获与归档日志均成功。用户截图确认目标柱已经选对、整体外框基本对齐，但高倍放大后右边和底边仍各多出约 1 px。
- 根因是 1.83 将画布宽高按包含末端像素的闭区间计算：`width=right-left+1`、`height=bottom-top+1`；结合 MT5 蜡烛的屏幕栅格取整，会让右边和底边比左边和上边多保留一个末端像素。
- `MT5_EnergyTrading.mq5` 已升级到 1.84，只将关键 K 线画布改为右/下半开像素边界：`markerWidth=halfWidth*2`、`markerHeight=bottomY-topY`。因此右边和底边各收回 1 px，左边、上边、柱中心、45% 柱间距半宽、High/Low 及 3 px 基础边距均不改变。
- 正式档案未改变：关键 K 线仍为 `2002.01.23 17:00`，OHLC=`0.88330/0.88350/0.88080/0.88090`，`action_sequence=15`；S1–S5 五个结构点完整保留。
- 1.84 源码保持 CP936 严格字节往返，行数 4605、括号 412/412，项目路径与 D: junction 源码 SHA256 均为 `FF04581631DBD2A50446612F2030CB7B3A96AE8BD742D94AC56E7DD44BB73354`。MetaEditor 于 16:21:04 编译结果为 `0 errors, 0 warnings`，EX5 SHA256 为 `9A06BA2B37D748E306D59AF69E229BDC1516B1DC5C0BD0712F0F81554A15AB3D`。
- 当前 MT5 进程仍运行 1.83，编译后未自动热重载。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=1.84` 后查看同一根已保存关键 K 线；验收重点只看右边和底边是否各准确收回 1 px，并继续检查缩放/滚动后对齐。

## Session Continuation (2026-07-30, EA 1.85 Key Bar Inner-Edge Fit)
- 用户已重启并实测 1.84；Experts 于 16:24:11 确认 `EA INIT | ver=1.84`，并成功从 CSV 恢复 `2002.01.23 17:00` 关键 K 线。截图确认 1.84 的右侧和底端间隙比 1.83 更小，但仍未完全贴合蜡烛边缘。
- 结合 2 px 画布边框的内缩方式，1.84 的外侧末端虽然各收回 1 px，但边框内侧在右边和底边仍保留约 1 px 空隙。`MT5_EnergyTrading.mq5` 已升级到 1.85，将 `markerWidth` 从 `halfWidth*2` 改为 `halfWidth*2-1`，将 `markerHeight` 从 `bottomY-topY` 改为 `bottomY-topY-1`。
- 1.85 相比 1.84 继续只收回右边和底边各 1 px；左边、上边、目标柱中心、High/Low、相邻柱间距算法和 CSV 真值均不变。预期 2 px 边框的内侧线将直接贴到目标蜡烛最右像素与 Low 像素，不再保留可见空隙。
- 当前正式档案仍只有一根 `2002.01.23 17:00` 关键 K 线，OHLC=`0.88330/0.88350/0.88080/0.88090`，最新 `action_sequence=21`；S1–S5 五个结构点保持完整。
- 1.85 源码保持 CP936 严格字节往返，行数 4605、括号 412/412，项目路径与 D: junction 源码 SHA256 均为 `ED8B3586AF01A11EBCFFC16569D6C381DF34BDDE2B8D950911ED4FAFBEC9B399`。MetaEditor 于 16:28:19 编译结果为 `0 errors, 0 warnings`，EX5 SHA256 为 `CEC21B1B4D2922B8F848A3FC978B2874BF3A895501A1B17FC5836D5745731D9B`。
- 当前 MT5 PID 12420 仍运行 1.84。用户需完整重启并确认 `EA INIT | ver=1.85` 后查看同一根恢复标记；验收重点是右侧和底端内边线是否与蜡烛边缘贴合，同时不能压住蜡烛实体或最低点。

## Session Handoff (2026-07-30, EA 1.85 Key Bar Accepted)
- 切换原因：用户明确表示 1.85 的关键 K 线外框效果“很好”，要求更新 `SESSION_LOG.md` 并切换 Session。关键 K 线功能的捕获、持久化、恢复和像素级显示阶段已经完成并通过用户目视验收，适合冻结后进入下一主题。
- 最终视觉方案：不再使用会产生半周期映射偏移的原生 `OBJ_RECTANGLE`；使用透明 `OBJ_BITMAP_LABEL + CCanvas`，由 `ChartTimePriceToXY()` 获取目标柱中心和 High/Low 像素，宽度依据相邻 K 线中心间距，2 px 金色边框随滚动/缩放重建。1.85 的最终尺寸为 `markerWidth=halfWidth*2-1`、`markerHeight=bottomY-topY-1`，右侧和底端内边线已与蜡烛边缘贴合。
- 正式数据语义保持冻结：`bar_time`、`confirm_time`、OHLC、方向、`bar_shift`、动作序列和原始高亮时间范围仍是档案真值；画布只负责当前视口显示，不反向改变 CSV 数据。每个案例只保留一根 `RELEASE_BAR`，重新标记会替换旧值。
- 实机验证：Experts 于 16:30:56 在 H1 确认 `EA INIT | ver=1.85`；用户随后切换 H4 并返回 H1，16:32:05 与 16:32:09 均再次记录 `EA INIT | ver=1.85`。关键 K 线在多根蜡烛上完成捕获、保存和 `UNDO` 测试，归档日志均为 `cases_saved=1 | anchors_saved=1 | key_bar_saved=1`，未发现本阶段 ERROR/WARN。
- 当前档案状态：用户在视觉测试后已通过 `UNDO` 清空最后一根测试关键 K 线，`opportunity_key_bars.csv` 当前为 0 行数据；这是干净测试状态，不得在新 Session 擅自恢复此前测试柱。`opportunity_anchors.csv` 仍有且仅有 S1–S5 五个正式结构点，`opportunity_cases.csv` 为 1 行且 `pivot_count=5`。
- 当前代码/构建：正式 EA 版本为 1.85，源码 4605 行、括号 412/412、CP936 严格往返通过；源码与 D: junction SHA256 为 `ED8B3586AF01A11EBCFFC16569D6C381DF34BDDE2B8D950911ED4FAFBEC9B399`，EX5 SHA256 为 `CEC21B1B4D2922B8F848A3FC978B2874BF3A895501A1B17FC5836D5745731D9B`，MetaEditor 编译结果为 `0 errors, 0 warnings`。
- 当前运行环境：MT5 PID 2560，通过固定快捷方式以 `/portable /config:"E:\Quantitative trading model\MT5_Integration\load_eurusd_2002.ini"` 启动；当前图表已返回 `EURUSD@_2002_FULL` H1，并运行 EA 1.85。项目与 MT5 仍通过 `D:\mt5\MQL5\Experts\MT5_EnergyTrading` junction 共用单一源码。
- 主要修改文件：`MT5_Integration/MQL5_Link/MT5_EnergyTrading.mq5`、`Data/Local_Data/opportunity_annotations/README.md`、`SESSION_LOG.md`。工作树还有大量用户既有修改和未跟踪文件，禁止 reset、清理或覆盖无关内容，`MT5_EnergyTrading.mq5.bak` 必须保留。
- 下一 Session 第一动作必须读取本文件，然后等待用户明确“继续”及下一标注工具方向。若继续此前讨论，候选主题是 MT5 原生起止线/结构线的统一扫描、归档与精确恢复；不要再次修改已验收的结构圆或关键 K 线外框，除非用户报告明确回归。
- 安全与编码约束继续有效：禁止自动操作 MT5 鼠标/键盘，禁止创建或运行 `ChartScreenShot` 临时脚本；用户负责视觉验收，助手只读取 Experts 与 CSV。EA 编辑继续使用“项目外临时 UTF-8 -> `apply_patch` -> 回写 CP936 -> 严格往返 -> MetaEditor 编译”的流程；`SESSION_LOG.md` 必须保持 UTF-8 BOM。

## Session Continuation (2026-08-07, EA 1.86 One-Click Native Drawing Extraction)
- 用户冻结本阶段目标为“案例提取尽可能简单”：结构点和关键 K 线继续使用 EA 自有标注；人工用 MT5 原生工具画出的通道线、平行结构线和蓝色区间线只保存原始几何与显示属性，本阶段不解释颜色、不划分三区角色，也不提取内部数学特征。
- `MT5_EnergyTrading.mq5` 已升级到 1.86，FULL 面板新增单击按钮 `提取结构`。一次点击执行 `扫描当前图表 -> 保存 CSV -> 回读验证 -> 创建 EA 托管副本 -> 删除人工原对象`；保存、回读或重绘任一环节失败时，不删除人工原对象，并在 Experts 输出 ERROR。
- 新增输入 `InpOpportunityDrawingsCsvPath`，默认值为 `opportunity_annotations\\opportunity_drawings.csv`。项目内已建立 `Data/Local_Data/opportunity_annotations/opportunity_drawings.csv`，当前仅有 31 列表头，尚未执行首次正式提取。
- 当前支持一至三个图表锚点的 MT5 原生绘图，包括水平线、垂直线、趋势线、角度趋势线、箭头线、周期线、等距/标准差/回归通道、安德鲁分叉线、Gann 常用工具、Fibonacci 常用线工具、矩形、三角形、椭圆、箭头和图表文本。EA 自有对象与屏幕控件会被排除；遇到其他不支持的人工分析对象时整次提取中止，避免生成不完整快照。
- 托管对象名称使用 `OPP_DRAW_<case>_D###`，保留对象类型、子窗口、一至三个时间/价格锚点、颜色、线型、线宽、前后景、填充、射线、角度、比例、标准差、可见周期、层级、文本和箭头属性。托管副本保持可选中、可编辑；编辑后再次点击 `提取结构` 会用当前全部受支持绘图覆盖该案例快照。
- EA 初始化时会读取绘图档案并自动重建托管绘图；`CLEAR CASE` 已同时接入绘图 CSV 清空和托管对象删除。`Data/Local_Data/opportunity_annotations/README.md` 已同步一键提取、失败保护、重启恢复和原始证据语义。
- 1.86 正式源码保持 CP936，项目源码与 `D:\\mt5` junction 源码一致；源码 SHA256 为 `170C503FDD1B932B7F5277CA91758BD92FD63120ED96C2658FC7B5488B4C4B84`，EX5 SHA256 为 `56FA999B458D1B691DFBC431537BAC123BFF37D5BDA7CA0ABD4FAEFFFB154690`。MetaEditor 于 2026-08-07 11:25 编译结果为 `0 errors, 0 warnings`。
- 当前 MT5 PID 13440 仍运行缓存的 EA 1.85；Experts 最后初始化记录为 `EA INIT | ver=1.85`。当前正式档案保留 S1-S5 和一根 `2002.01.23 17:00` 的 `RELEASE_BAR`，这些数据没有被 1.86 实现修改。
- 首次实机验收前不要完整关闭 MT5，因为当前人工原生线尚未归档。由用户在当前图表移除旧 EA 后重新挂载已编译的 1.86，先确认 Experts 出现 `EA INIT | ver=1.86`，再在 H1 单击一次 `提取结构`；助手不得代替用户操作界面。
- 首次提取验收门禁：Experts 依次包含 `extraction started`、每个 `object captured`、`archive loaded`、`redraw result`、`extraction result`，且无 ERROR/WARN；CSV 行数、对象类型与锚点正确；用户目视确认通道、平行结构线和蓝色区间线的位置、颜色、线型与线宽一致；随后完整重启 MT5，确认所有托管绘图从 CSV 自动恢复。

## Session Continuation (2026-08-07, EA 1.87 Three Opportunity Regions)
- 1.86 的原生绘图提取已完成实机验证：首次点击捕获 1 个等距通道和 4 条垂直区间线，`saved=1 | verified=5 | drawn=5 | originals_removed=5 | delete_failed=0`；重复点击只覆盖当前托管快照，不生成重复线。MT5 于 16:32 完整重启后从 CSV 成功读取并重绘 5/5 个对象，无 ERROR/WARN。
- 用户新增并冻结三区间语义：四条区间边界从左到右划分为 `积累前释放区`、`积累区`、`积累后释放区`。`MT5_EnergyTrading.mq5` 已升级到 1.87；提取流程不再通过颜色猜测，而是筛选恰好四条 `OBJ_VLINE`、按时间升序排序，并生成三个连续区间。
- 新增输入 `InpOpportunityRegionsCsvPath`，默认值为 `opportunity_annotations\\opportunity_regions.csv`；新增项目档案 `Data/Local_Data/opportunity_annotations/opportunity_regions.csv`。正式角色依次为 `PRE_ACCUMULATION_RELEASE`、`ACCUMULATION`、`POST_ACCUMULATION_RELEASE`，同时保存中文显示名、起止边界 drawing ID 和权威起止时间。
- 当前 1.86 绘图档案静态推导结果为：R1 `2002.01.09 00:00..2002.01.16 00:00`，R2 `2002.01.16 00:00..2002.01.23 19:00`，R3 `2002.01.23 19:00..2002.01.31 00:00`，与用户截图中的三个区域一致。
- 图面标签使用独立的 `OPP_REGION_<case>_R#_BOX/TEXT` 屏幕对象，不会被原生绘图扫描捕获。三个绿色边框标签显示在各自区间的水平中心、距图表底部固定位置；滚动和缩放时按保存的起止时间重新定位，区间不在当前视口或空间不足时隐藏而不修改档案。
- 1.87 首次加载现有 1.86 绘图档案时会自动生成并保存三区间，不要求用户重画或再次提取。后续每次点击 `提取结构` 都会同步覆盖绘图与区间快照；若垂直边界不是恰好四条，绘图仍保存，但区间档案清空并输出 WARN，禁止猜测错误角色。`CLEAR CASE` 已扩展为清空五个正式档案及区间标签。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步三区间角色、自动迁移、显示规则、失败语义和五档案清空行为。
- 1.87 正式源码为 5649 行、括号 498/498，CP936 严格字节往返通过；项目源码与 `D:\\mt5` junction 源码 SHA256 均为 `3AE2B46D7A9F032998078E95D495C2328E5582ACEB9C630DB52BC51AC264CF00`，EX5 SHA256 为 `714CAFD71373A1741FC3398BD63EFC519FAF9D8C24C94E510517F616C61E4606`。MetaEditor 于 18:28 编译结果为 `0 errors, 0 warnings`。
- 当前 MT5 PID 18912 仍运行缓存的 EA 1.86，`opportunity_regions.csv` 当前只有表头。用户重新挂载或重启 1.87 后，应在 Experts 看到 `regions derived`、`archive migration result`、`label result` 和初始化中的 `regions_loaded=1 | regions=3`；随后由用户目视确认三处中文标签位于正确区间且滚动/缩放后仍跟随。

## Session Continuation (2026-08-07, Accidental CLEAR CASE Recovery)
- 用户于 18:43:59 误触两次 `CLEAR CASE`；Experts 明确记录 `cases_cleared=1 | anchors_cleared=1 | key_bars_cleared=1 | drawings_cleared=1 | regions_cleared=1`，五份正式 CSV 一度只剩表头。
- 已依据清空前刚完成的逐文件内容核查恢复完整案例，并使用清空前 SHA256 做逐字节验收。恢复结果为：cases 1 行、anchors 5 行、key bars 1 行、drawings 5 行、regions 3 行；五份文件的字节数与 SHA256 均与清空前完全一致。
- 恢复哈希：cases `613909201DD0CFF0B6FA91ADEF49D6FC04EC9046497C5535821632D663053CFE`；anchors `354576C923D0A2BD9D7B18196BDFFB9D11B7480E0160901F7E359CB543D6578D`；key bars `C3F54A936CC6BFA81388776D4DB3E5520D317B72DFE79F4431EB9E6DFCEB588E`；drawings `7FBE1CC61B8467BFBF59BCC1E7983287C8DC5D77075E133867CFE35B2D509719`；regions `D27F0D190CABBDF8B8FCAF8FCF58EAF4A59EE13823BF0D48207EBFB1C7D006FC`。
- `D:\mt5\MQL5\Files\opportunity_annotations` Junction 下五份文件与项目目录哈希一致；三区中文字段已按原 CP936 编码恢复并严格解码为 `积累前释放区`、`积累区`、`积累后释放区`。
- 当前 EA 在执行 CLEAR 后仍持有空的内存状态。用户必须先通过切换周期后返回 H1或完整重启 MT5 触发档案回读，在此之前不要点击 `STRUCT`、`KEY BAR`、`提取结构`、`UNDO` 或 `CLEAR CASE`，否则可能再次覆盖刚恢复的 CSV。重载后应由助手读取 Experts，确认 `structures=5 | key_bar=1 | drawings=5 | regions=3` 和图形重建结果。

## Session Continuation (2026-08-07, EA 1.88 Non-Destructive Chart Clear)
- 用户要求按步骤实现案例选择功能，第一步范围冻结为修复原 `CLEAR CASE`：主面板按钮改名为 `清空图表`，单击一次只移除 MT5 当前图表上的案例标记，绝不删除或重写案例档案；年份、机会类型、同类型机会序号三个下拉框留到后续步骤。
- `MT5_EnergyTrading.mq5` 已升级到 1.88。新增 `opportunityChartViewVisible`、`ClearOpportunityChartView()` 和 `RestoreOpportunityChartView()`；旧破坏性 `ClearOpportunityAnnotation()` 与旧按钮 ID `OBJ_FULL_BTN_CLEAR_CASE` 已完全移除，主面板不再提供永久删除案例的入口，也不再要求五秒内二次确认。
- `清空图表` 会删除结构圆、关键 K 线外框、EA 托管绘图和三区标签，同时保留结构点数组、关键 K 线、四个结构线端点、原生绘图快照、三区数组、动作序列与案例状态。清空日志固定包含各类 `*_retained` 数量、`archive_touched=0` 和 `view_visible=0`。
- 清空后的滚动与缩放只维持空白案例视图，不会重新绘制标记。下一次明确点击任一标注操作会先恢复当前内存案例；重新挂载 EA、切换周期或完整重启会从五份 CSV 正常重建。`清空图表` 在非原始周期的只读图表上同样可用。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 1.88 语义：图表显示与档案持久化分离，清空路径不调用任何 CSV rewrite，永久删除不再暴露在主图表面板。
- 静态与构建验证完成：源码版本和 `EA_VERSION_STR` 均为 1.88；旧破坏性函数与旧按钮 ID 均为 0 处；源码 5676 行、大括号 504/504、CP936 严格字节往返通过。项目源码与 D: Junction 源码 SHA256 均为 `C6AAF823F952B4EC07F6F6BB4E5E84F3C8C8A7D7B06AE07437A138588205385D`。
- MetaEditor 于 19:08:14 编译正式 Junction 源码，结果为 `0 errors, 0 warnings`；新 EX5 为 247652 字节，项目路径与 Junction 路径 SHA256 均为 `6DA5E55BD191DEEB631EAE827A44C2BC1505FB85D659E05AFC4C05CAB04EE1B8`。项目外临时 UTF-8 源码和临时编译日志已经删除。
- 编译前后五份正式 CSV 均未改变：cases 1 行、anchors 5 行、key bars 1 行、drawings 5 行、regions 3 行；其 SHA256 仍与上一节列出的误删前恢复哈希逐一完全一致。
- 当前 MT5 PID 16472 于 18:51:55 启动，仍运行编译前缓存的 EA 1.87；Experts 最后一次 H1 初始化为 18:52:21 的 `EA INIT | ver=1.87`，且已正确回读 `5/1/5/3` 档案。用户必须完整关闭终端并从固定快捷方式重开，不能用单纯切换周期代替首次 1.88 加载；助手不得代替用户操作界面。
- 1.88 实机验收顺序：先确认 Experts 出现 `EA INIT | ver=1.88` 且恢复 `structures=5 | key_bar=1 | drawings=5 | regions=3`；单击一次 `清空图表`，预期日志为 `structures_retained=5 | key_bar_retained=1 | drawings_retained=5 | regions_retained=3 | archive_touched=0 | view_visible=0`；滚动和缩放后标记不得重现，五份 CSV 哈希必须不变；最后切换 H4 再返回 H1，确认档案重新读取并恢复 `5/1/5/3` 图面。
- 安全约束继续有效：禁止自动操作 MT5 鼠标/键盘，禁止创建或运行 `ChartScreenShot` 临时脚本；用户负责按钮与视觉验收，助手只读取 Experts 日志和五份 CSV。

## Session Continuation (2026-08-07, EA 1.89 Repeatable Structure Save)
- 用户将原 `提取结构` 的实际用途重新定义为可重复校正：复盘时可以拖动已有托管线，或删除过长/不准确的通道线后重新绘制，再用一个按钮把当前图表结构覆盖保存为该案例的最新正式版本。按钮文案因此改为 `保存结构`。
- `MT5_EnergyTrading.mq5` 已升级到 1.89。按钮 ID 改为 `OBJ_FULL_BTN_SAVE_STRUCTURE` / `btn_full_save_structure`，创建面板时主动删除旧 `btn_full_extract_structure`；处理函数和 Experts 日志统一改为 `SaveOpportunityStructureDrawings` 与 `structure save ...`，不再保留旧提取标识。
- `保存结构` 扫描当前图表上的全部受支持绘图，包括可编辑的 EA 托管副本和用户重新绘制的原生对象；保存成功后以当前快照覆盖本案例的 drawings/regions 行、重建稳定托管对象，并只在验证和重绘全部成功后删除非托管原对象，因此重复保存不生成重复档案行。
- 完整性门禁已收紧：当前快照必须包含恰好四条有效、时间互异的垂直边界，并成功推导三个连续区域；否则在任何 CSV 写入之前拒绝整次保存，旧绘图档案和旧三区档案均保持不变。1.87 的“仍保存绘图但清空旧三区”行为已废止。
- drawings 与 regions 两份 CSV 现在作为一个受保护的保存事务：覆盖前分别复制到带本次事务 ID 的临时备份；绘图写入、三区写入、绘图回读验证、三区回读验证或托管绘图重绘任一步失败，都会恢复两份原文件、旧内存数组和旧托管图面。若文件级恢复失败，备份会保留并在 Experts 输出路径与错误 ID，避免丢失唯一恢复材料。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 `保存结构` 的重复校正流程、四边界前置门禁和双档案回滚语义。结构点、关键 K 线与 1.88 的非破坏性 `清空图表` 逻辑未改变；1.89 完整包含 1.88 功能，因此无需再单独加载 1.88。
- 1.89 正式源码为 5857 行、大括号 520/520、CP936 严格字节往返通过；旧 `OBJ_FULL_BTN_EXTRACT_STRUCTURE`、`ExtractOpportunityDrawings` 和按钮文字 `提取结构` 均为 0 处。项目源码与 D: Junction 源码 SHA256 均为 `03AA995CEA78FBE775822A92C825EFD5AEA85C82351E905D6865069AE6EBF224`。
- MetaEditor 于 19:25:12 编译正式 Junction 源码，结果为 `0 errors, 0 warnings`；新 EX5 为 255064 字节，项目路径与 Junction 路径 SHA256 均为 `3DB630E03B4B92F8A05734EF884D0A0762EF0648AE8584A606ACBF9FDE8D4DE6`。
- 本轮实现和编译没有运行保存按钮，五份正式 CSV 仍保持误删前恢复状态与哈希：cases 1 行、anchors 5 行、key bars 1 行、drawings 5 行、regions 3 行；当前目录没有遗留 `.save_structure_*.bak` 事务文件。
- 当前 MT5 仍为 PID 16472，并在 19:12:48 的最近一次 H1 初始化继续记录 `EA INIT | ver=1.87`；周期切换没有加载新 EX5。用户必须完整关闭终端并从固定快捷方式重开，先由助手读取 Experts 确认 `EA INIT | ver=1.89`、档案 `5/1/5/3` 和两个中文按钮，再进行任何保存或清空操作。
- 1.89 保存验收：用户先轻微缩短或移动一条现有通道线，再单击一次 `保存结构`；Experts 应依次出现 `structure save started`、5 个 `object captured`、`regions derived`、两份 `archive loaded`、`redraw result`、`structure save result`，最终包含 `saved=1 | verified=5 | drawn=5 | regions=3 | archive_replaced=1 | delete_failed=0` 且无 ERROR。保存后 drawings/regions 哈希会因校正几何与更新时间而合理变化，cases/anchors/key bars 必须保持原哈希；完整重启后校正线与三区应从新档案精确恢复。
- 安全约束继续有效：助手不得自动操作 MT5 鼠标/键盘，不得创建或运行 `ChartScreenShot` 临时脚本；用户负责线条调整、按钮和视觉验收，助手读取 Experts、五份 CSV 及事务备份状态。

## Session Continuation (2026-08-07, EA 1.90 Structure Save Feedback)
- 用户在 19:42:29 使用 1.89 再次完成正式 `保存结构`；Experts 记录 5 个对象捕获、三区推导、两份档案回读、5/5 重绘和 `saved=1 | verified=5 | drawn=5 | regions=3 | archive_replaced=1 | delete_failed=0`。因此 drawings/regions 的新内容是用户校正后的正式基线，不得恢复为误删前的旧版本。
- 当前五份正式档案基线为：cases 1 行，SHA256 `613909201DD0CFF0B6FA91ADEF49D6FC04EC9046497C5535821632D663053CFE`；anchors 5 行，`354576C923D0A2BD9D7B18196BDFFB9D11B7480E0160901F7E359CB543D6578D`；key bars 1 行，`C3F54A936CC6BFA81388776D4DB3E5520D317B72DFE79F4431EB9E6DFCEB588E`；drawings 5 行，`56D3243F5FA40CA174EAB44256CAE11990B236CED7B5CC0A16C2B94987211C18`；regions 3 行，`45981997D047E1EA06455B9F9A1083F788974654565E74AB846E84CBD49E833A`。
- `MT5_EnergyTrading.mq5` 已升级到 1.90。`保存结构` 单击后先显示橙色 `保存中...`，成功显示绿色 `保存成功` 约 2 秒，失败显示红色 `保存失败` 约 3 秒；状态栏同步显示 `已保存 | 绘图 N | 区间 3` 或明确失败原因，不使用弹窗。
- 失败反馈覆盖只读周期、没有绘图、不支持对象、缺少四条有效区间边界、无法创建备份以及事务失败后的恢复状态。事务回滚函数现在返回两份档案是否均已恢复，用于准确区分 `已恢复旧档案` 与 `备份已保留`。若档案已经成功保存而仅非托管原对象清理失败，按钮仍显示保存成功，状态栏单独报告清理失败数量。
- FULL 实例现在启用 100ms 独立计时器，仅用于让成功/失败反馈到期后恢复默认按钮。`OnTimer()` 在 FULL 模式刷新反馈后立即返回，绝不连接 Python pipe；`OnDeinit()` 对 FULL 和 replay 两种实例都关闭计时器。保存按钮不再调用含 `Sleep(70)` 的通用点击闪烁。
- 正式源码继续保持 CP936，临时 UTF-8 与正式源码文本一致，CP936 严格字节往返通过，`MT5_EnergyTrading.mq5.bak` 保留。项目源码与 D: Junction 源码 SHA256 均为 `E7FD10FFECC372833D2300A2D7147BA9DF51149D680C1320294BA519E641F43C`。
- MetaEditor 于 19:52:53 编译正式 Junction 源码，结果为 `0 errors, 0 warnings`；新 EX5 为 256904 字节，项目路径与 Junction 路径 SHA256 均为 `2CA5813D8154B325D2410783BD83073DB4283091704EEB52214A801E05B05898`。编译前后五份 CSV 行数与上述哈希完全不变，目录中无 `.save_structure_*.bak` 遗留。
- 当前 MT5 PID 3544 仍加载编译前缓存的 EA 1.89；1.90 尚未实机加载。用户需要完整关闭 MT5 并从固定快捷方式重开，助手先读取 Experts 确认 `EA INIT | ver=1.90` 和档案 `5/1/5/3`，再由用户点击 `保存结构` 目视验收三个按钮状态及状态栏反馈。助手不得代替用户操作界面。
- 1.90 实机验收应先验证正常保存：按钮依次显示保存中和保存成功，状态栏为 `已保存 | 绘图 5 | 区间 3`，约 2 秒后恢复默认。失败路径可切换到 H4 后点击一次，预期红色失败与 `保存失败 | 只读周期`，约 3 秒后恢复；不需要破坏当前四条边界或制造文件错误。验收前后五份 CSV 必须保持当前基线，除非用户再次主动调整绘图并正式保存。

## Session Continuation (2026-08-07, EA 1.90 Runtime Accepted)
- MT5 于 19:58:05 实机加载 `EA INIT | ver=1.90`，初始化正确回读 structures=5、key_bar=1、drawings=5、regions=3。用户确认 `保存结构` 成功反馈符合预期，本阶段正式通过并可冻结。
- 用户于 19:58:08 和 19:58:16 两次点击 `保存结构`，Experts 两次均记录 `saved=1 | verified=5 | drawn=5 | regions=3 | archive_replaced=1 | delete_failed=0`，没有保存或回滚错误。
- 最后一次保存只更新 drawings/regions 的 `updated_at`，当前正式数据仍为 1/5/1/5/3 行。最新 SHA256：cases `613909201DD0CFF0B6FA91ADEF49D6FC04EC9046497C5535821632D663053CFE`；anchors `354576C923D0A2BD9D7B18196BDFFB9D11B7480E0160901F7E359CB543D6578D`；key bars `C3F54A936CC6BFA81388776D4DB3E5520D317B72DFE79F4431EB9E6DFCEB588E`；drawings `A5DDE452D41AF6274ACAA4B983681AD21B9F4C6F980DD86436D230E5C48EA1BD`；regions `1DD047088CF8B8F4CD00BD4CC63FCC59D76124BB99177B4C3B8F86CBDDBB6218`。
- 下一阶段候选为三个级联案例下拉框：年份、该年份内的机会类型、该年份与类型下按机会起始时间排序的案例。实现前必须先把当前活动案例 ID/type 从固定 input 解耦，并确保案例切换只读档案和重绘，不触发当前案例保存或覆盖。

## Session Continuation (2026-08-07, EA 1.91 Unified Case List and Read-Only Reproduction)
- 用户确认先实现第一阶段统一“案例列表”下拉框，用当前唯一案例验证五份 CSV 能否精确复现；案例增多后再拆成年份、机会类型、同类型机会三个级联下拉框。
- `MT5_EnergyTrading.mq5` 已升级到 1.91。启动输入 `InpAnnotationCaseId/InpAnnotationCaseType` 现在只提供默认案例；运行时使用 `opportunityActiveCaseId/opportunityActiveCaseType`，全部新保存行通过活动案例 getter 取 ID/type，不再固定绑定启动 input。
- FULL 面板高度由 122 增至 154，状态栏下新增统一案例按钮。当前目录项显示为 `案例 | 2002 | 上升通道 | 机会01 | 完整`；单击展开动态 `OBJ_BUTTON` 选项，选择当前同一案例也会强制重新读取档案，用于复现验收。点击空白或其他按钮会关闭菜单，菜单对象不参与 `保存结构` 扫描。
- 案例目录以 `opportunity_cases.csv` 为主记录，只读扫描 anchors、key bars、drawings、regions 四份档案计算真实数量。年份优先取 R1 起点，无完整三区时回退 `formation_start`；同一年同类型按机会起始时间排序。`完整` 当前只表示 structures>0、key bars>0、drawings>0、regions==3，不表示交易规则已经成立。
- 案例切换严格不保存、不迁移、不重写 CSV：退出标注/编辑状态，按旧活动案例前缀删除旧图面，切换运行时 ID/type，Reset 内存并只读五档案，逐项验证 S/L/K/D/region 实载数量与目录一致，按 R1-R3 时间中心定位图表，再重绘结构、关键 K 线、托管绘图和三区标签。所有切换日志固定包含 `archive_touched=0`。
- 切换中的数量校验、图表定位或托管绘图重建任一步失败，都会删除目标案例的部分图面，恢复旧活动 ID/type，并从旧案例五档案重新只读加载、定位和重绘。成功状态栏显示 `案例已加载 | S 5 | K 1 | D 5 | 区间 3`；失败会明确显示是否已恢复原案例。现有 `InitializeOpportunityAnnotation()` 仍仅用于 EA 启动，因此旧三区 migration 写盘路径不会被案例切换调用。
- `Data/Local_Data/opportunity_annotations/README.md` 已补充统一案例列表、完整性含义、同案例强制重载、只读计数验证和失败回滚语义。
- 1.91 正式源码按 `Get-Content` 计为 6617 行、大括号 580/580，CP936 严格字节往返通过；`MT5_EnergyTrading.mq5.bak` 未改变。项目源码与 `D:\\mt5` Junction 源码 SHA256 均为 `9CCCAAE3923ABB62B8BF2EAEB2A72480089D74A2A07849CC40A6010B648CF2DC`。
- MetaEditor 于 20:26:42 编译正式 Junction 源码，结果为 `0 errors, 0 warnings`；新 EX5 为 285452 字节，项目路径与 Junction 路径 SHA256 均为 `14BC84680DE53528E1C56C8A9367DBD786DA6C9996B6AAA0012FF3DF9E5D8A52`。
- 实现、文档和编译前后五份正式 CSV 完全不变，仍为 cases/anchors/key bars/drawings/regions = 1/5/1/5/3 行。SHA256 继续为 cases `613909201DD0CFF0B6FA91ADEF49D6FC04EC9046497C5535821632D663053CFE`；anchors `354576C923D0A2BD9D7B18196BDFFB9D11B7480E0160901F7E359CB543D6578D`；key bars `C3F54A936CC6BFA81388776D4DB3E5520D317B72DFE79F4431EB9E6DFCEB588E`；drawings `A5DDE452D41AF6274ACAA4B983681AD21B9F4C6F980DD86436D230E5C48EA1BD`；regions `1DD047088CF8B8F4CD00BD4CC63FCC59D76124BB99177B4C3B8F86CBDDBB6218`。目录中无 `.save_structure_*.bak` 遗留。
- 当前 MT5 PID 12172 仍运行 19:58:05 加载的 EA 1.90；助手没有自动重启或操作界面。用户需完整关闭 MT5 并从固定快捷方式重开，先确认 Experts 出现 `EA INIT | ver=1.91`、`[EA|FULL|CASE] INFO catalog entry ... structures=5 ... key_bars=1 ... drawings=5 ... regions=3 ... complete=1`，再点击案例按钮并选择唯一选项。
- 1.91 实机验收门禁：按钮文字和唯一选项均为 `案例 | 2002 | 上升通道 | 机会01 | 完整`；选择后 Experts 依次出现 `switch started`、五档案加载、`read-only archive validation ... verified=1`、`chart focus ... navigated=1`、`case redraw ... drawings=5/5`、`switch result ... loaded=1 ... archive_touched=0`；状态栏短暂显示 `案例已加载 | S 5 | K 1 | D 5 | 区间 3`；用户目视确认结构点、关键 K 线、通道/四条区间线和三个区域标签全部精确恢复；最后再次核对五份 CSV 哈希不变。
- 安全约束继续有效：禁止助手自动操作 MT5 鼠标/键盘，禁止创建或运行 `ChartScreenShot` 临时脚本；用户负责下拉框和图面视觉验收，助手只读取 Experts 与五份 CSV。

## Session Continuation (2026-08-09, EA 1.92 Case Menu Click-Bubble Fix)
- 用户实机反馈：先点击 `清空图表`，再点击 `案例 | 2002 | 上升通道 | 机会01 | 完整` 后视觉上没有任何反应。2026-08-09 Experts 证明 1.91 已正常加载，`清空图表` 于 10:11:18 保留 5/1/5/3 内存数据且 `archive_touched=0`；案例按钮于 10:11:19 正常进入，目录也成功读取 `ready=1 | cases=1 | complete=1`，因此问题与档案或按钮命中无关。
- 根因已定位为 MT5 事件冒泡：案例选择器的 `CHARTEVENT_OBJECT_CLICK` 创建下拉选项后，同一次鼠标操作继续产生 `CHARTEVENT_CLICK`；旧代码把它当作“点击图表空白”并立即调用 `CloseOpportunityCaseMenu()`，选项在用户看见前就被删除。日志中连续点击选择器只重复 `catalog loaded`、从未出现 option 对象点击，和该路径完全一致。
- `MT5_EnergyTrading.mq5` 已升级到 1.92。新增 `OPPORTUNITY_CASE_MENU_CLICK_GUARD_MS=250` 和 `opportunityCaseMenuOpenedTick`；菜单打开后的 250 ms 内只忽略由选择器自身冒泡出来的 chart click，之后用户真正点击图表空白仍会正常关闭菜单。点击其他按钮、再次点击选择器关闭菜单、点击动态案例选项执行切换的原语义不变。
- 新增 Experts 可观测日志：展开时 `menu opened | options=1`；同次冒泡被拦截时 `chart click bubble ignored`；点击动态选项时 `option selected | index=0`；主动关闭时记录对应 `menu closed` 原因。案例切换仍严格走 1.91 的五档案只读验证、定位、重绘和失败回滚路径，继续保证 `archive_touched=0`。
- 1.92 正式源码按 `Get-Content` 计为 6634 行、大括号 581/581，CP936 严格往返通过；项目与 `D:\\mt5` Junction 源码 SHA256 均为 `DFD0CE6AD8C3524C43C0C4C20F0DE4ADDDF2F4989DEA66DB3462866247E34998`，原 `.mq5.bak` 哈希保持 `1A03D0738F555045C61BEB9BFD4CAD0925CF76B59F386CA2B0BD23CB69629D2A`。
- MetaEditor 于 2026-08-09 10:15:20 编译正式 Junction 源码，结果为 `0 errors, 0 warnings`；新 EX5 为 285456 字节，项目与 Junction EX5 SHA256 均为 `930EDC40620FDEBBD491F16C3043A56E8DDD45D579345E2976BE2000D57CC8BF`。
- 修复和编译前后五份正式 CSV 仍为 cases/anchors/key bars/drawings/regions = 1/5/1/5/3 行，哈希全部保持 1.90/1.91 基线：cases `613909201DD0CFF0B6FA91ADEF49D6FC04EC9046497C5535821632D663053CFE`；anchors `354576C923D0A2BD9D7B18196BDFFB9D11B7480E0160901F7E359CB543D6578D`；key bars `C3F54A936CC6BFA81388776D4DB3E5520D317B72DFE79F4431EB9E6DFCEB588E`；drawings `A5DDE452D41AF6274ACAA4B983681AD21B9F4C6F980DD86436D230E5C48EA1BD`；regions `1DD047088CF8B8F4CD00BD4CC63FCC59D76124BB99177B4C3B8F86CBDDBB6218`，无 `.save_structure_*.bak` 遗留。
- 当前 MT5 PID 15080 仍运行已加载的 EA 1.91；编译不会热替换运行实例，助手没有自动重启或操作界面。用户需完整关闭 MT5 并从固定快捷方式重开，确认 `EA INIT | ver=1.92` 后再次执行：`清空图表` -> 点击绿色案例选择器 -> 确认其下方出现唯一动态选项 -> 点击该选项。
- 1.92 实机验收日志应依次出现 `menu opened | options=1`、`chart click bubble ignored`、`option selected | index=0`、`switch started`、`read-only archive validation ... verified=1`、`chart focus ... navigated=1`、`case redraw ... drawings=5/5`、`switch result ... loaded=1 ... archive_touched=0`；用户目视确认 5 个结构点、1 根关键 K 线、5 个托管绘图和 3 个区间标签恢复。验收后助手再核对 Experts 与五份 CSV 哈希。

## Final Session Handoff (2026-08-09, EA 1.92 Runtime Accepted)
- EA 1.92 已于 2026-08-09 10:17:43 在 `EURUSD@_2002_FULL,H1` 实机加载，当前 MT5 PID 为 13024。此前 1.92 章节中“当前仍运行 1.91、待重启验收”的描述已经过期，以本节最新状态为准。
- 点击冒泡修复已通过多轮真实按钮流程。10:18、10:37 和 12:23 均记录 `menu opened | options=1`，紧接 `chart click bubble ignored | elapsed_ms=0 | guard_ms=250`，证明选择器自身的 chart-click 冒泡被稳定拦截；随后动态对象 `btn_full_case_option_0` 正常产生 `option selected | index=0`。
- 12:23 的最终验收流程为：先 `清空图表`，日志确认 structures/key bar/drawings/regions 仍保留 5/1/5/3 且 `archive_touched=0 | view_visible=0`；再展开案例菜单并点击唯一选项，执行同案例 `force_reload=1`。
- 最终只读复现结果全部通过：anchors/key bar/drawings/regions 档案分别加载成功；数量校验为 structures `5/5`、lines `0/0`、key bars `1/1`、drawings `5/5`、regions `3/3`、`verified=1`；图表定位到 R1-R3 中心 `2002.01.20 00:00`，`navigated=1 | err=0`；托管绘图重建 `5/5`，三区标签 `3/3`，最终 `loaded=1 | focused=1 | redrawn=1 | archive_touched=0`。
- 五份正式 CSV 在最终实机验收后仍为 cases/anchors/key bars/drawings/regions = 1/5/1/5/3 行，哈希完全不变：cases `613909201DD0CFF0B6FA91ADEF49D6FC04EC9046497C5535821632D663053CFE`；anchors `354576C923D0A2BD9D7B18196BDFFB9D11B7480E0160901F7E359CB543D6578D`；key bars `C3F54A936CC6BFA81388776D4DB3E5520D317B72DFE79F4431EB9E6DFCEB588E`；drawings `A5DDE452D41AF6274ACAA4B983681AD21B9F4C6F980DD86436D230E5C48EA1BD`；regions `1DD047088CF8B8F4CD00BD4CC63FCC59D76124BB99177B4C3B8F86CBDDBB6218`；事务备份数量为 0。
- 当前正式构建保持不变：源码 SHA256 `DFD0CE6AD8C3524C43C0C4C20F0DE4ADDDF2F4989DEA66DB3462866247E34998`；EX5 285456 字节，SHA256 `930EDC40620FDEBBD491F16C3043A56E8DDD45D579345E2976BE2000D57CC8BF`；正式编译结果 `0 errors, 0 warnings`。
- 1.92 统一案例列表、清空后恢复、同案例强制只读重载、数量验证、定位、重绘及失败回滚功能在日志层面已经正式通过，可冻结。用户本轮没有单独用文字确认最终视觉细节；若下一 Session 需要绝对视觉闭环，先简短确认图上 5 个结构点、1 根关键 K 线、5 个托管绘图和 3 个区间标签是否与原案例一致，不需要重复修改代码。
- 下一 Session 的第一步仍必须读取本文件。若用户确认视觉无误，下一功能阶段可直接在现有 `opportunityCaseCatalog` 和 `SwitchOpportunityCase()` 基础上，将统一案例列表拆为三个级联下拉框：年份 -> 机会类型 -> 该年该类型按起始时间排序的机会。不得重做已经验收的五档案只读加载器，也不得改变 `清空图表` 的非破坏性语义。
- 安全约束继续有效：禁止助手自动操作 MT5 鼠标/键盘，禁止创建或运行 `ChartScreenShot`；正式案例数据只允许通过用户明确触发的标注/保存操作更新，案例选择必须继续保持 `archive_touched=0`。

## Session Continuation (2026-08-09, EA 1.93 Cascading Case Selector)
- 在已冻结的 1.92 五档案只读加载器和 `SwitchOpportunityCase()` 基础上完成三级案例选择器：`YEAR -> TYPE -> CASE`。点击主案例按钮先展示去重年份；选择年份后只展示该年份的机会类型；选择类型后只展示该年份和类型下按既有 `sortTime/typeSequence` 排序的案例。
- 新增独立的年份、类型、案例动态对象前缀，以及当前菜单层级、年份、类型和最终 catalog index 映射。`BACK | YEAR` 与 `BACK | TYPE` 只返回上一筛选层，不加载案例、不保存档案；最终案例按钮仍直接调用原 `SwitchOpportunityCase()`，因此五档案数量校验、图表定位、托管绘图/三区重绘、失败回滚和 `archive_touched=0` 语义没有复制或改变。
- 1.92 的 250 ms chart-click 冒泡保护已覆盖每次层级切换：每次创建下一层菜单都会刷新 opened tick，同一鼠标操作产生的 `CHARTEVENT_CLICK` 不会立即关闭新层。点击其他按钮、再次点击主选择器或稍后点击图表空白仍会关闭菜单。
- Experts 新增逐层日志：`menu opened | level=YEAR`、`year selected`、`menu opened | level=TYPE`、`type selected`、`menu opened | level=CASE`；最终仍记录 `option selected`、`switch started`、只读验证、定位、重绘和 `switch result ... archive_touched=0`。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 1.93 三级只读选择流程和 BACK 语义。正式源码版本已升级为 1.93。
- 1.93 正式源码为 6752 行、276820 字节、大括号 588/588，CP936 严格字节往返通过。项目源码与 `D:\\mt5` Junction 源码一致，SHA256 为 `087BD1AD0A198B11BB108FE1D78DA9C3BC2A1292223B2389D0C5515C8EEA38DC`。
- MetaEditor 最终编译结果为 `0 errors, 0 warnings`；EX5 为 291330 字节，项目路径与 Junction 路径 SHA256 均为 `8D00BBB0C87B0B6C283365DD43D860F85A49CE0C506E47A1E5DFF25E31610F1B`。
- 编译前后五份正式 CSV 保持 cases/anchors/key bars/drawings/regions = 1/5/1/5/3 行，哈希仍为：cases `613909201DD0CFF0B6FA91ADEF49D6FC04EC9046497C5535821632D663053CFE`；anchors `354576C923D0A2BD9D7B18196BDFFB9D11B7480E0160901F7E359CB543D6578D`；key bars `C3F54A936CC6BFA81388776D4DB3E5520D317B72DFE79F4431EB9E6DFCEB588E`；drawings `A5DDE452D41AF6274ACAA4B983681AD21B9F4C6F980DD86436D230E5C48EA1BD`；regions `1DD047088CF8B8F4CD00BD4CC63FCC59D76124BB99177B4C3B8F86CBDDBB6218`；事务备份数量为 0。
- 当前 MT5 PID 13024 仍是 10:17:43 加载的 EA 1.92；编译不会热替换运行实例，助手没有自动重启或操作 MT5。用户需完整关闭终端并从固定快捷方式重开，先确认 Experts 出现 `EA INIT | ver=1.93`，再依次点击主案例按钮、`YEAR | 2002`、`TYPE | 上升通道`、唯一案例项。
- 1.93 实机验收门禁：三层菜单每层均可见且不会被同次 click bubble 关闭；BACK 可逐层返回；选择最终案例后原 1.92 流程必须得到 `verified=1`、`navigated=1`、`drawings=5/5`、`regions=3/3`、`loaded=1`、`archive_touched=0`；用户目视确认 5 个结构点、1 根关键 K 线、5 个托管绘图和 3 个区间标签精确恢复。验收后再次核对五份 CSV 哈希不变。
- 安全约束继续有效：禁止助手自动操作 MT5 鼠标/键盘，禁止创建或运行 `ChartScreenShot`；正式案例数据只允许通过用户明确触发的标注/保存操作更新，三级筛选与案例切换必须始终只读。

## Session Continuation (2026-08-09, EA 1.94 Opportunity Type Guard)
- 用户确认 1.93 三级案例选择器视觉方向正确，并要求在完成一个机会标注时明确选择机会类型，同时在积累区上方直接显示类型文字，降低人工误标风险。
- `MT5_EnergyTrading.mq5` 已升级到 1.94。FULL 面板原 `UPPER` 与 `LOWER` 两个可见按钮已合并替换为 128 px 宽的 `类型 | ...` 选择器；旧上下轨锚点底层逻辑暂时保留但不再暴露在主面板。状态栏同时移除容易误导的 `U 0/2 | L 0/2` 计数。
- 类型菜单以两列六行显示 12 类标准机会：上矩、下矩、上升/下降三角形、上升/下降旗形、上升/下降通道、双顶、双底、头肩顶、头肩底。菜单沿用 250 ms click-bubble 防护；选择只更新内存并记录 `archive_touched=0`，已归档类型为绿色，待保存类型为橙色。
- 积累区 `R2` 上方新增独立前景标签：横向中心严格跟随 R2 时间中心，固定显示于图表上部，正式类型为红色双像素边框和文字，例如 `交易机会 | 上升通道`；新选择尚未保存时变为橙色并追加 `待保存`。滚动、缩放、案例切换和重绘都会重新定位；`清空图表` 会与其他托管标签一起隐藏，不触碰档案。
- 为避免下拉选择后结构拖动、UNDO、关键 K 线等自动保存提前造成类型错配，新增“显示类型”和“档案写入类型”分离：待保存期间普通标注写入继续使用原归档类型；只有用户明确点击 `保存结构` 时才进入类型提交状态。
- `保存结构` 的事务已从 drawings/regions 两档案扩展为类型变更时保护全部五份档案。保存前逐档验证当前案例的行数和 `case_type`；类型变更时备份 cases/anchors/key bars/drawings/regions，写入前三档新类型并保存后两档几何，回读验证五档类型及行数，再重绘。任一备份、写入、回读、类型校验或重绘失败都会恢复五份旧档案；选择保持橙色待保存，便于修正后重试。
- 案例切换只读验证新增五档 `case_type` 一致性门禁。切换成功会把选择器和图上标签恢复为目标案例的正式类型并清除待保存状态；失败回滚同时恢复原案例的已归档类型、待保存选择和图面。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 1.94 类型选择、图面标签、延迟提交和五档案事务语义。
- 1.94 正式源码为 7374 行、308095 字节、大括号 629/629，CP936 严格字节往返通过。项目源码与 `D:\\mt5` Junction 源码一致，SHA256 为 `2C4A0A9592AC189335A9D845C9FD190D2CA4A57F78E2ECFDD8ED5A360FE2D73E`。
- MetaEditor 最终编译结果为 `0 errors, 0 warnings`；EX5 为 312814 字节，项目路径与 Junction 路径 SHA256 均为 `9018B5D995C969353B1FE559B0B560646B37DE6A5437C52A054FA4724BBDB949`。
- 编译前后五份正式 CSV 保持 cases/anchors/key bars/drawings/regions = 1/5/1/5/3 行，哈希仍为：cases `613909201DD0CFF0B6FA91ADEF49D6FC04EC9046497C5535821632D663053CFE`；anchors `354576C923D0A2BD9D7B18196BDFFB9D11B7480E0160901F7E359CB543D6578D`；key bars `C3F54A936CC6BFA81388776D4DB3E5520D317B72DFE79F4431EB9E6DFCEB588E`；drawings `A5DDE452D41AF6274ACAA4B983681AD21B9F4C6F980DD86436D230E5C48EA1BD`；regions `1DD047088CF8B8F4CD00BD4CC63FCC59D76124BB99177B4C3B8F86CBDDBB6218`；事务备份数量为 0。
- 当前 MT5 PID 3468 于 12:40:29 加载的仍是 EA 1.93；1.94 编译不会热替换运行实例，助手没有自动重启或操作界面。用户需完整关闭终端并从固定快捷方式重开，先确认 Experts 出现 `EA INIT | ver=1.94` 和初始化五档类型验证均为 `verified=1`。
- 1.94 正常视觉验收：面板第二行下方应只见 `类型 | 上升通道`、`UNDO`、`清空图表`，不再出现 UPPER/LOWER；R2 上方应出现红框文字 `交易机会 | 上升通道`。点击类型按钮应显示 12 项；选择同一类型保持正式状态，选择其他类型后按钮和图上文字同时变橙并显示 `待保存`，且 Experts 明确 `archive_touched=0`。
- 为避免修改当前正式案例，首次实机只验收“选择当前相同的上升通道”和菜单显示，不选择其他类型、不点击保存。待视觉位置确认后，再决定是否用临时/新案例执行真实类型变更事务测试。安全约束继续有效：禁止助手自动操作 MT5 鼠标/键盘，禁止创建或运行 `ChartScreenShot`。

## Session Continuation (2026-08-09, EA 1.95 Case Catalog Summary)
- 用户确认绿色案例按钮应作为总案例导航入口，不应重复显示当前年份、类型、机会序号和完整性；当前机会类型已由图表上方的 1.94 标签承担。
- `MT5_EnergyTrading.mq5` 已升级到 1.95。关闭状态的绿色主按钮固定显示 `案例 | 共 N 个`，颜色只表达目录是否可用，不再因当前案例完整/缺少标注而变成不同颜色。
- 三级目录信息已重新分层：年份项显示 `年份 | YYYY | N 个`；类型项显示 `类型 | 类型名 | N 个`；最终案例项显示 `机会NN | Sx Ky Dz Rw | 标注完整/缺少标注`。原来容易被误解为交易机会判断错误的单独“完整/不完整”文字已从源码移除。
- `S/K/D/R` 分别是结构点、关键 K 线、托管绘图和机会区间的实际档案行数。“标注完整”仍只表示 structures>0、key bars>0、drawings>0、regions==3，不代表形态规则或交易结果已通过。
- BACK 按钮同步改为 `返回 | 年份` 和 `返回 | 类型`；年份、类型和返回项均显式使用 Microsoft YaHei。案例选择、五档案只读验证、图表定位、重绘和 `archive_touched=0` 行为没有改变。
- 1.95 正式源码为 7399 行、309116 字节、大括号 631/631，CP936 严格字节往返通过。项目源码与 `D:\\mt5` Junction 源码一致，SHA256 为 `331A526E14F3A93CBB8559FACDF9A0A6769BE40315283468AE4ADE6DF87FCB3C`。
- MetaEditor 最终编译结果为 `0 errors, 0 warnings`；EX5 为 314252 字节，项目与 Junction 路径 SHA256 均为 `BA070C3F5FD26B609C609FF21B441516D223E9585370AFB9AC447C20754DD8A7`。
- 1.94 实机期间，用户曾于 13:20:03–13:20:05 用 UNDO 删除 RELEASE_BAR、S5、S4、S3，目录因此正确显示 structures=2、key_bars=0、complete=0。随后用户于 13:23:20–13:23:34 重新捕获 S3、S4、S5 和 RELEASE_BAR，目录重新记录 structures=5、key_bars=1、drawings=5、regions=3、complete=1。新捕获坐标是用户最新正式标注，不得恢复为 1.94 启动前的旧 anchors/key bar 内容。
- 当前五份正式档案为 cases/anchors/key bars/drawings/regions = 1/5/1/5/3 行；最新 SHA256：cases `E7180257EA466C1C1E31D2E2FD320C71DACF59CC52B416F58A2E98049403C5C7`；anchors `44EB1F29905437CE91FF8011619E771BFDF5F9CE671DC2B5416E878880156C35`；key bars `F3A7D051E5C980FAE8EF591B012DF73F2E1915AA0660C7E16165FD1C982127FB`；drawings `225353F8AA68D54E8D5E62939D11EDA66F2E9184AD4BDF51932D436BD3AF2288`；regions `6837E9002CF45FF8D66B7CAF166F25B3A503BBA1FFD8D0CA8C7A75429E166B20`；事务备份数量为 0。
- 当前 MT5 PID 8944 仍是 13:19:41 加载的 EA 1.94；1.95 尚未实机加载。用户需完整关闭终端并从固定快捷方式重开，确认 `EA INIT | ver=1.95` 后检查：主按钮为 `案例 | 共 1 个`，年份为 `年份 | 2002 | 1 个`，类型为 `类型 | 上升通道 | 1 个`，最终项为 `机会01 | S5 K1 D5 R3 | 标注完整`。
- 本阶段只改导航展示，编译过程没有运行 MT5 按钮或写案例档案。安全约束继续有效：助手不得自动操作 MT5 鼠标/键盘，不得创建或运行 `ChartScreenShot`。

## Session Continuation (2026-08-09, EA 1.96 New Case Isolation)
- 用户实机发现 1.95 bug：点击 `清空图表` 后准备标注下一个机会，再点击 `KEY BAR` 会重现上一个上升通道。Experts 精确证明旧流程于 13:35–13:37 多次记录 `chart clear result ... structures_retained=5 | key_bar_retained=1 | drawings_retained=5 | regions_retained=3 | view_visible=0`，随后 `KEY BAR` 立即记录 `chart view restored ... case=EURUSD-2002-H1-CHANNEL-001`。根因是 1.88 的清空语义只隐藏图面并保留旧案例内存，任何标注按钮都会先恢复当前案例；这不是绘图残留或 CSV 加载错误。
- `MT5_EnergyTrading.mq5` 已升级到 1.96。主面板 `清空图表` 改为 `新建案例`：先只读刷新案例目录并生成无冲突的新 ID（示例 `EURUSD-2002-H1-CASE-002`，年份取当前可视区域中心），再删除旧案例托管图面、Reset 全部结构点/关键 K 线/绘图/三区内存，切换到新 ID。旧案例五档案不删除、不覆盖，仍可从案例目录只读恢复。
- 新草稿使用内部类型 `UNSELECTED`，面板显示 `类型 | 未选择`。在选择 12 类中的正式类型前，`STRUCT`、`KEY BAR`、`保存结构`、UNDO 和尺寸操作都会被拒绝并显示 `请先选择机会类型`；日志固定包含 `annotation rejected; opportunity type not selected ... archive_touched=0`。因此点击 KEY BAR 不再调用旧 `RestoreOpportunityChartView()`，也不会写入旧案例。
- 点击 `新建案例` 本身不创建 CSV 行，日志记录 `new draft started | previous=... | new=... | type=UNSELECTED | archive_touched=0`。选择类型后，首次结构点或关键 K 线自动保存会用新案例 ID 建立 cases/anchors/key bars 行，并只读刷新一次目录，使主按钮总数立即增加；正式 `保存结构` 成功后再次加载目录，补齐最终 drawings/regions 计数和完整性状态。
- 为支持新案例首次正式保存，类型保存预检在 `opportunityArchivedCaseType` 为空时使用当前已选择类型，而不是把空归档类型当作不支持类型；五档案备份、类型一致性校验和失败回滚继续沿用 1.94 事务。
- 旧 `ClearOpportunityChartView()`/`RestoreOpportunityChartView()` 底层函数暂时保留以兼容历史代码，但主面板不再调用清空隐藏路径；README 中 1.88 的旧工作流已明确标记为被 1.96 取代。
- 1.96 正式源码为 7510 行、313864 字节、大括号 636/636，CP936 严格字节往返通过。项目源码与 `D:\\mt5` Junction 源码一致，SHA256 为 `480D56443719A9785A68BC926915C2FC571E18A695D9B21939BB88C59695F484`。
- MetaEditor 最终编译结果为 `0 errors, 0 warnings`；EX5 为 318800 字节，项目与 Junction 路径 SHA256 均为 `39222E4F88676497B5A65DF838B561CD68FAC2035B8759996C3073F3C404B76D`。
- 当前 MT5 PID 22196 于 13:36:56 启动，仍加载 EA 1.95；1.96 尚未实机加载。用户在 1.95 下继续操作过正式案例，当前五份档案仍为 cases/anchors/key bars/drawings/regions = 1/5/1/5/3 行，13:41:05 最新 SHA256：cases `3A5A2A2034299A634AE277C0C9898DBA8297267C4F1362A9E7FB1BF59E5AAF8F`；anchors `6034A75AAC37E0AD9E8E8B594613A8961DAF34C4EE356AF1B826F267F4AC89AB`；key bars `61E59ED6CA5717A9F7F9074B9AFF296EF20C01A97D5F939C32069EBB57509C8E`；drawings `00F6552E9BF1025D0AAD7F66AAC11138576C129A9B70405E9084F1693F5634C5`；regions `640C29849FDD3B6DE78E03C8B615B5719536D384DB36AA768882A410C46C9984`；事务备份数量为 0。这些是用户最新操作后的正式基线，不得恢复到 1.95 章节的旧哈希。
- 1.96 首轮实机验收应避免创建正式第二案例数据：重启确认 `EA INIT | ver=1.96` 后点击 `新建案例`，确认旧通道消失、类型为未选择、案例总数仍为 1；直接点击 `KEY BAR`，应只看到“请先选择机会类型”，旧通道不得出现，五份 CSV 哈希必须保持上述基线。确认此隔离门禁后，再由用户选择真实类型并开始第二案例标注。
- 安全约束继续有效：助手不得自动操作 MT5 鼠标/键盘，不得创建或运行 `ChartScreenShot`；新案例坐标和类型只能由用户明确点击产生。

## Session Continuation (2026-08-09, EA 1.97 Timeframe Session Persistence)
- 用户在 1.96 实机确认新的周期切换 BUG：点击 `新建案例` 得到空白草稿后，只要切换 H1/M15/H4，EA 就会重新显示第一个上升通道案例。Experts 已精确复现：13:58:13 创建 `EURUSD-2002-H1-CASE-003 | type=UNSELECTED | archive_touched=0`；14:00:02 切到 M15 后新的 `OnInit()` 把活动案例恢复成固定 input `EURUSD-2002-H1-CHANNEL-001`，随后加载并重绘其 5/1/5/3 档案。根因不是图形残留，而是 1.96 的新草稿状态只在内存中，周期切换会销毁该 EA 实例。
- `MT5_EnergyTrading.mq5` 已升级到 1.97。新增不会被案例对象清理或 `DestroyFullControlPanel()` 删除的隐藏图表对象 `full_opportunity_session_state`，在其文本中保存 active case ID、当前类型、归档类型、类型待保存标志、原始 symbol 和原始 timeframe。该对象是 `OBJ_LABEL`，现有绘图扫描明确忽略屏幕标签，不会进入 drawings CSV。
- FULL `OnDeinit()` 现在先写入会话状态，再删除 EA 托管图面；下一次 FULL `OnInit()` 先设置 input 默认值，再优先恢复图表会话状态，然后读取案例目录。会话对象缺失或格式无效时才回退 input；无效对象会被丢弃并记录字段、版本和错误状态。
- 恢复的 active case 不在案例目录时，1.97 将其判定为尚未写档的草稿：保留同一个 case ID、`UNSELECTED` 或已选择但待保存的类型、原始 H1 周期和空白图面，明确跳过五档案加载、三区 migration 和类型验证，日志为 `draft initialized ... archives_skipped=1 | types_verified=skipped | archive_touched=0`。在 M15/H4 上该草稿保持只读，返回 H1 后恢复可编辑；第一个上升通道不会再被加载。
- 已归档或部分写档的活动案例仍走原有五档案加载、类型验证和重绘路径。若存在待保存类型，启动验证使用归档类型，不会把待保存显示类型误判为五档案不一致。会话状态在新建草稿、选择类型、标注自动保存、保存结构成功、案例切换成功/失败回滚、初始化和反初始化时同步；这些同步全部只写图表对象，固定记录 `archive_touched=0`。
- `SwitchOpportunityCase()` 的失败回滚同时补全了未入库草稿的 native symbol/timeframe/read-only 恢复，避免从空白草稿切换失败后丢失原始周期。`Data/Local_Data/opportunity_annotations/README.md` 已新增 1.97 周期会话语义。
- 1.97 正式源码为 7726 行、324766 字节、大括号 649/649，CP936 严格字节往返通过。项目路径与 `D:\\mt5` Junction 源码 SHA256 均为 `6021FE27DEAE5E487A37B5CF60210E80B88DE4058BE7657092C4E4D24E66EB0D`。
- MetaEditor 正式编译结果为 `0 errors, 0 warnings`（4917 ms）；EX5 为 330490 字节，项目与 Junction SHA256 均为 `AAA9B1B9739AD7217E0509DA8AD8C5C10010AC508E298842EAF37920ED3D980A`。
- 用户在 1.96 下已经完成第二个正式双底案例，当前五份档案不得恢复到 1.96 章节的单案例旧基线。正式数据为 cases/anchors/key bars/drawings/regions = 2/8/2/13/6 行；两个案例分别为 `CHANNEL-001 / ASCENDING_CHANNEL / 5/1/5/3` 与 `CASE-002 / DOUBLE_BOTTOM / 3/1/8/3`。最新 SHA256：cases `10D06FD8603EB49C158635C345D0D6E8FD1614D4EC754D594A95E23D025AB51B`；anchors `5A0192F8D2CE5D234A0599E25435F8ABBF07D541F1E63452FBDBD93F08C13386`；key bars `79A7BEA3C62307559AE23007E48D6DD9EE6B2B75AAF066E1D7173D22FB175F4E`；drawings `BE9A40C6650F02A8C12FF3DF1E881FF7B9C04FA50AC104711F7115040C3350BD`；regions `9F7DEB8FBD25C8DD30C5E349AA3C8C1E95FDA3A2352295611C57D6BC621F3BE2`；事务备份数量为 0。实现、文档和编译前后这些值完全不变。
- 当前 MT5 PID 18796 仍运行 EA 1.96；编译不会热替换。用户需完整关闭 MT5 并从固定快捷方式重开，确认 `EA INIT | ver=1.97`。首次 1.97 加载因尚无会话对象会正常回到 input 默认案例；随后在 H1 点击 `新建案例`，预期得到空白 `CASE-003` 和 `类型 | 未选择`，再切 H1 -> M15/H4 -> H1。每次应依次出现 `state saved | reason=deinit_3`、`state restored | case=...CASE-003`、`catalog loaded ... active=...CASE-003`、`draft initialized ... archives_skipped=1`；不得出现对 `CHANNEL-001` 的 archive loaded/redraw，图面始终空白，五份 CSV 哈希必须保持上述双案例基线。
- 安全约束继续有效：助手不得自动操作 MT5 鼠标/键盘，不得创建或运行 `ChartScreenShot`；用户负责周期切换与视觉确认，助手只读取 Experts 和五份正式 CSV。

## Session Continuation (2026-08-09, EA 1.98 Marker-Based Session Persistence)
- 用户实机确认 1.97 仍有同类 BUG：从案例目录成功切换到其他已归档交易案例后，再切换周期仍回到第一个上升通道。Experts 证明案例切换与保存端本身正确：17:18:37 和 17:18:47 均成功加载 `EURUSD-2002-H1-CASE-005` 并记录 `state saved | reason=case_switch_success`；17:18:41 周期切换前也记录 `deinit_3 | case=...CASE-005`。
- 1.97 的失败点已精确定位在恢复端：其 V1 状态写入一个隐藏 `OBJ_LABEL` 的 `OBJPROP_TEXT`，但 MT5 周期切换后读取到的字段数在 4、5、6 之间变化，而格式要求固定 7 段；日志连续出现 `invalid state discarded | fields=4/5/6`，随后才回退 input 默认 `CHANNEL-001`。因此不是案例切换、五档案加载或图面清理错误，而是 MT5 对该隐藏标签文本的跨周期持久化不可靠。
- `MT5_EnergyTrading.mq5` 已升级到 1.98，会话格式改为 V2 多标记对象，不再把任何状态写入或解析 `OBJPROP_TEXT`。七个隐藏 `OBJ_LABEL` 中，一个固定对象标记 V2 格式，另外六个对象分别通过对象名称后缀保存 active case ID、active type、archived type、type dirty、native symbol、native timeframe。字段前缀使用短名称，所有支持的案例 ID、类型和当前自定义品种均在 MT5 63 字符对象名限制内。
- V2 保存要求七个标记全部创建并配置成功后才报告成功；随后删除同前缀的旧字段标记和 1.97 的 legacy 文本对象。V2 恢复要求六个字段标记各且仅各一个，日志固定显示 `matches=1/1/1/1/1/1`；缺失、重复或非法字段会整体丢弃并记录各字段匹配数。标记对象不可见、不可选中、跨所有周期显示，现有 `保存结构` 扫描继续把 `OBJ_LABEL` 当作屏幕控件忽略，因此不会进入 drawings CSV。
- 1.97 的空白草稿跳过五档案、已归档案例验证加载、类型待保存状态、失败回滚 native timeframe 等语义全部保留；本轮只替换图表会话状态的物理持久化格式。所有 V2 日志继续固定 `archive_touched=0`。
- `Data/Local_Data/opportunity_annotations/README.md` 已补充 1.98 V2 标记格式和 V1 文本截断原因。正式源码为 7839 行、328556 字节、大括号 659/659，CP936 严格往返通过；项目路径与 `D:\\mt5` Junction 源码 SHA256 均为 `5A822F351EF21A90006DB1536D12F39675E83E7CACE275428E31F7070ED63FFB`。
- MetaEditor 正式编译结果为 `0 errors, 0 warnings`（5088 ms）；EX5 为 333920 字节，项目与 Junction SHA256 均为 `F8D466E127D4B56174614A119FFD08AA215F5CEEBD21C737DFD06CBBC4573A96`。
- 用户在本轮修复前已继续建立正式案例，当前案例目录共有 5 个：`CHANNEL-001 / ASCENDING_CHANNEL`、`CASE-005 / ASCENDING_CHANNEL`、`CASE-002 / DOUBLE_BOTTOM`、`CASE-003 / HEAD_AND_SHOULDERS_TOP`、`CASE-004 / HEAD_AND_SHOULDERS_TOP`。五份档案为 cases/anchors/key bars/drawings/regions = 5/26/5/43/15 行，最新 SHA256：cases `6CA2684E41E01310861B98861D864E46296F2C2062383F08CC3A7F0C6ECBBA80`；anchors `BC274BA6BB44D0ADDAB44D8C9FF5E5D105587781D8C444C4AF2FFF6247EB3B41`；key bars `10B55CB7480F89FB5C8C313AD9149B592D6DEEA71F8669EBCEB8595EB396F6E9`；drawings `71F38870E5E71981883CB94F3DCE7BD63D4BE5CF250A301DCE360325FD97E62E`；regions `F355124711E6ABFC5BDE756EA5B89AED7C2B3D5C94F64D59CAF41B9B95461A5B`；事务备份数量为 0。实现、编译和文档更新前后这些值完全不变，不得恢复到 1.97 章节的双案例旧基线。
- 当前 MT5 PID 5256 仍运行 EA 1.97。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=1.98`。首次 1.98 初始化会删除旧 V1 对象并正常回到 input 默认案例，日志预期 `marker state unavailable ... legacy_present=1 | discarded=1`，随后 `state saved ... format=V2 | markers=7`。接着由用户切换到任意非首案例（建议刚才测试的 `CASE-005`），再切 H1 -> H4 -> H1；每次 OnInit 必须出现 `state restored | format=V2 | case=...CASE-005 | matches=1/1/1/1/1/1`，案例目录 active、五档案加载和重绘都必须保持 CASE-005，不得加载 `CHANNEL-001`。
- 安全约束继续有效：助手不得自动操作 MT5 鼠标/键盘，不得创建或运行 `ChartScreenShot`；用户负责案例切换、周期切换和视觉确认，助手只读取 Experts 与五份正式 CSV。

## Session Continuation (2026-08-09, EA 1.98 Timeframe View Restoration)
- 用户加载 1.98 后继续发现独立视图 BUG：当前已经处于所选交易案例时，切换 H1/H4 等周期会让图表水平视图跳回全年行情起点，看起来像回到一开始。根因位于 FULL `OnInit()`：`InitializeOpportunityAnnotation()` 已恢复 V2 会话和当前案例后，初始化末尾仍无条件调用 `GoFullChartToStart(ChartID())`，覆盖了当前案例视图；`GO START` 按钮本身不是问题。
- 1.98 初始化导航已改为按会话状态分流。V2 恢复的活动案例存在于 `opportunityCaseCatalog` 时，调用既有 `FocusOpportunityCaseOnChart()`，按该案例 R1-R3 区间（缺失时回退 formation/ready）中心重新定位；日志记录 `restored session view initialized ... navigation=case_range`。这样周期变化后仍停留在当前交易案例，不再跳到全年历史起点。
- V2 恢复的是尚未入库空白草稿时，不执行任何自动导航，让 MT5 保持周期切换前的视图；日志记录 `restored draft view preserved ... navigation=unchanged`。只有首次启动或没有恢复到有效会话状态时才自动调用 `GoFullChartToStart()`，并记录 `initial chart view initialized ... navigation=history_start`。面板 `GO START` 的显式手动跳转行为保持不变。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步上述已归档案例、空白草稿、首次启动和手动 `GO START` 四种视图语义。本轮保持 EA 版本号 1.98，因为用户当前运行实例已经开始验收该版本，而 V2 会话格式没有再次变化。
- 正式源码为 7863 行、329700 字节、大括号 663/663，CP936 严格文本往返通过；项目路径与 `D:\\mt5` Junction 源码 SHA256 均为 `8E0234C89652508CFC2589E1FD3EBD410407B07A740188EC2282F8C812D350B8`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（5010 ms）；EX5 为 335954 字节，项目与 Junction SHA256 均为 `5889B41B61DEFFC4BC03F4C2DF9B37E14206976EDF8A53EE5CC25B1F549846B4`。
- 修复、编译和文档更新前后五份正式档案保持 cases/anchors/key bars/drawings/regions = 5/26/5/43/15 行，SHA256 仍为：cases `6CA2684E41E01310861B98861D864E46296F2C2062383F08CC3A7F0C6ECBBA80`；anchors `BC274BA6BB44D0ADDAB44D8C9FF5E5D105587781D8C444C4AF2FFF6247EB3B41`；key bars `10B55CB7480F89FB5C8C313AD9149B592D6DEEA71F8669EBCEB8595EB396F6E9`；drawings `71F38870E5E71981883CB94F3DCE7BD63D4BE5CF250A301DCE360325FD97E62E`；regions `F355124711E6ABFC5BDE756EA5B89AED7C2B3D5C94F64D59CAF41B9B95461A5B`；事务备份数量为 0。
- 当前 MT5 PID 19472 于 17:38:01 已加载上一份 17:25 编译的 1.98，并在 17:38-17:39 完成多次 H1/H4 初始化；本次视图修复 EX5 于 17:45:20 才生成，因此运行实例尚未包含该分流逻辑。用户需完整关闭并从固定快捷方式重开。因版本号仍为 1.98，除 `EA INIT | ver=1.98` 外还必须检查新日志：切换到 `CASE-005` 后执行 H1 -> H4 -> H1，每次应出现 `state restored | format=V2 | case=...CASE-005` 和 `restored session view initialized ... focused=1 | navigation=case_range`，图表应重新定位并停留在 CASE-005 区间；空白草稿切换周期应出现 `restored draft view preserved ... navigation=unchanged`，且不得执行自动 `GO START`。
- 安全约束继续有效：助手没有重启或操作 MT5 界面，没有创建或运行 `ChartScreenShot`；用户负责完整重启、案例选择、周期切换和视觉确认，助手只读取 Experts 与五份正式 CSV。

## Session Continuation (2026-08-09, EA 1.99 Drawing Segment Semantics)
- 用户冻结人工线段语义：紫色趋势线表示 `积累前释放路径`；红色结构线通常与 `S1、S2、S3...` 结构点配合出现。正式分析不得只保留颜色，也不得在未来训练阶段临时猜测含义；几何原始证据与人工约定语义需要同时进入档案。
- `MT5_EnergyTrading.mq5` 已升级到 1.99。`OpportunityDrawingState` 与 `opportunity_drawings.csv` 在原 31 列后追加七个字段：`semantic_role`、`path_id`、`segment_order`、`anchor_1_role`、`anchor_2_role`、`semantic_source`、`semantic_confirmed`。原 `updated_at` 仍保持第 31 列，便于兼容旧行。
- 紫色 `OBJ_TREND`（当前约定覆盖 `DarkViolet`、`MediumVioletRed`、`Purple`）保存为 `PRE_ACCUMULATION_RELEASE_PATH`，`path_id=R1_RELEASE_PATH`，按每段最早时间稳定生成从左到右的 `segment_order`。红色与橙红色 `OBJ_TREND` 保存为 `STRUCTURE_LINE`，`path_id=STRUCTURE_GRAPH`；颜色只是触发已冻结人工约定的输入，正式下游使用语义字段。
- 红色结构线的两个几何端点会分别尝试关联保存的结构圆。匹配使用每个 `S#` 已存时间范围与圆形价格范围，并允许半个结构范围的容差；匹配成功写入 `anchor_1_role/anchor_2_role`。颈线、延长线或没有直接落在结构圆附近的端点仍保留正式 `STRUCTURE_LINE`，对应节点字段留空，不强行误配，也不阻止保存。
- Experts 新增逐线与汇总日志：捕获日志包含颜色、语义和端点角色；随后输出 `line semantic` 的 role/path/order/anchor roles/source/confirmed，以及 `semantic summary` 的释放路径段数、结构线数和已关联节点端点数。托管对象 tooltip 同步显示正式语义。
- 旧 31 列绘图行继续可读。初始化和案例切换只在内存中依据约定补出语义，保持 `archive_touched=0`，不会后台改写正式 CSV。只有用户明确点击 `保存结构` 时，当前案例才通过原 drawings/regions 事务写出新 38 列 schema；因此现有紫线和红线无需重画，只需在加载 1.99 后对该案例保存一次。其他旧案例可在以后逐案例明确保存时升级。
- 只读回放已覆盖当前既有案例。典型结果包括：`CASE-002` 红线 `D001=S1/S2`、`D004=S2/S3`；`CASE-004` 多条红线依次关联 S1-S6，同时长结构线端点保持空；最新 `CASE-006` 当前几何预期为 1 段紫色释放路径、4 条红/橙红结构线，其中 4/8 个端点可明确关联结构点。该回放没有写入任何档案。
- 正式源码为 8094 行、338968 字节、大括号 687/687，CP936 严格往返通过；项目与 `D:\\mt5` Junction 源码 SHA256 均为 `83280F7BC68370D70E8577DDA3A71FC420B96C11D495B66E943B9236740DA3B2`。首次编译暴露 4 个计数器作用域错误并立即修正；最终 MetaEditor 编译结果为 `0 errors, 0 warnings`（5377 ms）。EX5 为 343040 字节，项目与 Junction SHA256 均为 `FC35DA4AD9B507F5BA33A38A8BA170839F8D6B781BB47585E68B781CD36A3A31`。
- 用户在实现前已新增第六个正式案例 `EURUSD-2002-H1-CASE-006 / DOUBLE_TOP`，不得恢复到上一节五案例基线。当前五份档案为 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行；SHA256：cases `5E75A72C6C1F73E2F020331366714B0F795A65AAA66C9FE4D8CE834E342D5450`；anchors `9873892F9D8217DCB6FDCA620CCB7686B8384F330DE6E61381B5360AAB71C16B`；key bars `B2C0910435DF3314C7B7961FAA57B38EB3742EE0E77DB8AC83AB0809076DB02F`；drawings `32CCF91945AE04E2B183BC23E21142269C2AEA15824A3FF65E4FC19AC4E3DBAB`；regions `B2249F51AF9A22AA6A46A1BEC7C2E27546C6BB6A7E0F71382A862E0C34D46F1B`；事务备份数量为 0。当前 drawings 仍是 31 列，因为运行实例尚未加载 1.99，代码实现和编译没有修改任何正式案例行。
- 当前 MT5 PID 5972 仍运行 EA 1.98。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=1.99`；切换到 `CASE-006` 后点击一次 `保存结构`。预期出现 `semantic summary ... pre_release_segments=1 | structure_lines=4 | linked_structure_anchors=4/8`（若用户在重启前继续调整线条，计数可随正式几何变化），最终保存必须仍为 `saved=1`、drawings/regions 回读和重绘成功。保存后 `opportunity_drawings.csv` 表头应为 38 列，CASE-006 每行具有语义字段；cases/anchors/key bars 不应变化，drawings/regions 因用户明确保存而合理更新。
- 安全约束继续有效：助手没有自动重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`；语义档案升级必须由用户明确点击 `保存结构` 触发。

## Session Continuation (2026-08-09, EA 2.00 DarkOrchid Release Path Fix)
- 用户在 1.99 实机保存第一个头肩顶案例 `EURUSD-2002-H1-CASE-003` 后发现紫色积累前释放线没有语义。CSV 与 Experts 精确确认：`D002` 的实际颜色为十进制 `13382297`、十六进制 `0xCC3299`，即 MT5 `DarkOrchid`；该行在 18:56:37 保存后 `semantic_role/path_id` 为空、`semantic_confirmed=0`，日志也记录 `pre_release_segments=0 | structure_lines=7`。其他七条红色结构线均正确保存，问题仅是紫色集合漏色，不是档案写入或事务失败。
- EA 已升级到 2.00，在 `IsOpportunityPreReleasePathColor()` 中加入 `clrDarkOrchid`。数值按 MT5 颜色编码核对为 `153 + 50*256 + 204*65536 = 13382297`，与 CASE-003 D002 完全一致；原 `DarkViolet`、`MediumVioletRed`、`Purple` 和红/橙红结构线规则均保持不变。
- 现有 CASE-003 D002 不需要重画。2.00 加载该 38 列行时，虽然保存字段为空，`FinalizeOpportunityDrawingSemantics()` 仍会根据 DarkOrchid 约定在内存中补为 `PRE_ACCUMULATION_RELEASE_PATH / R1_RELEASE_PATH / segment_order=1 / semantic_confirmed=1`；案例切换继续只读。用户再明确点击一次 `保存结构` 后，纠正后的语义才正式写回 D002。
- `Data/Local_Data/opportunity_annotations/README.md` 已把 DarkOrchid 纳入 1.99 紫色约定并增加 2.00 漏色修复说明。正式源码为 8095 行、339011 字节、大括号 687/687，CP936 严格往返通过；项目与 `D:\\mt5` Junction 源码 SHA256 均为 `9986DEA595E6191268EDA9112E1C9F45632E4435211B99168E8E2E96440799A3`。MetaEditor 最终编译为 `0 errors, 0 warnings`（5153 ms）；EX5 为 343158 字节，项目与 Junction SHA256 均为 `93FB98156748B9F4A0E279E166EF099EB0840F21562B25F2D41B5439C44F05A4`。
- 用户已在 1.99 下于 18:56:37 正式保存 CASE-003，drawings/regions 因该明确操作产生新的正式基线，不得恢复到 1.99 实现前哈希。当前五份档案保持 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行；SHA256：cases `5E75A72C6C1F73E2F020331366714B0F795A65AAA66C9FE4D8CE834E342D5450`；anchors `9873892F9D8217DCB6FDCA620CCB7686B8384F330DE6E61381B5360AAB71C16B`；key bars `B2C0910435DF3314C7B7961FAA57B38EB3742EE0E77DB8AC83AB0809076DB02F`；drawings `AD4E9240B983036D5639F43BFFB0FB8673D4706061900AD909993A11F9D3C7EC`；regions `0162D5A367472757684EAD7E6A24BBF84A18523680FDC5E6626B5B94E9BF2BA1`；事务备份数量为 0。2.00 实现和编译没有再次写案例档案。
- 当前 MT5 PID 15212 仍运行 EA 1.99。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.00`；切换 CASE-003 时加载日志应从 `pre_release_segments=0` 变为 `pre_release_segments=1`。随后点击一次 `保存结构`，预期 `line semantic | id=D002 | role=PRE_ACCUMULATION_RELEASE_PATH | path_id=R1_RELEASE_PATH | segment_order=1`，汇总为 `pre_release_segments=1 | structure_lines=7`，最终仍须 `saved=1`、12 个绘图与 3 个区间回读/重绘成功。保存后只需核对 D002 新语义和 drawings/regions 新哈希，cases/anchors/key bars 应保持不变。
- 安全约束继续有效：助手没有自动重启或操作 MT5 界面，也没有直接修补正式 CSV；修正后的档案写入继续由用户明确点击 `保存结构` 触发。

## Session Continuation (2026-08-09, EA 2.01 HSV Color Families and Case Label)
- 用户确认两项改动：紫色/红色人工趋势线不再依赖少数固定命名色值，而应容纳同一颜色家族的合理色差；图上原顶部 `交易机会 | 类型` 标签应移除，改为案例完整 R1-R3 范围左下角的单一 `短ID | 具体类型` 标签，例如 `CASE-003 | 头肩顶`，避免重复文字并让案例能快速对应正式档案。
- `MT5_EnergyTrading.mq5` 已升级到 2.01。新增 MT5 BGR 颜色到 HSV 的转换；紫色家族定义为 Hue `265–330°`、Saturation `>=0.35`、Value `>=0.25`，红色家族定义为 Hue `345–360°` 或 `0–25°`、Saturation `>=0.45`、Value `>=0.30`。`DarkViolet`、`DarkOrchid`、`MediumVioletRed`、`Purple`、`Red`、`OrangeRed` 均通过对应家族静态验证。
- 紫色家族 `OBJ_TREND` 继续得到 `PRE_ACCUMULATION_RELEASE_PATH / R1_RELEASE_PATH`，红色家族继续得到 `STRUCTURE_LINE / STRUCTURE_GRAPH`；新推导来源写为 `MANUAL_COLOR_FAMILY_CONVENTION`。原始 MT5 色值始终保留。范围外趋势线不阻止 `保存结构`，但 Experts 会记录原始色值、HSV 和 `semantic_role=UNCLASSIFIED` WARN；加载与保存汇总均增加 `unclassified_trend_lines`。
- 原顶部 `交易机会 | ...` 可见文字和旧 `CreateOpportunityTypeChartLabel` 已从正式源码移除。新 `CreateOpportunityCaseChartLabel()` 使用完整 R1 起点至 R3 终点确定案例范围，在三区标签上方、案例左侧绘制 `CASE-003 | 头肩顶`；待提交类型追加 `待保存`。完整案例 ID 和正式类型仍保留在 tooltip，绿色 `案例 | 共 N 个` 总导航按钮不变。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.01 HSV 阈值、范围外线段保留规则和左下角案例标签语义。旧 1.99/2.00 章节作为历史演进记录保留。
- 正式源码为 8177 行、345166 字节、大括号 691/691，CP936 严格往返通过；项目与 `D:\\mt5` Junction 源码 SHA256 均为 `270294AB2DEBD43B40741451C3CBD7C8BDA309867A4BDD2F30A43B6181FE47A6`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（5056 ms）；EX5 为 346050 字节，项目与 Junction SHA256 均为 `C901D060C0B613B0B2CCE991061EB7372B5309555C985835996FB9E25CC944AF`。
- 实现、文档和编译前后五份正式档案完全不变，仍为 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行；SHA256：cases `5E75A72C6C1F73E2F020331366714B0F795A65AAA66C9FE4D8CE834E342D5450`；anchors `9873892F9D8217DCB6FDCA620CCB7686B8384F330DE6E61381B5360AAB71C16B`；key bars `B2C0910435DF3314C7B7961FAA57B38EB3742EE0E77DB8AC83AB0809076DB02F`；drawings `AD4E9240B983036D5639F43BFFB0FB8673D4706061900AD909993A11F9D3C7EC`；regions `0162D5A367472757684EAD7E6A24BBF84A18523680FDC5E6626B5B94E9BF2BA1`；事务备份数量为 0。
- 当前 MT5 PID 11192 于 19:03:51 加载的仍是 EA 2.00；编译不会热替换。用户需完整关闭 MT5 并从固定快捷方式重开，确认 `EA INIT | ver=2.01`。视觉验收应确认顶部不再出现 `交易机会 | ...`，案例左下角在三区标签上方显示 `短ID | 类型`；切换 CASE-003 后加载汇总应为 `pre_release_segments=1`。若 CASE-003 D002 正式档案仍为空语义，仍由用户明确点击一次 `保存结构`，预期写入 `PRE_ACCUMULATION_RELEASE_PATH / R1_RELEASE_PATH / segment_order=1`，助手不得直接修补 CSV。
- 安全约束继续有效：助手没有自动重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`；正式档案更新仍只允许由用户明确触发的标注或保存操作完成。

## Session Continuation (2026-08-09, EA 2.02 Minimal Bottom Case Text)
- 用户实机加载 2.01 后确认 `CHANNEL-001 | 上升通道` 的内容正确，但红色描边框、红字和位于三区标签上方的显示方式不美观。用户在截图中明确标出新目标：第一条蓝色 R1 边界左侧、紧贴时间轴上方的低位区域，只显示一小串黑色粗体文字，不再显示任何外框。
- `MT5_EnergyTrading.mq5` 已升级到 2.02。案例标识仍为 `短ID | 具体类型`，例如 `CHANNEL-001 | 上升通道`；类型待提交时仍追加 `待保存`。`TYPE_BOX` 矩形创建路径已完全移除，并在刷新时主动删除 2.01 可能遗留的框对象。
- 新文字使用系统已确认安装的 `Microsoft YaHei UI Bold`、9 号、`clrBlack`。正常位置以第一条 R1 边界的屏幕 X 坐标为基准，文字右下锚点位于该边界左侧 14 px，底部距图表下缘 30 px，与用户截图红框对应；若 R1 左侧可用空间不足，则回退到当前视口左下边距 8 px。滚动、缩放、周期切换和案例切换仍通过既有刷新路径重新定位。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.02 的无框、小号黑色粗体和 R1 左侧低位定位规则。2.01 章节保留为用户本次视觉反馈对应的历史版本。
- 正式源码为 8142 行、343033 字节、大括号 690/690，CP936 严格往返通过；项目与 `D:\\mt5` Junction 源码 SHA256 均为 `D16FE947DBBCC36C13AD136E32CF1EE54E847F5C5A1AF5390E319E32AF22889D`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（5398 ms）；EX5 为 345124 字节，项目与 Junction SHA256 均为 `BB8A5209F5314519C048EB8540E83F056B8ADCCA4F08941B572D46BFBD4D34D0`。
- 实现、文档和编译前后五份正式档案仍保持 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行，SHA256 分别为 `5E75A72C6C1F73E2F020331366714B0F795A65AAA66C9FE4D8CE834E342D5450`、`9873892F9D8217DCB6FDCA620CCB7686B8384F330DE6E61381B5360AAB71C16B`、`B2C0910435DF3314C7B7961FAA57B38EB3742EE0E77DB8AC83AB0809076DB02F`、`AD4E9240B983036D5639F43BFFB0FB8673D4706061900AD909993A11F9D3C7EC`、`0162D5A367472757684EAD7E6A24BBF84A18523680FDC5E6626B5B94E9BF2BA1`；事务备份数量为 0。
- 当前 MT5 PID 21776 运行的仍是 EA 2.01，最近 H1 初始化为 21:03:11；编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.02`，随后目视验收文字是否位于第一条蓝线左侧、时间轴上方的红框位置，且只剩无框黑色粗体文字。
- 安全约束继续有效：助手没有自动操作 MT5 界面，没有创建或运行 `ChartScreenShot`，也没有改写任何正式案例 CSV。

## Session Continuation (2026-08-09, EA 2.03 R2-Centered Case View and Full ID)
- 用户在 2.02 实机截图中提出两项明确要求：每次从案例目录打开案例或因周期切换恢复案例时，应把结构积累区 `R2 / ACCUMULATION` 放到图表真正的正中间；左下角无框黑体案例文字应显示完整档案 ID，而不是 `CASE-006` 之类的短 ID。
- 旧 `FocusOpportunityCaseOnChart()` 在三区完整时使用整个 R1-R3 时间范围，并按两个时间戳的秒数算术中点定位。MT5 横轴实际按已有 K 线等距排列，周末和休市时间没有对应 K 线，因此时间中点不一定是两个边界在屏幕上的几何中点，这是积累结构发生视觉偏移的根因。
- `MT5_EnergyTrading.mq5` 已升级到 2.03。案例档案只读加载完成后，定位函数优先在已加载的 `opportunityRegions` 中查找角色为 `ACCUMULATION` 的 R2，分别用 `iBarShift()` 得到其起止边界 K 线索引，再以两个索引的整数中点作为目标柱。`ChartNavigate()` 继续把该目标柱放在可见 K 线数量的一半位置，因此 R2 在有周末/休市空档时仍按真实柱数居中。
- 若 R2 缺失或无效，定位才回退完整 R1-R3，再回退 formation/ready；错误路径会记录边界、两端 shift 和错误 ID。成功日志新增 `scope=accumulation_r2`、`boundary_shifts=start/end`、目标柱时间与最终 position，便于核对初始化恢复、案例切换和失败回滚三条路径是否使用同一居中规则。
- 左下角标签现直接使用完整 `OpportunityCaseId()`，例如 `EURUSD-2002-H1-CASE-006 | 双顶`；短 ID 辅助函数和 `short_id` 标签日志已移除，标签结果改记 `display_id=<完整ID>`。2.02 的无框、9 号黑色微软雅黑粗体、R1 左侧低位定位保持不变。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步完整 ID 与按 R2 边界 K 线索引居中的规则。正式源码为 8160 行、344053 字节、大括号 691/691，CP936 严格往返通过；项目与 `D:\\mt5` Junction 源码 SHA256 均为 `A0C8F6E9211F721491983825E2BC3704E4ABEB22ED4A09C62C5172E84DFDAF95`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（5457 ms）；EX5 为 345482 字节，项目与 Junction SHA256 均为 `B90E8DEB9112DDCFE1B7EF6E61F48B2BE84EC4E23A42BF457B7F8344F6C3DC98`。
- 实现、编译和文档更新前后五份正式档案仍为 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行，SHA256 继续为 `5E75A72C6C1F73E2F020331366714B0F795A65AAA66C9FE4D8CE834E342D5450`、`9873892F9D8217DCB6FDCA620CCB7686B8384F330DE6E61381B5360AAB71C16B`、`B2C0910435DF3314C7B7961FAA57B38EB3742EE0E77DB8AC83AB0809076DB02F`、`AD4E9240B983036D5639F43BFFB0FB8673D4706061900AD909993A11F9D3C7EC`、`0162D5A367472757684EAD7E6A24BBF84A18523680FDC5E6626B5B94E9BF2BA1`；事务备份数量为 0。
- 当前 MT5 PID 8364 于 21:10:21 加载的仍是 EA 2.02；编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.03`。随后打开任一案例，Experts 应出现 `chart focus ... scope=accumulation_r2 ... navigated=1 | err=0`；用户目视确认 R2 两条蓝色边界的柱数中点位于图表正中，左下角文字显示类似 `EURUSD-2002-H1-CASE-006 | 双顶` 的完整 ID。
- 安全约束继续有效：助手没有自动操作 MT5 界面，没有创建或运行 `ChartScreenShot`，没有改写任何正式案例 CSV。

## Session Continuation (2026-08-09, EA 2.04 R2-Derived Opportunity Level)
- 用户依据 CASE-005 截图纠正了一个关键概念：旧完整 ID `EURUSD-2002-H1-CASE-005` 中的 `H1` 是人工标注所用图表周期，不是交易机会周期；CASE-005 的真实积累区明显超过 7 天，不能在没有读取 R2 宽度时直接视为 H1 级别机会。
- `MT5_EnergyTrading.mq5` 已升级到 2.04。机会级别只使用正式 `opportunity_regions.csv` 中 `region_role=ACCUMULATION` 的 R2 起止时间计算真实日历跨度：`0 < duration <= 604800秒` 为 `H1`，`604800 < duration <= 2419200秒` 为 `H4`；超过 28 天返回 `UNCLASSIFIED` 并输出 WARN，不擅自扩展为 D1。
- 六个现有正式案例的只读静态回放结果为：`CHANNEL-001=7.792天/H4`、`CASE-002=6.958天/H1`、`CASE-003=6.625天/H1`、`CASE-004=8.417天/H4`、`CASE-005=18.875天/H4`、`CASE-006=7.208天/H4`。其中 CASE-005 的权威 R2 为 `2002.05.30 04:00..2002.06.18 01:00`，新显示编码为 `EURUSD-2002-H4-CASE-005`。
- 正式五档案之间继续使用不可变 `case_id` 关联，原 `timeframe=H1` 也继续表示标注图表周期。图面左下角和案例目录 tooltip 使用派生显示编码：把内部 ID 的第三段源周期替换为机会级别，例如内部 `EURUSD-2002-H1-CASE-005` 显示为 `EURUSD-2002-H4-CASE-005 | 上升通道`，避免误把源周期当作机会周期。
- `OpportunityCaseCatalogEntry` 新增 R2 起止、持续小时、`opportunityLevel` 和 `caseCode`。案例目录每次加载都从 regions 权威档案重新派生，因此旧案例无需后台迁移即可立即得到正确级别；目录项增加级别和持续天数，逐案例 Experts 日志增加内部 ID、显示编码、R2、持续小时和机会级别。2.03 的 R2 按 K 线索引居中继续保留，focus 日志同步输出显示编码与派生级别。
- `opportunity_cases.csv` 保持原 19 列索引不变，并在 `updated_at` 后追加 `opportunity_level`、`accumulation_start`、`accumulation_end`、`accumulation_duration_hours`、`case_code`。旧 19 列行继续兼容读取；初始化和案例切换只读派生，固定 `archive_touched=0`。只有用户下一次明确标注或点击 `保存结构` 时，活动案例才写成 24 列新 schema。
- `保存结构` 的受保护事务现始终备份 cases 元数据，并在 drawings/regions 写入和回读成功后重新写入当前案例级别；元数据写入失败会与 drawings/regions 一起回滚。类型发生变化时 anchors/key bars 仍加入同一事务；成功后清理所有备份。这样新案例首次保存即可得到基于刚保存 R2 的正确级别，而不会留下 `UNCLASSIFIED` 旧快照。
- “非标准”仍保持为独立人工标准性维度，不能混入自动 H1/H4 判定或替代上升通道等机会类型；本轮按用户最新明确要求先冻结真实周期判定与编码，尚未增加标准性按钮或改写正式档案。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.04 阈值、CASE-005 示例、不可变内部 ID、派生显示编码、24 列兼容 schema 和显式保存迁移语义。正式源码为 8363 行、354539 字节、大括号 706/706，CP936 严格往返通过；项目与 `D:\\mt5` Junction 源码 SHA256 均为 `F729EBEAE1EA4BEEC688CCAF659F2DB6CCEE1054AAF40B9EEA56D92FDF5775FA`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（5877 ms）；EX5 为 357194 字节，项目与 Junction SHA256 均为 `3E05877AFA6DFFCAEE822EA28107C5CAA355854BB44DCEA7871353EB16D10805`。
- 实现、编译和文档更新前后五份正式档案完全不变，仍为 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行；SHA256 继续为 `5E75A72C6C1F73E2F020331366714B0F795A65AAA66C9FE4D8CE834E342D5450`、`9873892F9D8217DCB6FDCA620CCB7686B8384F330DE6E61381B5360AAB71C16B`、`B2C0910435DF3314C7B7961FAA57B38EB3742EE0E77DB8AC83AB0809076DB02F`、`AD4E9240B983036D5639F43BFFB0FB8673D4706061900AD909993A11F9D3C7EC`、`0162D5A367472757684EAD7E6A24BBF84A18523680FDC5E6626B5B94E9BF2BA1`；事务备份数量为 0。
- 当前 MT5 PID 7428 于 21:33:48 加载的仍是 EA 2.03；编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.04`。打开 CASE-005 时，左下角应显示 `EURUSD-2002-H4-CASE-005 | 上升通道`，Experts 的 catalog/focus 日志应同时记录 `opportunity_level=H4`、`duration_hours=453.0` 和 `scope=accumulation_r2`；五份 CSV 在只读打开后必须保持上述哈希。
- 安全约束继续有效：助手没有自动操作 MT5 界面，没有创建或运行 `ChartScreenShot`，没有后台改写正式案例 CSV。

## Session Continuation (2026-08-09, EA 2.05 Effective H1-Bar Opportunity Level)
- 用户核对第一个上升通道后确认：机会周期必须按 R2 在真实行情中的有效宽度判定，周末和休市时间不能计入。第一个案例的 R2 为 `2002.01.16 00:00..2002.01.23 19:00`，虽然日历跨度为 187 小时，但正式 2002 M1 数据只形成 138 根有效 H1 K线，因此应为 H1，不是 2.04 的 H4。
- `MT5_EnergyTrading.mq5` 已升级到 2.05。`OpportunityLevelFromAccumulationRange()` 现在始终对案例权威 symbol 调用 `iBarShift(symbol, PERIOD_H1, ...)`，以 R2 两端 H1 索引差的绝对值加一得到有效 H1 柱数；当前图表即使切换到 H4，也不会改用当前图表周期。`<=168` 根为 H1，`169–672` 根为 H4，超过 672 根为 `UNCLASSIFIED`。端点查询失败会记录 symbol、R2、两个 shift 和两个错误 ID。
- 日历时长与有效柱数保持为两个独立审计量：`accumulation_duration_hours` 继续保存 R2 自然时间跨度，新增 `accumulation_h1_bars` 作为唯一自动分级输入。案例目录改为显示 `N根H1`；catalog、tooltip 和 focus 日志同时输出日历小时与有效 H1 柱数，避免再次混淆。
- 六个正式案例已用 `EURUSD_2002.csv` 只读回放：`CHANNEL-001=187小时/138根/H1`、`CASE-002=167小时/118根/H1`、`CASE-003=159小时/110根/H1`、`CASE-004=202小时/153根/H1`、`CASE-005=453小时/304根/H4`、`CASE-006=173小时/124根/H1`。因此只有 CASE-005 保持 H4；2.04 因周末误判的 CHANNEL-001、CASE-004、CASE-006 均回归 H1。
- 内部 `case_id` 和源 `timeframe=H1` 继续作为不可变档案关联键；左下角显示编码只替换第三段机会级别。第一个案例恢复显示 `EURUSD-2002-H1-CHANNEL-001`，CASE-005 继续显示 `EURUSD-2002-H4-CASE-005`。
- `opportunity_cases.csv` 新 schema 为 25 列，在 2.04 的 `case_code` 后追加 `accumulation_h1_bars`；旧 19 列和 2.04 的 24 列行继续兼容读取。初始化、案例切换和静态回放不会后台迁移，只有用户明确标注或点击 `保存结构` 才把活动案例写为 25 列，且 cases 元数据继续参与 drawings/regions 的同一回滚事务。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.05 有效 H1 柱规则、第一个案例与 CASE-005 对照以及 25 列兼容 schema。正式源码为 8411 行、357138 字节、大括号 707/707，CP936 严格往返通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `FAC77824E306643DC4C270211C35B436FE3BFC1575D60922AF1604C35C123A64`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（6525 ms）；EX5 为 359902 字节，项目与 Junction SHA256 均为 `24579522D358EB54F0DB28405EFD7D7E9BD72A976FFFB98DC433435106A23A41`。
- 实现、编译和文档更新前后五份正式档案仍为 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行，SHA256 继续为 `5E75A72C6C1F73E2F020331366714B0F795A65AAA66C9FE4D8CE834E342D5450`、`9873892F9D8217DCB6FDCA620CCB7686B8384F330DE6E61381B5360AAB71C16B`、`B2C0910435DF3314C7B7961FAA57B38EB3742EE0E77DB8AC83AB0809076DB02F`、`AD4E9240B983036D5639F43BFFB0FB8673D4706061900AD909993A11F9D3C7EC`、`0162D5A367472757684EAD7E6A24BBF84A18523680FDC5E6626B5B94E9BF2BA1`；事务备份数量为 0。
- 当前 MT5 PID 25360 于 22:04:53 加载的仍是 EA 2.04；编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.05`。打开第一个案例时应显示 H1 且 catalog 日志为 `duration_hours=187.0 | h1_bars=138`；打开 CASE-005 应继续显示 H4 且为 `duration_hours=453.0 | h1_bars=304`。只读打开后五份 CSV 必须保持上述哈希。
- 安全约束继续有效：助手没有自动重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`，没有后台改写任何正式案例 CSV。

## End-of-Day Handoff (2026-08-09)
- 今日工作到此结束。EA 2.05 的有效 H1 K线周期判定、六案例只读回放、25 列兼容档案 schema、文档更新、CP936 往返和正式编译均已完成；编译结果为 `0 errors, 0 warnings`。
- 明日第一步由用户完整关闭 MT5，并从固定快捷方式重新启动，确认 Experts 出现 `EA INIT | ver=2.05`。不得把当前仍在内存中运行的 2.04 视觉结果当作 2.05 验收结果。
- 明日实机验收重点：第一个案例显示 `EURUSD-2002-H1-CHANNEL-001`，catalog 日志包含 `duration_hours=187.0 | h1_bars=138`；CASE-005 继续显示 `EURUSD-2002-H4-CASE-005`，日志包含 `duration_hours=453.0 | h1_bars=304`；切换 H1/H4 后显示编码和 R2 居中位置均不得变化。
- 只读打开和切换案例后，五份正式 CSV 必须继续保持 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行及 2.05 章节记录的 SHA256；只有用户明确标注或点击 `保存结构` 才允许活动案例迁移到 25 列 cases schema。
- 尚未实现的明确需求仍为“非标准”人工选项。它必须作为独立标准性维度实现，不能与自动 H1/H4 机会级别或十二类机会类型混用；应在完成 2.05 实机验收后再进入设计与实现。

## Session Continuation (2026-08-10, EA 2.06 Non-Standard Opportunity Standardity)
- 用户冻结“非标准交易机会”的业务定义：它不是第 13 种机会类型，而是十二类标准轮廓的衍生变体；外部轮廓仍能归入既有 `case_type`，但内部结构、枢轴、边界、对称或推进关系不如标准形态精准/完美，并可能伴随假突破。标准性不得改变 R2 派生的 H1/H4 机会级别、三区角色、结构点或关键 K 线。
- `MT5_EnergyTrading.mq5` 已升级到 2.06。十二类类型菜单下方新增全宽勾选行：未勾选显示 `[ ] 非标准交易机会`，勾选显示 `[X] 非标准交易机会`。勾选状态关闭菜单后仍通过主类型按钮后缀 `非标/待判`、案例左下角文字和案例目录项显示。
- 新增独立状态 `UNREVIEWED / STANDARD / NON_STANDARD`。现有 19/24/25 列案例不被后台猜测为标准，而是兼容加载为 `UNREVIEWED`；普通 STRUCT、KEY BAR 和拖动自动归档在标准性待提交时继续写旧归档值。勾选本身只更新内存并固定记录 `archive_touched=0`。
- `opportunity_cases.csv` 当前 schema 在 2.05 的 `accumulation_h1_bars` 后追加 `standardity`、`standardity_confirmed`，共 27 列。只有用户明确点击 `保存结构` 才提交：勾选写 `NON_STANDARD,1`；未勾选或旧档待判写 `STANDARD,1`。现有六案例正式 CSV 本轮没有迁移，仍保持 19 列和原哈希。
- 标准性元数据接入现有受保护保存事务。cases 档案仍先备份；写入后必须回读当前案例的第 26/27 列并验证期望值与 `confirmed=1`。写入或回读失败会与 drawings/regions 及必要的类型档案一起回滚。假突破的具体发生时间不会由勾选框推断；若以后需要事件级监督，必须另建人工证据字段/标记。
- 周期会话标记已从 V2 升级为 V3，新增活动标准性、归档标准性和待保存标志三个独立隐藏对象名字段。V3 仍不使用易截断的 `OBJPROP_TEXT`；首次加载可兼容读取旧 V2 六字段并将标准性置为 `UNREVIEWED`，随后保存为 10 个 V3 标记。会话对象继续不进入 drawings 扫描且 `archive_touched=0`。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.06 定义、勾选行为、V3 会话、27 列兼容 schema、显式提交与回滚语义。
- 正式源码为 8708 行、373419 字节、大括号 722/722，CP936 严格往返通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `C963C29787CD49E5E25D4D13B7CA36A34246744257C7E636871CE1ED58BA51ED`。MetaEditor 最终编译结果为 `0 errors, 0 warnings`（5822 ms）；EX5 为 375008 字节，项目与 Junction SHA256 均为 `54D43DF0B79B445187CA9C107314ACAD8522B2ED9785FC44C7DEB7C199680C91`。
- 实现、文档和编译前后五份正式档案仍为 cases/anchors/key bars/drawings/regions = 6/30/6/52/18 行；SHA256 继续为 `5E75A72C6C1F73E2F020331366714B0F795A65AAA66C9FE4D8CE834E342D5450`、`9873892F9D8217DCB6FDCA620CCB7686B8384F330DE6E61381B5360AAB71C16B`、`B2C0910435DF3314C7B7961FAA57B38EB3742EE0E77DB8AC83AB0809076DB02F`、`AD4E9240B983036D5639F43BFFB0FB8673D4706061900AD909993A11F9D3C7EC`、`0162D5A367472757684EAD7E6A24BBF84A18523680FDC5E6626B5B94E9BF2BA1`；事务备份数量为 0。
- 当前 MT5 PID 12224 于 05:18:19 加载的仍是 EA 2.05；2.06 编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.06`。首次视觉验收只展开类型菜单并勾选/取消“非标准”，不点击 `保存结构`：应看到按钮、案例文字同步变化及 `standardity selected ... archive_touched=0`，五份 CSV 哈希必须不变。真正遇到首个非标准案例时再明确保存，届时验证 `standardity=NON_STANDARD | confirmed=1 | verified=1` 及 27 列 cases 行。
- 安全约束继续有效：助手没有自动重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`，没有后台改写任何正式案例 CSV。

## Session Continuation (2026-08-10, EA 2.07 Centered Compact Region Labels)
- 用户确认以当前五份正式档案中的 8 个案例作为 2002 年权威案例集；其中包含用户人工补充、原始档案没有的案例，因此不再用旧 Excel 或原始案例清单判断 2002 年案例是否遗漏。未覆盖的类型和月份只表示当前样本分布，不表示漏标。
- 用户同时冻结当前标注语义：`future_outcome` 是可选的关键 K 线之后结果字段，当前为空不属于遗漏；结构点使用可扩展 `S1...Sn`，数量由具体案例决定，不设统一 5 点下限；上升通道不具备积累前释放，因此没有 `PRE_ACCUMULATION_RELEASE_PATH` 是不适用；假突破可在后续分析中由关键 K 线之前的 OHLC 越过结构线并重新回到区间自动派生，不需要当前人工事件标签。
- 用户截图指出三区标签在部分案例中没有位于可见区间正中且字号过大。根因是 `CreateOpportunityRegionLabel()` 使用起止时间戳的算术中点；区间包含周末或休市空档时，该时间中点与 MT5 图上的真实像素中点不一致。
- `MT5_EnergyTrading.mq5` 已升级到 2.07。每个区间标签现在先将两条权威边界转换为屏幕 X 坐标，再直接使用二者的像素中点，因此始终跟随图上实际区间居中；滚动和缩放仍通过原刷新路径重新计算。标签垂直中心统一为主图高度的 `3/4`，即正中偏下；字体由 10 号缩小为 8 号，外框高度由 30 px 缩小为 24 px，R2 宽度由 96 px 缩小为 80 px，R1/R3 由 154 px 缩小为 128 px。
- 本轮只修改显示层，没有改变四条边界、三区时间或任何案例档案。`Data/Local_Data/opportunity_annotations/README.md` 已同步 2.07 的屏幕像素中点、偏下位置和紧凑样式规则。
- 正式源码为 8716 行、373566 字节、大括号 723/723，CP936 严格往返通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `302B5F732713298F26CD49F9F53DC85C317E19A827C1B9FEEA792FE9E3085624`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（5881 ms）；EX5 为 375136 字节，项目与 Junction SHA256 均为 `8CE0C85AB89A8FD631EE366254453B6C87C333E78F301BC26FCD83C75369E40F`。
- 实现、文档和编译前后五份正式档案保持 cases/anchors/key bars/drawings/regions = 8/39/8/68/24 行，SHA256 分别为 `8BFDCD8F0734BBDBAE233A56FE52AC2ABAE34789133C12013A13D4FFCCE91E12`、`10F0A1E0C7BA5F5B769CF7A3DE449509505DDC3F8A55123E07A9A65A8CD472CC`、`825268B808F5349F4AF1A0495D5F6BAA5159EDA2DABCA2A2871BD81D65DC679E`、`F83F68A7B5676165CFF7D26DCFA0E2F47058BF17845FF7AA8999AA99BEFBE5E1`、`0E2AFB0E53796AA8D6F4B3EB0CB749BBA53D4684C6A8706310639293B6173CCD`；事务备份数量为 0。
- 当前 MT5 PID 16712 仍运行 EA 2.06，编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 Experts 出现 `EA INIT | ver=2.07`；随后打开截图案例并目视确认三段文字分别位于两条蓝色边界的正中、主图偏下位置且字号明显缩小。助手没有自动重启或操作 MT5，也没有创建截图或改写正式案例 CSV。

## Session Continuation (2026-08-10, EA 2.08 Bottom-Aligned Region Labels)
- 用户完成 2.07 实机验收后截图确认：三区标签的水平居中和紧凑字号已经正确，但主图 `3/4` 高度仍整体偏高；新要求是统一放到各个区间底部。
- `MT5_EnergyTrading.mq5` 已升级到 2.08。三区标签不再按主图比例计算垂直中心，改为标签框底边固定距离主图区底部 58 px；24 px 框高因此整体贴近时间轴上方。2.07 已验证的两边界屏幕像素中点、8 号字体、R2 80 px 宽、R1/R3 128 px 宽保持不变。
- 本轮仍只修改显示层，没有改变四条区间边界、三区时间或任何正式案例数据。`Data/Local_Data/opportunity_annotations/README.md` 已同步当前底部固定定位，并保留 2.07 的历史说明。
- 正式源码为 8718 行、373691 字节、大括号 723/723，CP936 严格往返通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `9E33D0744766C0413A99332C977FFAAD007B20E8EB3DD5D135C2AD45A88CCA8A`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（5907 ms）；EX5 为 375484 字节，项目与 Junction SHA256 均为 `68346AB241F682B548520D8304E6FDCBE669EBA618A3E62A0A17D66693BBE3A7`。
- 五份正式档案继续保持 cases/anchors/key bars/drawings/regions = 8/39/8/68/24 行及 2.07 章节记录的 SHA256，事务备份数量为 0。
- 当前 MT5 PID 4372 已由用户重启并在 10:22:06 于 H4 加载 EA 2.07；2.08 编译不会热替换。用户需再次完整关闭并从固定快捷方式重开，确认 Experts 出现 `EA INIT | ver=2.08`，随后目视确认三区标签均贴近各自区间底部且水平中心不回退。助手没有自动重启或操作 MT5，也没有创建截图或改写正式案例 CSV。

## Session Continuation (2026-08-10, EA 2.09 Pixel-Verified R2 Chart Centering)
- 用户在 2.08 实机截图中确认新的底部三区标签已经显示，但从案例目录呈现 CASE-007 时，R2 两条蓝色边界的屏幕中点仍未与整张主图的水平中心完全重合。
- 根因是旧 `FocusOpportunityCaseOnChart()` 只用 `CHART_VISIBLE_BARS / 2` 估算 `ChartNavigate()` 位置。即使 R2 中心柱计算正确，MT5 的价格轴、边缘半柱和图表内部偏移仍会留下固定像素误差；CASE-007 的 2.08 日志为 `boundary_shifts=1181/1044 | shift=1112 | visible_bars=467 | position=-879`，但该日志没有测量导航后的实际屏幕位置。
- `MT5_EnergyTrading.mq5` 已升级到 2.09。首次按 R2 边界柱索引中点导航后，EA 强制重绘并读取两条 R2 边界在当前图表上的实际 X 坐标，以二者像素中点对比 `CHART_WIDTH_IN_PIXELS / 2`。剩余像素误差按当前 R2 边界间的平均每柱像素宽度换算为整数柱修正，再次调用 `ChartNavigate()`；最多执行三次，最终允许的误差为半根当前周期柱且不少于 2 px。
- 聚焦日志新增 `chart_center_x`、`range_center_x`、`pixel_error`、`centering_passes` 和 `center_verified`。实机验收要求 `scope=accumulation_r2`、`center_verified=1`，并且 `range_center_x` 与 `chart_center_x` 的差值只剩允许的半柱像素误差。失败路径会明确记录边界坐标测量或像素修正失败及错误 ID。
- 2.08 的三区底部位置、水平标签居中、8 号字体以及所有案例档案语义保持不变。`Data/Local_Data/opportunity_annotations/README.md` 已同步 2.09 的 R2 像素校正流程和新增日志字段。
- 正式源码为 8793 行、376694 字节、大括号 728/728，CP936 严格往返通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `9DFD69225F2059E30D9942D43B17604AA02D3DF047FBB97B681129EF311073F0`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（6058 ms）；EX5 为 377702 字节，项目与 Junction SHA256 均为 `DE64B9AB38D195EFB7C4857CB26B02609B50C95378F3AD16025D9AEC8522AB9C`。
- 五份正式档案继续保持 cases/anchors/key bars/drawings/regions = 8/39/8/68/24 行及前述 SHA256，事务备份数量为 0。
- 当前 MT5 PID 4200 仍运行 EA 2.08，编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 Experts 出现 `EA INIT | ver=2.09`；随后重新打开 CASE-007，目视确认 R2 位于整张主图正中，并核对最新 `chart focus` 日志包含 `center_verified=1`。助手没有自动重启或操作 MT5，也没有创建截图或改写正式案例 CSV。

## Session Handoff (2026-08-10)
- 本轮目标已完成：三区标签保持底部固定定位，案例呈现时 R2 使用实际屏幕像素测量和最多三次柱位校正，以消除 `CHART_VISIBLE_BARS / 2` 带来的视觉偏差。
- 代码、README 和编译日志已经同步；五份正式案例 CSV 未修改，当前正式档案仍为 8/39/8/68/24 行，事务备份为 0。
- 下一步只需进行 2.09 实机验收：重启 MT5，打开任一案例，确认 `EA INIT | ver=2.09`、`scope=accumulation_r2`、`center_verified=1`，并目视确认 R2 位于整个主图水平中心。

## Session Continuation (2026-08-11, 2002 Annotation Complete / 2003 Transition)
- 用户正式确认：2002 年所有标准交易机会已经总结完毕。项目以当前五份正式档案中的 8 个案例作为 2002 年冻结真值集，后续切换年度、周期、案例或重启均不得后台改写这些档案。
- 冻结基线为 cases/anchors/key bars/drawings/regions = 8/39/8/68/24 行；SHA256 分别为 `8BFDCD8F0734BBDBAE233A56FE52AC2ABAE34789133C12013A13D4FFCCE91E12`、`10F0A1E0C7BA5F5B769CF7A3DE449509505DDC3F8A55123E07A9A65A8CD472CC`、`825268B808F5349F4AF1A0495D5F6BAA5159EDA2DABCA2A2871BD81D65DC679E`、`F83F68A7B5676165CFF7D26DCFA0E2F47058BF17845FF7AA8999AA99BEFBE5E1`、`0E2AFB0E53796AA8D6F4B3EB0CB749BBA53D4684C6A8706310639293B6173CCD`；事务备份数量为 0。
- 2003 数据继续使用同一权威 Forex Tester M1 源 `data/EditMode/EURUSD/1/Bars.dat` 和现有 `modules/replay/src/convert_forex_tester_bars.py`，目标文件为 `Data/Local_Data/split_by_year/EURUSD_2003.csv`；禁止改用实际只有 2010 年数据的 `data/Ticks/EURUSD.dat`。
- 新阶段将增加独立、常驻的工作年份选择器。选择 2003 后必须检查/加载 `EURUSD_2003.csv`、切换到 `EURUSD@_2003_FULL`、持久化工作年份，并使新草稿从 `EURUSD-2003-H1-CASE-001` 开始。案例目录必须同时显示 2002 的 8 个案例与 2003 的 0 个案例。
- 从案例目录打开跨年案例时，EA 必须先切换到对应年度行情再只读加载案例；单纯切换年份、周期、重启或打开案例固定保持 `archive_touched=0`。
- 已从上述同一 `Bars.dat` 导出 `EURUSD_2003.csv`：305,119 行、20,698,402 字节，实际时间 `2003-01-01 23:01` 至 `2003-12-31 23:13`，SHA256 为 `42DEA40093BAAB3383C15CA664B9ACE4CA8E7F5A298209C2FB981A0A31BCCE54`。独立验证已通过 9 列无表头、全年年份约束、严格升序、无重复、OHLC 合法、非负成交量/点差和项目路径与 MT5 Junction 哈希一致。
- 2003 源数据从 `2003-05-06 00:00` 起出现大量较大成交量值，最高为 2,147,400,028；已逐条回查 `Bars.dat` 原始 `float64 volume`，CSV 与源值一致，不是转换溢出或列错位。转换继续遵守原样保留源成交量的既定规则，不在导出层擅自归一化。
- 2003 导出和验证前后五份正式案例档案哈希完全不变，事务备份数量仍为 0。
- `MT5_EnergyTrading.mq5` 已升级到 2.10。FULL 行情从“固定一个 2002 品种可选合并多年 CSV”改为“一年一个自定义品种、一年一个 CSV”：工作年份 2002 对应 `EURUSD@_2002_FULL / EURUSD_2002.csv`，2003 对应 `EURUSD@_2003_FULL / EURUSD_2003.csv`。`InpFullEndYear` 默认扩展到 2003，旧 `InpFullLoadAllYears` 保留兼容但默认关闭且不再把多个年度写进同一年度品种。
- FULL 面板顶部新增常驻绿色 `年份 | YYYY` 按钮。年度菜单对每个配置年份显示案例数量和 CSV 可用性；切换前依次验证 CSV、创建/检查年度自定义品种、检查或导入 M1 历史，全部成功后才将当前图表切到目标年度 H1。CSV、品种、导入、会话或 `ChartSetSymbolPeriod` 任一步失败都会恢复旧年度和旧会话，日志包含错误 ID，固定 `archive_touched=0`。
- 工作年份同时保存到终端 Global Variable `Energy_FullWorkYear` 和 V4 隐藏标记对象。V4 在原 V3 十个标记上追加独立年份标记，继续兼容读取 V3/V2；周期切换、启动配置先打开 2002 品种以及终端重启后，恢复端会先读会话/全局工作年份，再切到对应年度行情。
- 案例目录年份层不再只来源于已有案例，而是合并配置年度范围，因此当前必定显示 `2002 | 8 个` 和 `2003 | 0 个`。空年份可以正常进入并显示“暂无已保存案例”，不再被“目录为空”错误拦截。
- 新草稿编号改为按年份独立扫描该年最高 `CASE-NNN`：当前 2002 下一条仍为 `EURUSD-2002-H1-CASE-009`，2003 第一条固定为 `EURUSD-2003-H1-CASE-001`，不再使用全目录案例总数或可见窗口时间推导编号。
- 从案例目录选择其他年份的正式案例时，2.10 先准备目标案例的只读会话并切换到对应 `EURUSD@_YYYY_FULL`，新年度 `OnInit()` 才加载五档案、定位 R2 和重绘；因此 2002 案例不会再画到 2003 行情上，反向切换同理。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.10 年度 UI、年度行情、V4 会话、零案例年份、按年编号和跨年加载语义；replay README 已明确权威源为 `data/EditMode/EURUSD/1/Bars.dat`、2003 转换命令以及禁止使用只有 2010 数据的 tick 文件。
- 2.10 正式源码为 9,371 行、400,166 字节，大括号 774/774，CP936 严格往返和 `git diff --check` 通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `FA99D486EA7155A7115FBCD807FD1A25D43FBB9CC327DB09E54AA2E6D90FC9E6`。MetaEditor 最终编译结果为 `0 errors, 0 warnings`（6,393 ms）；EX5 为 403,482 字节，项目与 Junction SHA256 均为 `2EBFC5473F417A2C11E53216C265B246311E7BE7580D6516FC53CFC7A312EE66`。
- 实现、格式化、文档和两次正式编译前后五份 2002 档案继续保持 cases/anchors/key bars/drawings/regions = 8/39/8/68/24 行及本节冻结哈希，事务备份数量为 0；2003 切换逻辑没有后台创建任何案例行。
- 当前 MT5 PID 3852 于 08:35:06 加载的仍是 EA 2.09；编译不会热替换。用户需完整关闭并从固定快捷方式重开，先确认 `EA INIT | ver=2.10`。随后点击年份 2003，预期日志依次包含 `history ready ... year=2003 ... verified=1`、`session prepared ... EURUSD-2003-H1-CASE-001`、`switch result ... archive_touched=0`，图表品种变为 `EURUSD@_2003_FULL`，案例年份层显示 2002/8 与 2003/0。再做 2003 H1/H4/H1、重启持久化以及从目录打开 2002 案例后自动返回 `EURUSD@_2002_FULL` 的实机回归。
- 安全约束继续有效：助手没有自动重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`，没有改写任何正式案例 CSV；2003 年第一条案例仍须由用户在实机年度切换验收通过后明确标注。

## Session Continuation (2026-08-11, EA 2.11 Blank Startup Case Selection)
- 用户实机截图确认 2.10 的完整终端重启仍会自动显示第一个正式案例。Experts 在 14:34:56 精确复现：`marker state unavailable; using input defaults | case=EURUSD-2002-H1-CHANNEL-001`，随后读取该案例的 structures/key bar/drawings/regions 并重绘。根因是固定启动配置创建新图表后没有 V4 图表标记，EA 回退到 `InpAnnotationCaseId` 的首案例默认值；这不是正式 CSV 被改写或旧图形残留。
- `MT5_EnergyTrading.mq5` 已升级到 2.11。新增 `InpOpenDefaultCaseOnStartup=false`；默认情况下，无有效 V4 会话时不再把 `InpAnnotationCaseId/InpAnnotationCaseType` 设为活动案例，而是为已恢复的工作年份准备一个未入库 `UNSELECTED` 空白草稿。旧默认案例输入仅在用户显式把该兼容开关设为 `true` 时生效。
- 空白启动路径会主动删除可能残留的结构点、关键 K 线框、托管绘图、三区标签和案例文字，然后跳过五份案例档案；案例目录和年份选择器仍正常可用。只有用户从案例目录明确选择正式案例后才执行五档案只读加载、R2 定位和重绘。启动、空白草稿和目录选择继续固定 `archive_touched=0`。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.11 的无选择启动语义和显式兼容开关。正式源码为 9,396 行、402,494 字节，大括号 776/776，CP936 严格往返通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `08BC98D17ED26396623A30A438C07264960CAD64338AD0188C7FD6408121E7FF`。
- MetaEditor 最终正式编译结果为 `0 errors, 0 warnings`（8,014 ms）；EX5 为 405,046 字节，项目与 Junction SHA256 均为 `6D10FF9D6D3A74AD2AA980057DFA38D1A24A0D4C557B1FBFC1AF5C0C4F3B2B9D`。
- 实现、文档和两次编译前后五份 2002 冻结档案继续保持 cases/anchors/key bars/drawings/regions = 8/39/8/68/24 行；SHA256 仍为 `8BFDCD8F0734BBDBAE233A56FE52AC2ABAE34789133C12013A13D4FFCCE91E12`、`10F0A1E0C7BA5F5B769CF7A3DE449509505DDC3F8A55123E07A9A65A8CD472CC`、`825268B808F5349F4AF1A0495D5F6BAA5159EDA2DABCA2A2871BD81D65DC679E`、`F83F68A7B5676165CFF7D26DCFA0E2F47058BF17845FF7AA8999AA99BEFBE5E1`、`0E2AFB0E53796AA8D6F4B3EB0CB749BBA53D4684C6A8706310639293B6173CCD`；事务备份数量为 0。
- 当前 MT5 PID 16148 于 14:34:56 加载的仍是 EA 2.10；2.11 编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.11`，随后应看到 `marker state unavailable | default_case_enabled=0`、`session prepared | reason=startup_no_selection` 和 `draft initialized ... archives_skipped=1 | archive_touched=0`，且不得出现任何正式案例的 `archive loaded`/`redraw result`。图面应没有第一个案例的结构点、关键 K 线、红线、蓝色边界、三区标签或案例文字；案例按钮仍显示总数 8。选择目录中的案例后才应正常只读重绘。
- 安全约束继续有效：助手没有重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`，没有改写任何正式案例 CSV。

## Session Continuation (2026-08-11, EA 2.12 Current-Year / Total Case Counts)
- 2.11 空白启动已完成实机验证：14:48–14:50 的 Experts 多次确认 `EA INIT | ver=2.11`；2003 空白草稿固定为 `EURUSD-2003-H1-CASE-001`，2002 空白草稿固定为 `EURUSD-2002-H1-CASE-009`，H1/H4/D1 切换均记录 `draft initialized ... archives_skipped=1 | archive_touched=0`，没有重新加载第一个正式案例。用户随后确认新的显示需求：案例主按钮既要保留全部年份总数，也要随当前工作年份显示该年的案例数。
- `MT5_EnergyTrading.mq5` 已升级到 2.12。关闭状态的案例按钮由 `案例 | 共 N 个` 改为 `案例 | 本年 N | 总计 M`：`N=CountOpportunityCasesForYear(fullWorkYear)`，`M=ArraySize(opportunityCaseCatalog)`。动态 tooltip 同时显示明确年份，例如 `当前年份 2003：0 个 | 全部年份：8 个`。
- 双计数复用现有 `UpdateOpportunityCaseSelectorButton()` 刷新路径，因此完整初始化、年份切换、案例目录重载以及用户明确保存新案例后都会自动更新；三级案例目录、跨年只读加载、空白草稿和所有档案语义均未改变。2002 当前预期显示 `案例 | 本年 8 | 总计 8`，2003 当前预期显示 `案例 | 本年 0 | 总计 8`。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.12 双计数与 tooltip 规则。正式源码为 9,402 行、402,975 字节，大括号 776/776，CP936 严格往返通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `974F6C2E8C6CCFFFF87BCECB68988B9935C4D1EC520D72AE4A8ADDC9D50006B8`。
- MetaEditor 正式编译结果为 `0 errors, 0 warnings`（6,734 ms）；EX5 为 406,626 字节，项目与 Junction SHA256 均为 `F99DB599B327149550AC0E0BE65400C3DD644C6AEBCA9AEAEEC386C91FA99A79`。
- 实现、文档和编译前后五份 2002 冻结档案继续保持 cases/anchors/key bars/drawings/regions = 8/39/8/68/24 行及 2.11 章节记录的 SHA256，事务备份数量为 0。
- 当前 MT5 PID 24504 仍运行 EA 2.11；2.12 编译不会热替换。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.12`，目视核对 2003 为 `本年 0 | 总计 8`，切到 2002 后立即变为 `本年 8 | 总计 8`，再切回 2003 应恢复 `本年 0 | 总计 8`；全过程仍应保持空白草稿且 `archive_touched=0`。
- 安全约束继续有效：助手没有重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`，没有改写任何正式案例 CSV。

## Session Continuation (2026-08-11, EA 2.13 Editable Multi-Timeframe Drafts)
- 用户在仍运行 2.11 的 MT5 中继续完成了 3 个 2003 正式案例，因此 2.12 章节的 8 案例基线已经过期且不得恢复。当前正式目录为 11 个案例，2003 下一空白草稿为 `EURUSD-2003-H1-CASE-004`；五份档案最新基线为 cases/anchors/key bars/drawings/regions = 11/55/11/85/33 行，SHA256 分别为 `57B909DC978545856B75D5F7519C11F5DC086E67D89025D7474E59FAEED4B828`、`4E65847793251FD15CA742981C7B32055B75927665212DF200093F8C5972C9E9`、`C74A234BCD43D94F9185885574A42ECBFE58321F59FC17ACE64BDB6A8BD38451`、`98B71449B79BDC730E7EDCEA6D10FC64290680ABEAA0ADF565433E49098E2D1B`、`7336AE1D31A03986C433A31DC16C44AD761ED4A92053E6911E19DF448456A101`；事务备份数量为 0。
- 用户随后实机发现空白草稿只能在 H1 标注：切到 H4 后全部标注按钮变灰。Experts 在 15:50:14 精确复现 `case=EURUSD-2003-H1-CASE-004 | native=EURUSD@_2003_FULL/H1 | chart=EURUSD@_2003_FULL/H4 | read_only=1 | archives_skipped=1`。根因是旧保护规则把尚未写档的空白草稿也永久绑定到创建时的 H1，而不是仅锁定已有正式证据的案例。
- `MT5_EnergyTrading.mq5` 已升级到 2.13。未出现在案例目录中的空白草稿会在周期切换后的初始化中自动重绑定到当前图表周期：重新生成同一年度、同一下一序号且带当前源周期的草稿 ID，并同步更新 native symbol/timeframe。例：H1 空白 `EURUSD-2003-H1-CASE-004` 切到 H4 后变为 `EURUSD-2003-H4-CASE-004`，会话只写 V4 图表标记，日志固定为 `draft timeframe rebound ... archive_touched=0`，随后 `draft initialized` 必须为 `native=.../H4 | chart=.../H4 | read_only=0`。
- `新建案例` 现在也直接使用当前图表周期生成草稿和 native timeframe，因此在 H4 点击会建立 H4 原生草稿；若用户在首次正式标注前切回 H1，空白草稿可再次安全重绑定。选择的机会类型和标准性内存状态会保留，正式 CSV 仍不会因周期切换产生任何行。
- 已归档案例的保护语义没有放宽：一旦 STRUCT/KEY BAR 等明确操作创建正式案例行，源 `timeframe` 继续是权威标注周期；在其他周期打开时仍为只读并保持按钮灰色，防止同一案例跨周期误改。机会级别仍由 R2 的有效 H1 柱数独立派生，不能与源标注周期混用。
- 2.12 的 `案例 | 本年 N | 总计 M` 双计数改动完整包含在 2.13 中。按当前新基线，2003 应显示 `本年 3 | 总计 11`，2002 应显示 `本年 8 | 总计 11`。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.13 空白草稿周期重绑定与已归档案例周期锁定边界。正式源码为 9,451 行、405,711 字节，大括号 778/778，CP936 严格往返通过；项目与 `D:\mt5` Junction 源码 SHA256 均为 `0152E1B745134DCD22A92AEE11CBE06432980F642127D35216F307099764C02B`。
- MetaEditor 正式编译结果为 `0 errors, 0 warnings`（6,525 ms）；EX5 为 407,114 字节，项目与 Junction SHA256 均为 `E1057EDF2C341343A4619C571AA07085A8871288347803748651316FC78401E6`。实现、文档和编译前后上述 11 案例五档案哈希完全不变。
- 当前 MT5 PID 24504 仍运行 EA 2.11，2.12/2.13 均未热加载。用户需完整关闭并从固定快捷方式重开，确认 `EA INIT | ver=2.13`；在未入库 CASE-004 上执行 H1 -> H4，预期出现 `draft timeframe rebound`、面板 `VIEW H4` 且 `read_only=0`，按钮不再因周期保护统一变灰。再从目录打开任一已归档 H1 案例并切 H4，仍应为 `read_only=1`，用于验证保护边界没有回退。
- 安全约束继续有效：助手没有重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`，没有改写任何正式案例 CSV。

## Session Continuation (2026-08-11, EA 2.14 Read-Only Geometry Semantic Advice)
- 用户明确同意先实现一版自动划分/着色算法的安全前置阶段。当前阶段冻结为“只读几何语义建议”：算法输出建议角色、置信度、证据和 Experts 日志，但不修改绘图颜色、不覆盖现有正式语义、不写五份 CSV；自动着色必须等本阶段实机观察通过后再单独启用。
- 实现前重新建立了当前正式档案基线，旧 11 案例哈希已经过期且不得恢复。最新目录共有 14 个案例（2002 年 8 个、2003 年 6 个），五份档案 cases/anchors/key bars/drawings/regions = 14/72/14/97/39 行；SHA256 分别为 `8250A861272F956EA3BA32E885FC04244775E3F9F86F6E6E7BC0B46DEB0D9773`、`A618F2DE25039D7F7EF645A567C7B572FE4E50C16A0B1B5E7070389917F90B55`、`5211173E15A16DAF276BA8DDB7E0C3E74057145B6B0EEE132FAC4FF754E3193B`、`4901E46CBE616047DA38D001EE9FA020F340E8B043BC185F6D9FD4AEE75AD9A3`、`DE52B87A9338AE6F8A31817F8FF16D58683B89652991606F78A184AC3574E4A6`；事务备份数量为 0。`EURUSD-2003-H1-CASE-006 / DOUBLE_TOP` 当前只有 structures/key bar，没有 drawings/regions，因此不进入首轮趋势线验收集。
- `MT5_EnergyTrading.mq5` 已升级到 2.14，新增默认开启的 `InpOpportunityGeometryAdvice`。分类器只读取 `OBJ_TREND` 的时间/价格几何、R1/R2 权威区间、结构圆和 H1 OHLC；明确屏蔽颜色、线宽、已存 `semantic_*`、drawing ID/name 与屏幕角度。每条日志固定输出 `color_used=0 | width_used=0 | semantic_input_used=0 | archive_touched=0 | colors_changed=0`。
- V1 使用有效 H1 柱而非日历时长计算区间占比，并把 R1/R2 作为半开区间处理，使共享边界柱只归属一个区域；R2 的 H1 True Range 中位数作为 ATR 基准。非通道释放路径门禁为：R1 占比 `>=0.55`、端点连接 R2 最早结构点（结构时间窗内且价格距离不超过 `1.5` 个结构圆半径）、位移 `>=5.0 ATR`、斜率 `>=0.05 ATR/有效H1柱`、从人工起点经中间 H1 收盘价到人工终点的完整路径效率 `>=0.10`。R2 占比 `>=0.45` 的其余趋势线建议为 `STRUCTURE_LINE`；无法充分归类的线建议为 `REVIEW_REQUIRED`。`ASCENDING_CHANNEL` 与 `DESCENDING_CHANNEL` 对积累前释放执行硬排除。
- 建议日志接入三条只读/预写路径：完整初始化后 `trigger=initialization`、案例目录只读切换成功后 `trigger=case_switch`、用户点击 `保存结构` 且四条边界成功生成三区后、任何备份或 CSV 写入前 `trigger=save_preflight`。日志前缀统一为 `[EA|FULL|GEOMETRY]`，逐线包含 R1/R2 占比、有效 H1 柱数、ATR、ATR 位移/斜率、路径效率、首结构连接、建议角色、置信度和与现有人工语义的一致性；汇总固定包含 `mode=read_only_v1`。
- 当前 38 列 drawings 档案共有 39 条正式趋势线，人工真值为释放路径 8 条、结构线 31 条；颜色与角色完全一一对应，因此只用于输出后的验收标签，不进入算法特征。使用 2002/2003 权威 OHLC 对 V1 做独立只读回放，结果为建议释放 8、结构 29、待复核 2，与人工语义一致 37/39（94.87%），释放路径召回 8/8，通道释放误报 0。两条待复核均是有价值的异常：`CASE-007/D004` 是无位移且位于 R2 前的退化红线；`CASE-005/D001` 是远离该通道 R1/R2 的超长旧红线。算法没有为了追求表面 100% 一致而强制吞掉这两条异常。
- 独立代码审查确认没有阻断或高风险问题，并验证三个调用点均不接触颜色、正式语义或 CSV。审查提出的两个中等/中低风险已在最终构建前修正：路径效率分母现在包含人工端点到首尾 H1 收盘价的距离，不再因口径不同而被虚高；R1/R2 共享边界柱不再双重计入。日志中的对照标签也改为 `reference_role/source/confirmed`，明确它仅用于验收，不是算法输入。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.14 的特征屏蔽、阈值、三个触发点、日志字段与只读保证。实现和正式编译前后五份 CSV 行数/哈希完全不变，事务备份仍为 0。
- 正式源码保持 CP936，严格字节往返通过；源码为 9,960 行、428,639 字节、大括号 810/810，项目与 `D:\mt5` Junction SHA256 均为 `807465DD6F08969B27F388FC189C949F3C58D5BF16AF042BB493D80B23EB0127`。MetaEditor 最终正式编译结果为 `0 errors, 0 warnings`（6,590 ms）；EX5 为 419,868 字节，项目与 Junction SHA256 均为 `770E3DCFB5E1F744018D672F35378E5B8BE4E372287C997EADD556FFCDE600EA`。
- 当前 MT5 PID 24196 仍运行 20:04:51 加载的 EA 2.13，正式编译不会热替换；助手没有重启或操作 MT5。用户需完整关闭并从固定快捷方式重开，先确认 `EA INIT | ver=2.14`。随后从案例目录打开一个非通道案例，Experts 应出现逐线 `line advice` 和 `advice summary`，典型完整案例应显示一条 `PRE_ACCUMULATION_RELEASE_PATH`、若干 `STRUCTURE_LINE`、`channel_pre_release=0`；打开任一通道案例必须保持 `pre_release=0`。本版图面颜色不会变化，这是预期的安全验收行为。
- 下一步仅在用户观察 2.14 日志并确认建议可靠后，设计第二阶段预览/自动着色：高置信释放路径紫色、积累结构红色、待复核橙色，并保留人工覆盖。第二阶段仍不得因启动、年份、周期或案例切换后台改写正式档案；任何正式语义迁移继续只能由用户明确点击 `保存结构` 触发。

## Session Continuation (2026-08-11, EA 2.15 Non-Persistent Geometry Preview)
- 用户实机指出 2.14 “明显没起作用”：积累前释放没有在图上变色或加粗。最新 Experts 与正式档案核对确认分类本身正确，问题是 2.14 按已冻结的安全前置设计只输出日志、明确 `colors_changed=0`，因此没有任何视觉反馈。当前活动案例 `EURUSD-2003-H1-CASE-006 / DOUBLE_TOP` 中，算法已把 `D002` 建议为 `PRE_ACCUMULATION_RELEASE_PATH`，置信度 `0.874`；`D001/D003/D004` 建议为 `STRUCTURE_LINE`，汇总为释放 1、结构 3、待复核 0。
- 用户在 21:22 又明确点击了一次正式 `保存结构`，所以 2.14 章节的 14/72/14/97/39 基线已经过期且不得恢复。2.15 实现前后最新五档案均为 cases/anchors/key bars/drawings/regions = 14/72/14/105/42 行；SHA256 分别为 `CE59DAF1A70944DA9B44C8B7836085E43C2E92A7102E34D01A4EC8EFA3C0309A`、`A618F2DE25039D7F7EF645A567C7B572FE4E50C16A0B1B5E7070389917F90B55`、`5211173E15A16DAF276BA8DDB7E0C3E74057145B6B0EEE132FAC4FF754E3193B`、`80A12DD379738CF19287F4949D5A31664A451917F6EAEEDCC3A9920931ADD8AF`、`0B68304885FFB176B94ACC1F042E3959E3BBF114413CE3755FFF7C1904864521`；事务备份数量为 0。
- `MT5_EnergyTrading.mq5` 已升级到 2.15，新增默认开启的 `InpOpportunityGeometryPreview=true`。分类结果现在通过独立的非持久化前景叠加对象直接显示：`PRE_ACCUMULATION_RELEASE_PATH` 使用深紫色 4 px，并在趋势线中部显示 `积累前释放`；`STRUCTURE_LINE` 使用红色 2 px；`REVIEW_REQUIRED` 使用橙色 3 px、虚线样式并显示 `待复核`。部分 MT5 渲染环境可能把大于 1 px 的虚线显示成实线，因此 `待复核` 文字仍作为明确区分。
- 预览对象使用独立总前缀 `OPP_GEOMETRY_`，在托管 `OPP_DRAW_` 原始绘图全部重建后最后创建，以覆盖显示但不修改原对象的颜色、宽度、选择状态或正式语义。所有预览线和文字均不可选中、隐藏于对象列表、保持前景显示；tooltip 明确标记几何建议、置信度和“非持久化”。Experts 新增逐线 `preview line` 与 `mode=non_persistent_overlay_v1` 汇总，固定记录 `original_objects_changed=0 | semantic_fields_changed=0 | archive_touched=0`。
- 保存隔离采用双保险：`IsOpportunityDrawingInternalObject()` 把整个 `OPP_GEOMETRY_` 前缀视为内部对象，`保存结构` 扫描循环又直接按该前缀跳过。因此预览 `OBJ_TREND/OBJ_TEXT` 不进入 `opportunityDrawings[]`，不改变 D### 编号，不会在保存成功后作为人工原对象删除，也不会调用任何 CSV writer。预览清理复用托管绘图删除入口，覆盖 EA 卸载、清空图表、新建案例、空白草稿初始化、案例切换及失败回滚；下一次托管重绘会先清旧预览再重建。
- `Data/Local_Data/opportunity_annotations/README.md` 已同步 2.15 的颜色/粗细/标签、对象隔离、生命周期和日志语义。独立只读审查未发现编译阻断、档案污染或修改原线属性的路径；已记录 MT5 宽虚线可能显示为实线的视觉限制。
- 正式源码继续按“项目外 UTF-8 -> `apply_patch` -> 回写 CP936”流程修改，严格 CP936 编解码与字节往返通过；源码为 10,256 行、442,696 字节、大括号 830/830，项目与 `D:\mt5` Junction SHA256 均为 `6C2FF2BCF2A060904A05002A4DDA138F1C335ADD3F2B97F475B9941199E75540`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（6,593 ms）；EX5 为 429,894 字节，项目与 Junction SHA256 均为 `E2A241C714314262C6764952719238FA0616B723E41C3DF0BD651C916369F34C`。`git diff --check` 通过。
- 当前 MT5 PID 26352 仍运行 21:21:50 加载的 EA 2.14；编译不会热替换。用户需完整关闭 MT5 并从固定快捷方式重开，先确认 `EA INIT | ver=2.15`。随后重新打开 `EURUSD-2003-H1-CASE-006`，预期 `D002` 显示为明显的深紫色 4 px 并带 `积累前释放`，`D001/D003/D004` 显示为红色 2 px；Experts 应出现 `preview summary ... pre_release=1 | structure=3 | review=0 | failures=0 | archive_touched=0`。助手没有重启或操作 MT5，也没有创建 `ChartScreenShot`。

## Session Continuation (2026-08-12, EA 2.16 Cross-Year Display Cleanup)
- 用户截图并实机复现跨年显示 BUG：在查看 2003 正式案例后，从三级目录选择 2002 案例，2003 案例的部分结构点圆环和关键 K 线高亮仍保留在 2002 图表上；正式档案没有混写，属于托管显示对象残留。
- 2026-08-12 Experts 在 09:10:15 精确证明根因顺序：`SwitchOpportunityCase()` 将跨年选择委托给 `SwitchFullWorkYear()`；后者先通过 `PrepareOpportunitySessionForYear()` 把活动案例从 `EURUSD-2003-H1-CASE-001` 改为 `EURUSD-2002-H1-CHANNEL-001`，再调用 `ChartSetSymbolPeriod()`。随后旧实例执行 `deinit_3`，而 2.15 的 `DeleteOpportunityAnnotationObjects()` / drawings / regions 清理均按已经变更的当前案例前缀生成对象名，所以只能尝试删除 2002 前缀，漏掉仍在图表上的 2003 `OPP_ANNOT_` 位图结构点和关键 K 线框。
- `MT5_EnergyTrading.mq5` 已升级到 2.16。新增 `DeleteAllOpportunityDisplayObjects()`，不再依赖活动案例 ID，而是统一扫描并删除四类 EA 保留前缀：`OPP_ANNOT_`、`OPP_DRAW_`、`OPP_REGION_`、`OPP_GEOMETRY_`。位图对象继续通过 `DeleteOpportunityObjectWithResource()` 同时释放动态资源；用户原生绘图、FULL 控制面板、V4 会话标记以及正式 CSV 均不在清理范围。
- 全前缀清理已接入 FULL `OnDeinit()`，因此跨年度/品种或周期切换时旧实例无论当前活动 ID 已变成什么，都能删除旧案例全部托管图面；同时接入 FULL `OnInit()` 的档案加载前，用于在升级后第一次启动时自动清除已经遗留的旧年度对象，再仅按当前目标案例档案重绘。
- 新增 `[EA|FULL|DISPLAY] INFO/ERROR cleanup result` 日志，包含 `reason`、`matched/deleted/failed`、annotation/drawings/regions/geometry 分类计数、当前活动案例和固定 `archive_touched=0`。清理不调用任何 CSV writer；若对象删除失败会输出对象级错误和汇总 `ERROR`。
- 正式源码继续保持 CP936，严格字节往返通过；源码为 10,302 行、444,404 字节、大括号 832/832，项目与 `D:\mt5` Junction SHA256 均为 `5B60D8653F0C70FD62745547D1F4B8FE7B100F250383AEC3CCFB6F4B6D36AD73`。MetaEditor 正式编译结果为 `0 errors, 0 warnings`（7,559 ms）；EX5 为 431,856 字节，项目与 Junction SHA256 均为 `0511ACB86FEE0377ED3FFC1FA5542A2FA27870112249B2EC01E63C1329C140F8`；`git diff --check` 通过。
- 实现、文档和编译前后五份正式档案保持 cases/anchors/key bars/drawings/regions = 14/72/14/105/42 行；SHA256 分别为 `CE59DAF1A70944DA9B44C8B7836085E43C2E92A7102E34D01A4EC8EFA3C0309A`、`A618F2DE25039D7F7EF645A567C7B572FE4E50C16A0B1B5E7070389917F90B55`、`5211173E15A16DAF276BA8DDB7E0C3E74057145B6B0EEE132FAC4FF754E3193B`、`80A12DD379738CF19287F4949D5A31664A451917F6EAEEDCC3A9920931ADD8AF`、`0B68304885FFB176B94ACC1F042E3959E3BBF114413CE3755FFF7C1904864521`；事务备份数量为 0。
- 当前 MT5 PID 12772 仍运行 09:10:15 加载的 EA 2.15；正式编译不会热替换。用户需完整关闭并从固定快捷方式重开，先确认 `EA INIT | ver=2.16` 以及启动阶段 `cleanup result ... reason=full_init_preload | failed=0`。实机回归：先打开任一 2003 完整案例，再从目录打开任一 2002 案例；旧实例应出现 `cleanup result ... reason=full_deinit_3 | failed=0`，2002 初始化后只显示所选 2002 案例的结构点、关键 K 线、托管绘图、三区标签和几何预览，不得残留任何 2003 圆环或高亮框。再反向执行 2002 -> 2003 验证同一不变量，全过程必须保持 `archive_touched=0`。
- 安全约束继续有效：助手没有自动重启或操作 MT5 鼠标/键盘，没有创建或运行 `ChartScreenShot`，没有改写任何正式案例 CSV；跨年视觉结果仍由用户实机确认，助手只读取 Experts 和档案哈希。

## Last Updated
- 2026-08-12
