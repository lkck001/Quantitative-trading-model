# 任务计划: 量化交易模型开发 (Quantitative Trading Model Development)

## 目标
构建一个基于模式识别（ZigZag/DTW）和结构分析的自动化量化交易系统，并集成 Agent Skills 系统以增强数据分析和决策能力。

## 当前阶段
Phase 1.5 (系统设计与理论内化)

## 阶段列表

### 第一阶段: 环境与技能基础设施 (Phase 1)
- [x] 创建项目结构 (src, docs, data, legacy)
- [x] 设置虚拟环境和 requirements.txt
- [x] 实现技能加载器 (Skill Loader) (src/skills_system/loader.py)
- [x] 创建技能索引 (Skills Index) (skills_index.json)
- [x] 实现仓库扫描器 (Repo Scanner) (src/skills_system/scripts/scan_collections.py)
- [x] 集成社区技能库 (Community Skills)
- [x] 集成科学计算技能库 (Scientific Skills - K-Dense-AI)
- [x] 集成工程与反重力技能库 (Antigravity Skills - sickn33)
- [x] 集成交易技能库 (Trading Skills - SKE-Labs)
- [x] 升级技能系统以兼容 SkillsMP 网站标准
    - [x] **调研与设计**: 验证 SkillsMP API 结构，确立“Agent拆解+混合搜索+双重验证”流程。
    - [x] **核心流程验证 (Core Workflow)**:
        - [x] [A] [M] [T] 集成 API Key (`sk_live_...`) @src/skills_system/loader.py
        - [x] [A] [M] [T] 实现混合搜索逻辑 (Local Index + Remote API) @src/skills_system/loader.py
        - [x] [A] [H] [T] **宽进严出**: Top 10 召回 + 完整描述展示 @src/skills_system/loader.py
        - [x] [A] [M] [T] 升级 `fetch` 支持直接 URL 下载 @src/skills_system/loader.py
        - [x] [B] [M] [T] 实现“下载后仅提示路径” @src/skills_system/loader.py
    - [x] **附加功能验证 (Advanced Features)**:
        - [x] [B] [M] [T] **依赖管理**: `requirements.txt` 警告 @src/skills_system/loader.py
        - [x] [B] [M] [T] **长期安装**: `install` 命令 + 自动 `__init__.py` @src/skills_system/loader.py
        - [x] [C] [M] [T] 新增 `remove` 回滚命令 @src/skills_system/loader.py
    - [x] **协议更新 (SKILL.md) - [I] 智能层定义**:
        - [x] [B] [I] [T] Agent 责任定义 (关键词拆解/语义比对/强制审核) @SKILL.md
        - [x] [C] [I] [T] **反模式警告**: 区分“探讨模式”与“执行模式” @SKILL.md
        - [x] [C] [I] [T] **失败反馈**: remove 后记录 Core Memory @SKILL.md
- [x] [A] [I] **设计记忆索引机制 (Memory Indexing Mechanism)** @docs/Agent_Core/MEMORY_INDEX.md
    - [x] 阶段一: 层级化索引 (Hierarchical Indexing) - 创建 `MEMORY_INDEX.md`
- **状态:** 已完成 (complete)

### 第 1.5 阶段: 调研与系统设计 (Phase 1.5: Research & Design)
- [x] 内化 "爱思潘交易系统" (能量交易理论) PDF
- [x] 分析 "交易流程图" (图 11-1)
- [x] 将理论映射到系统架构 (ProjectPlan/energy_theory_notes.md)
- [x] [A] [I] **设计记忆索引机制 (Memory Indexing Mechanism)** @docs/Agent_Core/MEMORY_INDEX.md
    - [x] 阶段一: 层级化索引 (Hierarchical Indexing) - 创建 `MEMORY_INDEX.md`
    - [ ] 阶段二: 向量化记忆 (Vector Memory)
    - [ ] 阶段三: 自动化摘要 (Auto-Summarization)
    - [x] **文档规范化 (Documentation Standardization)** @docs/Manuals/documentation_standards.md
        - [x] 引入 ADR (架构决策记录) 模板
        - [x] 引入 Changelog 标准格式
        - [x] 引入 AI 友好文档 (llms.txt) 概念
- [ ] [A] [I] **开源项目深度调研 (Open Source Research)**
        - [x] 使用 Manus AI 调研三大痛点: ZigZag 防重绘、形态识别算法、MT4-Python 桥接 (ZeroMQ)
        - [x] 分析报告: 筛选 Top 3 可用库并制定集成方案 @docs/References/opensource_research_report.md
        - [x] **可视化复盘器调研 (Visual Replayer Research)**: 
        - [x] **任务**: 使用 Manus 寻找支持单步调试和动态绘图的 Python 库 (finplot, lightweight-charts 等)。
        - [x] **目标**: 寻找能完美复刻 MT4/复盘大师体验的开源方案。-> 选中 `lightweight-charts-python`。
        - [x] **Pivot (战略转型)**: 发现 Python GUI 库无法满足“可控复盘”需求，转向 **MT5 桥接方案**。
- [ ] [A] [I] **构建可视化行情回放器 (Visual Market Replayer MVP)**
    - [x] **架构重构**: 放弃 `lightweight-charts`，采用 **Python (Brain) + MT5 (Screen)** 架构。
    - [x] **技术验证**:
        - [x] 验证 Python `MetaTrader5` 库连接实盘 (Success)。
        - [x] 验证 Named Pipe (命名管道) 通信 (Success)。
        - [x] 建立 MQL5 <-> VS Code 实时同步开发环境 (Success)。
    - [x] **EA 基础建设**:
        - [x] 创建 `MT5_EnergyTrading` EA。
        - [x] 实现管道通信与指令解析 (`VLINE`, `SET_RANGE`, `MSG`)。
        - [x] 实现实时行情投喂指令 (`ADD_BAR`)。
        - [x] **EA 架构修正**:
             - [x] [A] [H] [T] **64位句柄修复**: 修复 `kernel32` 导入导致的内存崩溃。
             - [x] [A] [H] [T] **单窗口跳转**: 实现 EA 自动创建 `EURUSD@_2024` 并自我迁移。
             - [x] [B] [M] [T] **纯净模式**: 移除 Launcher，保持单一图表运行。
             - [x] [A] [H] [T] **UI 控制面板**: 实现播放/暂停按钮、速度滑块及位置记忆功能。
            - [x] [A] [H] [T] **UI 交互优化**:
                - [x] **面板锁定**: 移除面板拖动功能，防止误触。
                - [x] **滑块优化**: 扩大滑块响应区域 (Hitbox) 并加宽滑块。
                - [x] **滑块边界修复**: 轨道宽度一致化并限制 knob 不越界。
                - [x] **即时持久化**: 实现滑块释放即保存 (Immediate Save) 及 `GlobalVariablesFlush`。
                - [x] [C] [H] [T] **极简 UI 重构**: 移除冗余面板，实现 Start/Pause 单一入口逻辑。
                - [x] [C] [H] [T] **防误触锁定**: 实现 UI 区域禁用图表拖拽 (`CHART_MOUSE_SCROLL`)。
                - [x] [C] [H] [T] **批量加速模式**: 增加 `(x1-x10)` 步进按钮，支持单次唤醒发送 N 根 K 线，提升回放效率。
                - [x] **批量按钮稳定性**: 离线隐藏、点击更新、持久化、重连同步，确保 UI/后端一致。
        - [x] **生命周期自动化**:
             - [x] **Auto-Launch**: EA 启动时自动拉起 Python 数据源。
             - [x] **Auto-Kill**: 管道断开时 Python 自动退出，无残留。
        - [x] **同步机制增强 (Sync V3.0)**:
             - [x] **主动握手 (Proactive Handshake)**: MT5 连接后立即发送 `STATUS`。
             - [x] **双模同步 (Dual-Mode)**: Python 支持被动等待握手 + 主动重试查询。
             - [x] **M1 精度修复**: 修正时间帧锚点，由 H1 切换为 M1，解决分钟级回放进度丢失问题。
             - [x] **管道分帧 (Pipe Framing)**: 指令统一换行分隔，MT5 端行级拆包，解决批量合并丢包。
        - [ ] 实现高级绘图指令 (`DRAW_LINE`, `ZIGZAG`)。
    - [ ] **Python 控制台开发**:
        - [x] 编写 `feed_replay.py` 实现 M1 K线投喂模拟。
        - [x] 实现数据源自动切换 (Online/Local) 与格式兼容。
        - [x] ~~**持久化同步**: 实现 `replay_state.json` 检查点机制~~ (已废弃: 采用 MT5 自身数据/主动握手作为单一事实来源)
        - [x] **指令分隔**: 发送端统一追加 `\n`，确保批量指令可正确拆包。
        - [x] **日志增强**: 发送日志增加 `Speed` 字段，便于诊断性能与节奏。
        - [ ] 实现 ZigZag 算法与 MT5 绘图指令的实时映射。
    - [x] **项目治理 (Project Governance)**:
        - [x] [A] [M] [T] **Git 初始化**: 建立版本控制，配置 `.gitignore`。
        - [x] [A] [M] [T] **代码清理**: 移除 `VisualReplay_MVP` 下的 10+ 个冗余脚本。
        - [x] [B] [M] [T] **分支策略**: 建立 `main` (稳定) + `feature/draw-engine` (开发) 双分支。
    - [ ] **全流程联调**:
        - [ ] 在 MT5 策略测试器中跑通 "Python 指挥 -> MT5 画线 -> 暂停 -> 下一步" 的完整闭环。
- [ ] [A] [I] **构建历史问题解决库 (Solution Bank Construction)**
    - [ ] [M] 创建 `docs/Agent_Core/solution_bank.json` 并初始化
    - [ ] [M] 实现写入脚本 `record_solution.py` 和读取脚本 `search_solution.py`
    - [ ] [I] 录入首批关键技术决策 (MT4桥接方案, ZigZag回测原则)
- [ ] [A] [H] **核心架构设计 (Core Architecture Design)**
    - [x] 确定回测引擎方案 (自定义轻量级 vs vn.py) -> 决定采用“自定义轻量级回测引擎”
    - [x] 设计机会识别子系统 (Opportunity Recognition Subsystem) @docs/System_Architecture/Opportunity_Recognition/hybrid_recognition_design.md
        - [x] 确立“机械筛选+智能决策”混合架构
        - [x] **三角形形态理论内化与数据准备 (Triangle Pattern Theory & Data Prep)** @docs/System_Architecture/Opportunity_Recognition/Triangle_Pattern_Recognition/triangle_standards.md
            - [x] 提取并标准化形态理论 (上三/下三定义、规则与算法清单)
            - [x] 建立标准形态与实例图像库 (Standard Structure & Example Database)
            - [x] 标准化图像命名规范 (YYYYMM-NN-Market.png)
    - [ ] 设计状态机 (StateMachine) 逻辑: 能量释放 -> 积累 -> 触发
    - [ ] 制定数据流标准 (Data Flow Standard): MT4 -> ZMQ -> Python
- **状态:** 进行中 (in_progress)

### 第二阶段: 数据与核心策略迁移 (Phase 2)
- [ ] 实现数据加载器 (src/data_loader/) - 支持 CSV & CCXT
- [ ] 从旧代码迁移 ZigZag 算法
- [ ] 迁移 DTW/模式匹配逻辑
- [ ] 实现基础绘图/可视化工具
- [ ] **状态:** 待定 (pending)

### 第三阶段: 回测引擎 (Phase 3)
- [ ] 设计事件驱动或向量化回测引擎
- [ ] 实现交易管理 (入场, 出场, 止损, 止盈)
- [ ] 实现性能指标 (夏普比率, 最大回撤, 胜率)
- [ ] 可视化回测结果
- [ ] **状态:** 待定 (pending)

### 第四阶段: Agent 集成与优化 (Phase 4)
- [ ] 集成科学技能进行数据分析 (EDA, 统计)
- [ ] 实现基于 Agent 的 "智能研报" 生成
- [ ] 优化策略参数 (使用 pymoo 或类似工具)
- [ ] **状态:** 待定 (pending)

## 关键问题 (Key Questions)
1. 我们应该使用现有的回测框架 (Backtrader/Lean) 还是构建自定义的轻量级框架？ (决定：首先自定义轻量级框架，以便灵活处理 ZigZag 形态)
2. 如何无缝处理实时数据与历史数据？

## 已做决策 (Decisions Made)
| 决策 | 理由 |
|----------|-----------|
| **构建可视化行情回放器 (Visual Market Replayer)** | 解决形态识别算法的“重绘”与“黑箱”问题，实现所见即所得的算法验证。 |
| 使用技能加载器架构 (Skill Loader Architecture) | 允许在不臃肿代码库的情况下动态加载能力；保持 Agent 灵活。 |
| 混合技能源 (Hybrid Skill Sources) | 集成社区、科学、工程和交易技能，为开发和分析提供全面的工具集。 |
| 自定义文件规划 (Custom File-Based Planning) | 使用 `task_plan.md` (Manus 风格) 追踪进度，防止跨会话丢失上下文。 |
| 严格执行协议 (Strict Execution Protocol) | 在未得到用户明确指令前，仅进行探讨，不执行代码修改。 |
| 按需检索记忆 (On-Demand Memory Retrieval) | 从全量加载转向 `MEMORY_INDEX.md` 索引检索，解决 Token 消耗与注意力分散问题。 |
| **MT5 桥接架构 (Bridge Architecture)** | 采用 Named Pipe 通信，EA 负责展示，Python 负责计算。避免了 Python GUI 开发的复杂度。 |
| **单窗口体验 (Single Window UX)** | 通过 EA 自我迁移逻辑，实现 Launcher -> Target 的无缝切换，保持界面整洁。 |
| **主动握手协议 (Proactive Handshake)** | MT5 连接后主动发送状态，替代 Python 轮询，解决同步延迟和竞态条件。 |

## 遇到的错误 (Errors Encountered)
| 错误 | 尝试次数 | 解决方案 |
|-------|---------|------------|
| PermissionError (shutil.rmtree) | 1 | 添加重试逻辑和 `os.chmod` 以处理 Windows 下仓库扫描时的文件锁定问题。 |
| pip install pypdf 路径错误 | 1 | 使用 `python -m pip` 替代直接调用 `pip`，确保安装到当前虚拟环境。 |
| **MT5 64位句柄崩溃** | 1 | 将 EA 中所有 Kernel32 API 调用的 `int` 类型升级为 `long`，解决内存地址截断问题。 |
| **MT5 同步失败 (Sync Timeout)** | 3 | 从“被动查询”升级为“主动握手 + 双模重试”，并增加超时时间。 |

## 7. Changelog
- **2026-02-14**: [Stability] Fixed batch-mode command framing with newline + MT5 line parsing; Synced batch on reconnect; Slider clamp to track; Python send logs include speed; Mapped MT5 logs into project for faster diagnostics.
- **2026-02-12**: [Feature] Implemented "Batch Mode" (x1-x10 speed) with UI controls and persistence; Fixed UI initialization bugs (Forward Declaration); Integrated CodexZH config for GPT-5.3 CLI access.
- **2026-02-12**: [UI/UX] Refactored to "Minimalist" UI (One-Button Start); Implemented Auto-Launch/Auto-Kill lifecycle; Fixed Slider Hitbox & Drag-Lock; Added Chart Scroll Lock.
- **2026-02-12**: Polished MT5 UI (Locked Panel, Wider Slider, Hitbox Fix); Implemented "Immediate Save" for speed settings; Fixed M1 playback sync precision; Established `!` discussion protocol.
- **2026-02-11**: Implemented "Proactive Handshake" protocol for instant sync; Updated `feed_replay.py` to support dual-mode sync; Validated local M1 data replay.
- **2026-02-03**: Implemented MT5 UI Control Panel (Play/Pause/Speed Slider) with position memory; Fixed button logic and drag interaction.
- **2026-02-02**: Implemented MT5 Bridge MVP (Named Pipe), Fixed 64-bit crash, Established Git & Single Window UX.
- **2026-01-29**: Added "Visual Market Replayer" decision and updated Phase 1.5 tasks with triangle pattern standardization.
- **2026-01-28**: Updated Phase 1 with skill system V2.0 details.

## 备注 (Notes)
- 随着进度更新阶段状态：pending (待定) → in_progress (进行中) → complete (已完成)
- 在做重大决定前重读此计划 (注意力管理)
- 记录所有错误 - 它们有助于避免重复
