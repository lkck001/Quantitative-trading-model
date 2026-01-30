# Memory Index (记忆索引)

> **Protocol**: Agent 在启动 Session 时，**仅**读取此索引文件。根据任务需求，通过文件路径按需加载具体文档。

## 1. 项目规划 (Project Planning)
| 文件路径 | 摘要/用途 | 关键标签 |
| :--- | :--- | :--- |
| [`docs/System_Architecture/Opportunity_Recognition/hybrid_recognition_design.md`](../../docs/System_Architecture/Opportunity_Recognition/hybrid_recognition_design.md) | **[核心]** 机会识别子系统设计文档 (算法粗筛+AI确权)。 | Design, Architecture, ZigZag, AI |
| [`ProjectPlan/task_plan.md`](../../ProjectPlan/task_plan.md) | **[核心]** 项目总任务队列、阶段状态与待办事项。启动必读。 | Plan, Status, Todo |
| [`ProjectPlan/progress.md`](../../ProjectPlan/progress.md) | **[核心]** 每日工作日志、已完成事项验证与决策记录。 | Log, History, Decisions |
| [`ProjectPlan/findings.md`](../../ProjectPlan/findings.md) | 技术调研结果、错误解决方案与临时发现。 | Research, Errors, Notes |

## 2. 策略与理论 (Strategies & Theory)
| 文件路径 | 摘要/用途 | 关键标签 |
| :--- | :--- | :--- |
| [`src/strategies/Aspen_Energy_System/energy_theory_notes.md`](../../src/strategies/Aspen_Energy_System/energy_theory_notes.md) | **[核心]** 爱思潘能量系统理论笔记。定义了“释放/积累”状态与旗形规则。 | Theory, Aspen, Energy, Patterns |
| [`docs/System_Architecture/Opportunity_Recognition/Triangle_Pattern_Recognition/triangle_standards.md`](../../docs/System_Architecture/Opportunity_Recognition/Triangle_Pattern_Recognition/triangle_standards.md) | **[核心]** 三角形形态标准文档 (上三/下三图解、特征与算法清单)。 | Theory, Triangle, Pattern, Standards |
| [`src/strategies/LifeReset_Project/life_reset_protocol.md`](../../src/strategies/LifeReset_Project/life_reset_protocol.md) | 生活重启协议与执行标准。 | Protocol, Life |

## 3. Agent 核心 (Agent Core)
| 文件路径 | 摘要/用途 | 关键标签 |
| :--- | :--- | :--- |
| [`docs/Agent_Core/AGENT_MEMORY.md`](AGENT_MEMORY.md) | 定义了 Agent 的记忆架构、存储格式与更新协议。 | Memory, Architecture, System |
| [`docs/Agent_Core/core_memory.json`](core_memory.json) | (数据文件) 存储结构化的用户偏好与项目关键事实。 | JSON, Database |

## 4. 技能系统 (Skill System)
| 文件路径 | 摘要/用途 | 关键标签 |
| :--- | :--- | :--- |
| [`src/utils/skill_loader.py`](../../src/utils/skill_loader.py) | 技能加载器的源代码。实现搜索、获取、安装逻辑。 | Code, Tool, Loader |
| [`.trae/skills/skill-loader/SKILL.md`](../../.trae/skills/skill-loader/SKILL.md) | **[协议]** 技能系统的使用规范、工作流 3.0 与反模式警告。 | Protocol, Manual, Workflow |
| [`skills_index.json`](../../skills_index.json) | 本地技能注册表，映射技能名称到路径/URL。 | Registry, Config |

## 5. 参考资料 (References)
| 文件路径 | 摘要/用途 | 关键标签 |
| :--- | :--- | :--- |
| [`docs/References/book_summary.md`](../References/book_summary.md) | 相关书籍的阅读摘要。 | Reading, Summary |
| [`docs/References/architecture_research.md`](../References/architecture_research.md) | 开源量化框架架构调研 (Backtrader/Vn.py/Freqtrade 等对比)。 | Architecture, Research, Frameworks |
| [`docs/References/opensource_research_report.md`](../References/opensource_research_report.md) | Manus AI 调研报告：ZigZag防重绘、形态识别与MT4桥接选型。 | Research, Opensource, Selection |
| [`docs/Manuals/trae_usage_notes.md`](../Manuals/trae_usage_notes.md) | Trae IDE 的使用技巧与环境配置笔记。 | IDE, Env, Notes |
