# 进度日志 (Progress Log)

## 会话: 2026-02-14 (管道分帧修复与批量同步)

### 核心功能落地 (Core Implementation)
- **管道分帧 (Pipe Framing)**:
  - 统一 Python 端指令为 `\n` 分隔，MT5 端增加 `rx_buffer` 行级拆包，解决 Batch 模式下多条 `ADD_BAR` 合并导致的 K 线断档问题。
- **批量模式稳定性**:
  - 增加重连时 `BATCH` 同步，确保切换周期/重启后 UI 与 Python 状态一致。
  - 完成批量按钮离线隐藏、点击更新与即时持久化，避免状态失效与错乱。
- **滑块边界修复**:
  - 速度滑块对齐轨道宽度，限制 knob 不出轨道，交互更稳定。
- **日志映射与可观测性**:
  - 将 MT5 官方日志通过 Junction 映射至项目 `logs/`，便于快速检索。
  - Python 发送日志加入 Speed 字段，关键信息一行可见。

### 关键决策 (Key Decisions)
- **协议优先**: 使用简单可靠的“换行分隔 + 行拆包”取代隐式消息边界，降低丢包与解析风险。
- **状态一致性**: 连接后主动同步 `SPEED` 与 `BATCH`，确保“UI 所见即服务端状态”。

## 会话: 2026-02-12 (极简主义 UI 重构与自动化生命周期)

### 核心功能落地 (Core Implementation)
- **极简 UI 重构 (Minimalist UI)**:
  - **视觉减负**: 彻底移除了红色 Launch 按钮和黄色 Connecting 提示，将所有功能收敛至单一的 Start/Pause 按钮。
  - **交互优化**: 修复了滑块判定区域过大导致的误触问题，收缩 Hitbox 至视觉精准范围。
  - **防误触**: 实现了 `CHART_MOUSE_SCROLL` 锁定机制，当鼠标在面板区域时自动禁用图表拖拽，防止“拖滑块带动 K 线图”。
- **功能增强**:
  - **批量加速 (Batch Mode)**: 在 UI 上新增了 `(x1)` 到 `(x10)` 的步进控制器，允许 Python 每次唤醒发送多根 K 线，极大提升了回放速度上限。
  - **交互设计**: 采用了“双按钮模拟单按钮”设计 (Split-Click)，左半边减、右半边加，解决了右键兼容性问题。
- **自动化生命周期 (Auto-Lifecycle)**:
  - **Auto-Launch**: 在 EA `OnInit` 中实现自动检测并启动 Python 数据源，实现“零操作启动”。
  - **Auto-Kill**: 在 Python 端实现“自杀契约”，一旦检测到管道断开 (Broken Pipe)，进程立即自我终结。
  - **无缝退出**: 移除了 `launch_feed.bat` 中的 `pause` 命令，确保 Python 退出时 CMD 窗口瞬间消失，不留残余。
- **数据持久化**:
  - **双重保险**: 实现了“松开滑块即保存” + “关机再保存”的双重持久化策略，确保速度设置永不丢失。
  - **全局拖动**: 修复了滑块“脱轨”问题，实现了全屏幕范围的拖动捕获。

### 关键决策 (Key Decisions)
- **去中间化**: 虽然保留了 `.bat` 作为配置缓冲，但明确了 Python 脚本应具备独立生命周期管理能力，不依赖外部 Runner 的干预。
- **UI 哲学**: 确立了 "One Button" (单一入口) 原则，将连接、重连、启动、播放全部合并为一个按钮逻辑，大幅降低用户认知负担。
- **模型升级准备**: 配置了本地 `.codex` 环境以支持 GPT-5.3 CLI 调用，确立了 "Agent-based Development" (架构师+编码者) 的未来工作流。

## 会话: 2026-02-11 (数据同步与稳健性增强)

### 核心功能落地 (Core Implementation)
- **数据源增强**:
  - **M1 数据获取**: 修复了 `export_m1_data.py`，确认在线历史数据限制，全面转向使用本地高质量 M1 数据 (`Data/Local_Data/split_by_year/EURUSD_2024.csv`)。
  - **智能加载**: 升级 `feed_replay.py`，支持自动识别 Header（在线数据）和无 Header（本地数据）格式，实现无缝切换。
- **同步机制重构 (Sync V3.0)**:
  - **主动握手 (Proactive Handshake)**: 修改 MT5 EA，使其在连接管道成功后**立即、主动**发送 `STATUS|time` 消息。
  - **双模同步 (Dual-Mode Sync)**: Python 端实现了“被动等待握手 (5s) + 主动查询重试 (5次)”的双重保障机制，彻底解决了启动时的竞态条件和超时问题。
- **UI 状态修复**:
  - 修复了切换时间周期 (Timeframe Change) 时，EA 错误重置为 "LAUNCH" 状态的 Bug，现在只在真正断开连接时重置。

### 关键决策 (Key Decisions)
- **本地数据优先**: 鉴于模拟账户获取历史数据的限制，决定以本地清洗过的 CSV 数据作为唯一可信数据源 (Source of Truth)。
- **检查点机制 (Proposed)**: 发现依赖 MT5 图表状态作为进度依据不可靠（图表可能被重置），决定引入 `replay_state.json` 文件作为独立的中立进度记录。

## 会话: 2026-02-03 (MT5 UI 交互控制面板开发)

### 核心功能落地 (Core Implementation)
- **UI 控制面板 (Control Panel)**:
  - **组件**: 在 MT5 图表左上角实现了包含 **播放/暂停按钮** 和 **速度滑块** 的控制面板。
  - **交互逻辑**: 
    - **按钮**: 实现了点击切换状态 (PLAYING/PAUSED) 及颜色反馈 (绿/红)。
    - **滑块**: 实现了拖动滑块实时调整速度数值 (0.5s - 3.0s)。
    - **拖动**: 实现了整个面板的自由拖动，解决了遮挡 K 线的问题。
  - **位置记忆**: 利用 `GlobalVariable` 实现了面板位置的自动保存与恢复，重启 EA 后面板会自动出现在上次停留的位置。
- **代码优化**:
  - **逻辑修正**: 修正了按钮点击逻辑，使其符合“显示当前状态”的直觉。
  - **硬编码默认值**: 根据用户反馈，将面板默认位置固定为 (6, 20)。

## 会话: 2026-02-02 (MT5 自动化复盘环境落地与项目治理)

### 核心功能落地 (Core Implementation)
- **实时行情投喂 (Real-time Feed)**:
  - **Python 端**: 创建了 `feed_replay.py`，读取 2024 年 H1 数据，每 3 秒通过管道发送一条 `ADD_BAR` 指令。
  - **MT5 端**: 在 `MT5_EnergyTrading.mq5` 中实现了 `ADD_BAR` 解析和 `AddBarToChart` 函数，使用 `CustomRatesUpdate` 动态更新图表。
- **EA 架构修正**:
  - **脚本 vs EA**: 明确了项目性质为 EA (Expert Advisor)，修正了文件放置位置。
  - **远程控制模式**: 确立了 "Launcher (启动台) -> Target (目标图表)" 的控制模式，解决了 EA 在新图表上无法自动挂载的问题。
  - **空图表初始化**: EA 现在只初始化一根 Dummy Bar，随后的数据全靠 Python 投喂，完美模拟实盘环境。
- **项目治理 (Project Governance)**:
  - **版本控制**: 建立了 Git 仓库，配置了 `.gitignore`，清理了 9000+ 个垃圾文件。
  - **分支策略**: 建立了 `main` (稳定版) 和 `feature/draw-engine` (开发版) 双分支结构。
  - **代码清理**: 移除了 `VisualReplay_MVP` 目录下 12 个冗余的测试脚本，保持项目整洁。

### 错误修复 (Bug Fixes)
- **MT5 64位崩溃 (Critical)**: 发现并修复了 `kernel32` 导入时使用 `int` 存储 64位句柄导致的内存崩溃问题，全部升级为 `long`。
- **单窗口跳转**: 实现了 EA 自动创建 `EURUSD@_2024` -> 打开新窗口 -> 关闭旧窗口 -> 新窗口自动加载模板 (含 EA) 的完整闭环，达成了“单窗口纯净体验”。
- **Git 索引爆炸**: 修复了 `.gitignore` 漏写导致 IDE 试图索引 9000+ 个文件的问题。

## 会话: 2026-02-01 (MT5 自动化复盘环境落地)

### 架构转型落地 (Architecture Implementation)
- **从 Python GUI 转向 MT5 Bridge**: 
  - 放弃 `lightweight-charts`，确立 **"Python (Brain) + MT5 (Screen)"** 的双核架构。
  - 利用 Python 处理数据清洗和算法逻辑，利用 MT5 强大的原生图表能力进行展示。

### 核心功能开发 (Core Features)
- **MT5 桥接环境搭建**:
  - **通信层**: 实现了基于 Named Pipe (命名管道) 的双向通信 (`MT5_Python_Bridge`)。
  - **EA 开发**: 编写并迭代了 `MT5_EnergyTrading.mq5`，实现了指令解析 (`VLINE`, `SET_RANGE`)。
- **自动化流程闭环 (One-Click Experience)**:
  - **自定义品种**: 实现了 `EURUSD@_2024` 的自动创建与数据注入，彻底隔离历史数据干扰。
  - **单窗口模式**: 实现了启动台图表的自动关闭和新图表的自动弹出，保持测试环境整洁。
  - **模板联动**: 实现了 `ChartApplyTemplate` 自动加载 `红绿入场.tpl`，确保指标和颜色配置一步到位。
  - **交互控制**: 编写了 `interactive_replay.py` MVP，实现了键盘控制的时间跳转。

### 关键决策 (Key Decisions)
- **集成化部署**: 废弃独立的脚本文件，将所有功能集成到单一 EA 中，降低操作复杂度。
- **命名规范**: 统一使用 `EURUSD@_2024` 以匹配用户交易商后缀习惯。
- **半自动挂载**: 鉴于 MT5 安全限制，采用“模板加载+手动确认/提示”的方式解决 EA 挂载问题，平衡了自动化与稳定性。

## 会话: 2026-01-29 (形态理论内化与验证架构升级)

### 理论体系内化 (Theory & Data)
- **黄金标准提取**: 从 PDF 中精准提取并清洗了“爱思潘三角形”的几何定义（角度、时间比、收敛结构），建立 [`triangle_standards.md`](../../docs/System_Architecture/Opportunity_Recognition/Triangle_Pattern_Recognition/triangle_standards.md)。
- **数据标准化**: 
  - 删除了冗余和错误的 OCR 文本，确保理论纯度。
  - 重构了 `images/` 目录，建立了标准化的 `Examples/` (实战案例) 和 `Standard/` (理论模型) 结构。
  - 统一了图片命名规范 (YYYYMM-NN-Market.png)。

### 验证方法论升级 (Validation Methodology)
- **风险识别**: 确认 ZigZag 算法的“重绘”特性和 chart_patterns 库的不可靠性。
- **架构决策**:
  - 确立了 **“可视化行情回放器 (Visual Market Replayer)”** 的核心地位。
  - 决定采用“所见即所得”的单步调试模式，替代传统的黑盒回测。
  - **原则**: 任何形态识别算法必须经过 Replayer 的“肉眼验证”方可实盘。

### 基础设施准备 (Infrastructure)
- **调研计划**: 制定了使用 Manus 调研 Python 可视化复盘库 (如 finplot/backtrader) 的 Prompt。
- **项目管理**: 更新了 `task_plan.md`，明确了 Phase 1.5 的数据准备和复盘器构建任务。

## 会话: 2026-01-28 (技能系统 V2.0 升级)

### 技能加载器升级 (Skill Loader V2.0)
- **API 集成 (SkillsMP)**: 
  - 成功集成 SkillsMP API，打通了通向 **100,000+** 全球技能库的通道。
  - 实现了 Local Index (本地) + Remote API (云端) 的混合搜索机制。
- **架构重构**: 
  - 确立了“宽进严出”原则 (Wide In, Strict Out)。
  - 引入了“机械层 (M) 与智能层 (I) 分离”的设计模式。
- **功能增强**:
  - `search`: 支持多关键词，返回 Top 10 混合结果。
  - `fetch`: 升级为只提示路径，不刷屏；增加了 `requirements.txt` 依赖检测警告。
  - `install`: 新增长期安装功能，支持将技能提升至 `src/skills_system/installed/` 并自动生成 `__init__.py`。
  - `remove`: 新增回滚命令。
- **文档规范**: 
  - 全面更新了 `SKILL.md` (中文版)，定义了 Workflow 3.0。
  - 在 `task_plan.md` 中引入了 `[M]/[I]/[H]` 类型标记和 `[T]` 测试标记。

### 记忆架构重构 (Memory Architecture Refactoring)
- **从全量加载转向按需检索 (RAG)**: 解决了 Context Window 限制与知识增长的矛盾。
- **实施方案**:
  - 创建了 `docs/Agent_Core/MEMORY_INDEX.md` 作为唯一启动入口。
  - 将 `core_memory.json` (人格) 与 `MEMORY_INDEX.md` (知识) 分离。
  - 整理了 `docs/` 目录结构 (Agent_Core, References, Manuals)。
- **Core Memory 更新**: 修改了 `Session Start Protocol` 和 `Activation Phrase` 以适配新架构。

## 会话: 2026-01-24 (基础设施搭建与初期规划)

### 基础设施搭建 (Infrastructure Setup)
- 验证了项目目录结构。
- 创建了 `requirements.txt`。
- 实现了 `src/skills_system/loader.py`。
- 创建了 `skills_index.json`。

### 技能系统扩展 (Skill System Expansion)
- 创建了 `src/skills_system/scripts/scan_collections.py` 以自动化技能发现。
- 扫描并索引了:
  - `openai/skills`
  - `huggingface/skills`
  - `skillcreatorai/Ai-Agent-Skills`
  - `K-Dense-AI/claude-scientific-skills` (科学工具)
  - `sickn33/antigravity-awesome-skills` (工程最佳实践)
  - `SKE-Labs/agent-trading-skills` (交易策略)
- 修复了 `src/skills_system/scripts/scan_collections.py` 中的 Windows 权限 Bug。

### 规划系统 (Planning System)
- 采用了 `planning-with-files` 技能方法论。
- 创建了 `ProjectPlan/task_plan.md` (中文版) 以追踪进度。
- 创建了 `ProjectPlan/findings.md` (中文版) 和 `ProjectPlan/progress.md` (中文版)。
- 内化了 "爱思潘交易系统" 理论并创建了 `src/strategies/Aspen_Energy_System/energy_theory_notes.md`。
- 创建了 "生活重启协议" 文档 `src/strategies/LifeReset_Project/life_reset_protocol.md`。

### 理论内化 (Theory Ingestion)
- 读取并分析了 `docs/爱思潘交易系统.pdf`。
- 提取了核心交易逻辑：能量状态 (释放/积累)、旗形识别规则、50% 中位止损规则。
