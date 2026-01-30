# 任务计划: 量化交易模型开发 (Quantitative Trading Model Development)

## 目标
构建一个基于模式识别（ZigZag/DTW）和结构分析的自动化量化交易系统，并集成 Agent Skills 系统以增强数据分析和决策能力。

## 当前阶段
Phase 1.5 (系统设计与理论内化)

## 阶段列表

### 第一阶段: 环境与技能基础设施 (Phase 1)
- [x] 创建项目结构 (src, docs, data, legacy)
- [x] 设置虚拟环境和 requirements.txt
- [x] 实现技能加载器 (Skill Loader) (src/utils/skill_loader.py)
- [x] 创建技能索引 (Skills Index) (skills_index.json)
- [x] 实现仓库扫描器 (Repo Scanner) (scan_collections.py)
- [x] 集成社区技能库 (Community Skills)
- [x] 集成科学计算技能库 (Scientific Skills - K-Dense-AI)
- [x] 集成工程与反重力技能库 (Antigravity Skills - sickn33)
- [x] 集成交易技能库 (Trading Skills - SKE-Labs)
- [x] 升级技能系统以兼容 SkillsMP 网站标准
    - [x] **调研与设计**: 验证 SkillsMP API 结构，确立“Agent拆解+混合搜索+双重验证”流程。
    - [x] **核心流程验证 (Core Workflow)**:
        - [x] [A] [M] [T] 集成 API Key (`sk_live_...`) @skill_loader.py
        - [x] [A] [M] [T] 实现混合搜索逻辑 (Local Index + Remote API) @skill_loader.py
        - [x] [A] [H] [T] **宽进严出**: Top 10 召回 + 完整描述展示 @skill_loader.py
        - [x] [A] [M] [T] 升级 `fetch` 支持直接 URL 下载 @skill_loader.py
        - [x] [B] [M] [T] 实现“下载后仅提示路径” @skill_loader.py
    - [x] **附加功能验证 (Advanced Features)**:
        - [x] [B] [M] [T] **依赖管理**: `requirements.txt` 警告 @skill_loader.py
        - [x] [B] [M] [T] **长期安装**: `install` 命令 + 自动 `__init__.py` @skill_loader.py
        - [x] [C] [M] [T] 新增 `remove` 回滚命令 @skill_loader.py
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
        - [ ] **可视化复盘器调研**: 使用 Manus 寻找支持单步调试和动态绘图的 Python 库 (finplot, lightweight-charts 等)。
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
- [ ] [A] [M] **构建可视化行情回放器 (Visual Market Replayer MVP)**
        - [ ] **目标**: 模拟复盘大师/MT4 体验，支持单步调试，实现“所见即所得”的算法验证。
        - [ ] 实现 CSV 数据加载与步进器 (Step-by-Step Iterator)
        - [ ] **可视化控制台 (Visual Console)**:
            - [ ] 使用 `matplotlib` 交互模式实现动态 K 线绘图
            - [ ] 实时叠加 ZigZag 连线与形态标注 (验证防重绘逻辑)
            - [ ] 添加交互控制: [下一步], [暂停], [快进]
    - [ ] **机械层 (Mechanical Layer)**:
        - [ ] 集成 `jbn/ZigZag` 实现实时计算可视化
        - [ ] 集成 `chart_patterns` 实现初步形态筛选 (Flag/Triangle)
    - [ ] **智能层 (Intelligent Layer)**:
        - [ ] 设计 Prompt 模板: 注入形态截图/坐标 + 趋势背景
        - [ ] 实现 LLM 接口: 调用 Agent 进行二次确权 (Valid/Invalid)
    - [ ] 验证 ZigZag 重绘现象与防重绘逻辑
- **状态:** 进行中 (in_progress)

### 第二阶段: 数据与核心策略迁移 (Phase 2)
- [ ] 实现数据加载器 (src/data_loader/) - 支持 CSV & CCXT
- [ ] 从旧代码迁移 ZigZag 算法
- [ ] 迁移 DTW/模式匹配逻辑
- [ ] 实现基础绘图/可视化工具
- **状态:** 待定 (pending)

### 第三阶段: 回测引擎 (Phase 3)
- [ ] 设计事件驱动或向量化回测引擎
- [ ] 实现交易管理 (入场, 出场, 止损, 止盈)
- [ ] 实现性能指标 (夏普比率, 最大回撤, 胜率)
- [ ] 可视化回测结果
- **状态:** 待定 (pending)

### 第四阶段: Agent 集成与优化 (Phase 4)
- [ ] 集成科学技能进行数据分析 (EDA, 统计)
- [ ] 实现基于 Agent 的 "智能研报" 生成
- [ ] 优化策略参数 (使用 pymoo 或类似工具)
- **状态:** 待定 (pending)

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

## 遇到的错误 (Errors Encountered)
| 错误 | 尝试次数 | 解决方案 |
|-------|---------|------------|
| PermissionError (shutil.rmtree) | 1 | 添加重试逻辑和 `os.chmod` 以处理 Windows 下仓库扫描时的文件锁定问题。 |
| pip install pypdf 路径错误 | 1 | 使用 `python -m pip` 替代直接调用 `pip`，确保安装到当前虚拟环境。 |

## 7. Changelog
- **2026-01-29**: Added "Visual Market Replayer" decision and updated Phase 1.5 tasks with triangle pattern standardization.
- **2026-01-28**: Updated Phase 1 with skill system V2.0 details.

## 备注 (Notes)
- 随着进度更新阶段状态：pending (待定) → in_progress (进行中) → complete (已完成)
- 在做重大决定前重读此计划 (注意力管理)
- 记录所有错误 - 它们有助于避免重复
