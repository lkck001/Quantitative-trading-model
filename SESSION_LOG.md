# SESSION LOG - CURRENT STATE

> 新 Session 只需读取本文件。历史追溯按关键词查询 `docs/history/`，
> 不要默认通读归档。

## Current Objective

- 删除按钮实验切片已按最终所有权完成目录重组，正式 EA `2.40` 编译通过，等待用户重新加载并做 UI/取消路径回归验收。
- 当前阶段只忠实维护人工案例与原始证据，不运行或调整 opportunity quality、Features、Decision、评分、阈值或完整度判决。
- `EURUSD-2002-H1-CASE-009` 已由 2.38 于 2026-08-22 13:31:22 永久删除；原保存失败背景、详情页异常和回放视口未居中仍是后续独立问题，本轮未修改这些行为。
- 非 MT5 文件系统整理已完成：历史状态档案移至 `docs/history/`，操作者提示移至 `docs/Operations/`；废弃 Skill 项目、缓存和历史垃圾已移出仓库，MT5、正式 Data 和 Python 回放运行时未改变。

## Formal Build Baseline

- Formal EA: `2.40`；源码 15,137 行、678,413 字符、680,364 字节，大括号 `1126/1126`。
- CP936 严格编码往返通过；项目与 Junction 源码 SHA256：`D2648D40FEDE3E31B953AD6DFDDA30D099C4D4273F368FE0ED72B1C6288DE965`。
- MetaEditor 正式编译：`0 errors, 0 warnings`，15,422 ms；日志 `logs/compile_240_case_management_architecture.log`。
- EX5：821,352 字节；SHA256：`5B68C72562B7EF1E9B66AAB83A669706A3C5B095CFF4563D167606DD10450F99`。
- 永久 `.bak` 未改变；SHA256：`1A03D0738F555045C61BEB9BFD4CAD0925CF76B59F386CA2B0BD23CB69629D2A`。

## Formal Archive Baseline

- 目录：`Data/Local_Data/opportunity_annotations/`；七表行数（不含表头）为 `33/176/33/223/99/91/30`。
- cases：`B019538EB7463E5C2EA1168A4FAE023BF1C9157BAF865FD0CC9F42A202131FD1`
- anchors：`88960CE46FEFAABB85651C5939AB4236C4C33EDECBEE80B953CD39D46AE945E9`
- key bars：`C458EAC3A385FD135E9C3EEFEC43B81925571D4F6F8A6660F7CFE7EB94221EFD`
- drawings：`47694C31E3AB1AFFA1F408ABCFC42612986DC23BCC82C3E984BF697EFB537F58`
- regions：`1B7113932F4054A37A3A64D683C5C9684981B317B8033084373D6FC10CAE56C8`
- semantics：`97C6D913D20B33A7220612C6B8E1583CF0A7354C365F91E6CA7056CEBCADA605`
- channel boundaries：`E227AB0E9E11632A9595BDD6F0B5CEB985100A4E9B3B575F4F0F0972BAB671C0`
- sequence：一条数据 `2002,9,2026.08.22 13:31:22`；SHA256：`6A7C1DB6A79ED36E47B797FFF60A4CDECD360C9CB5629A116B35BA558D21DE20`。
- 2.38 删除 CASE-009 的写集为 `1/0/0/6/3/2/0`，结果 `DELETED`；journal/stage/backup/lock 残留为 `0`。
- 三个 `D:\mt5` Junction 仍是单一源码/数据源；2.40 目录重组和编译未写正式档案。

## Retired Skill Discovery

- `.agents/` 下的 Skill Discovery `2.0.0` 项目已退役，不再属于当前项目功能。
- 其离线/真实探针结果和退出原因归档于 `docs/history/SKILL_DISCOVERY_RETIREMENT_2026-08-25.md`。
- 不再下载、安装、执行或维护第三方 Skill；未来如需恢复，另行授权并建立新的 Skill。

## Implemented Deletion Slice

- UI 所有权：`UI/CaseManagement/Deletion/`；Panel 拥有按钮布局，Actions 拥有意图与二次确认，Presenter 拥有全部用户文案，外部只经 `UI/UI_Router.mqh` 的 `UI_CM_*` 入口。
- 案例生命周期所有权：`CaseManagement/Deletion/`；`CD_Facade.mqh` 是唯一公开领域入口，内部仅分 `Contract/` 与 `Persistence/`。
- 临时旧宿主边界：`Compatibility/LegacyMainEA/CaseManagement/Deletion/`；`CM_DeleteContextAdapter.mqh` 只读捕获上下文，`CM_DeleteRefreshAdapter.mqh` 只转发反馈和删除后刷新，`CM_DeleteModule.mqh` 只做同步编排。
- `Opportunity/` 只保留 PureRelease 机会识别代码，不再包含案例删除或删除 UI。
- 主 EA 只保留模块装配、按钮生命周期、启动和图表事件转发；删除专属文案、领域规则、事务和长期运行态均不在主 EA。
- UI 与 CaseManagement 互不 include；Compatibility 是唯一允许同时依赖两侧公开入口和旧主 EA 的临时接缝，UI、CaseManagement、Opportunity 不反向依赖它。
- 按钮行为保持 2.39：位于保存结构之后，`x=210, y=58, w=90, h=24`；可用为 `clrFireBrick`，禁用为 `clrDimGray`。
- 预览和取消全程只读；只有原生二次确认返回 `IDYES` 后才设置 `formalDeleteAuthorized=true`。
- 同一局部 Preview 保持 `Prepare -> Confirm -> Commit`；UI 不持有 manifest 或 transaction token。
- 删除资格只由七表身份盘点决定；完整度和 quality 不参与。事务写集、sequence 高水位、journal、锁、回滚和恢复语义均未改变。

## Validation And Active Risks

- MetaEditor 实际加载新 UI、CaseManagement 和 Compatibility 路径，结果 `0 errors, 0 warnings`；旧 `Application/Opportunity`、`Opportunity/CaseDeletion`、`UI/Opportunity` 路径和旧 `OP_Delete*` 符号均为零残留。
- 五维静态边界通过：UI 无 `CD_`/文件依赖；CaseManagement 无 UI/文案依赖；Module 无旧宿主直接调用；Context 无输出副作用；Refresh 无输入捕获或领域事务。
- 根架构和 `UI`、`CaseManagement`、`Opportunity`、`Compatibility` 四份一级模块架构文档均为 UTF-8 BOM，并已同步当前目录、依赖和临时边界退出条件。
- 本次整理只移动项目文档并清理非 MT5 废弃内容；未修改正式档案、年度行情、EA 源码、EX5 或 Python 回放源码。
- 可恢复的废弃目录和派生文件暂存于仓库外 `E:\QTM_quarantine_20260825\`；含凭据的 setup 文件已直接删除。
- 未运行任何 quality、Features、Decision、评分或案例质量检查；未操作 MT5 鼠标/键盘，未创建 `ChartScreenShot`，未执行新的正式删除。
- 2.40 尚无 `EA INIT | ver=2.40` 实机日志；按钮、确认、反馈、取消和恢复阻断仍由用户视觉/交互验收。
- `Trading/`、回放数据和日志仍保留；在回放启动器解除虚拟环境硬编码并完成独立验证前，不删除 Python 运行时。

## Acceptance And Next Step

- 用户重新加载 2.40，确认按钮位置、颜色、禁用/启用状态、确认文案和反馈与 2.39 一致。
- 只验证取消：关闭或选择“否”后，当前八表哈希和事务残留必须不变；不要求为结构重组再删除一个正式案例。
- UI 回归通过后，该删除切片可作为逐片抽离旧主 EA 的模板；后续能力仍需逐项授权。
- 再分别定位原 CASE-009 保存失败背景、详情页和回放居中问题，不得混入本次结构重组。
- 非 MT5 整理已完成；用户继续重新加载 2.40，进行既定 UI/取消路径验收；本轮不新增正式删除、不运行 quality/Features/Decision 检查。

## Entry Points

- EA：`MT5_Integration/MQL5_Link/MT5_EnergyTrading.mq5`
- 跨模块架构：`MT5_Integration/MQL5_Link/ARCHITECTURE.md`
- 模块架构：`UI/ARCHITECTURE.md`、`CaseManagement/ARCHITECTURE.md`、`Opportunity/ARCHITECTURE.md`、`Compatibility/ARCHITECTURE.md`
- 删除领域：`MT5_Integration/MQL5_Link/CaseManagement/Deletion/CD_Facade.mqh`
- 删除 UI：`MT5_Integration/MQL5_Link/UI/UI_Router.mqh`
- 删除临时组合入口：`MT5_Integration/MQL5_Link/Compatibility/LegacyMainEA/CaseManagement/Deletion/CM_DeleteModule.mqh`
- 正式档案：`Data/Local_Data/opportunity_annotations/`
- 操作者提示过渡源：`docs/Operations/CODEX_KEY_PROMPTS.md`
- 历史档案：`docs/history/`

## Last Updated

- 2026-08-25：完成非 MT5 文件系统整理；历史 Session Log 和操作者提示已归档/归类，Skill Discovery 项目退役；MT5 2.40 UI 回归仍待用户验收。
