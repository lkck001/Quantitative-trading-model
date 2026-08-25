# MQL5 Link 模块架构

## 文档定位

本文件是 `MQL5_Link/` 的跨模块架构入口，只记录一级所有权、依赖方向和模块文档链接。模块内部职责进入对应一级目录的 `ARCHITECTURE.md`；当前目标、正式哈希和交接状态只进入根目录 `SESSION_LOG.md`。

## 一级所有权

```text
MQL5_Link/
|-- ARCHITECTURE.md
|-- MT5_EnergyTrading.mq5
|-- UI/
|   |-- ARCHITECTURE.md
|   |-- UI_Router.mqh
|   `-- CaseManagement/Deletion/
|-- CaseManagement/
|   |-- ARCHITECTURE.md
|   `-- Deletion/
|-- Opportunity/
|   |-- ARCHITECTURE.md
|   `-- PureRelease/
`-- Compatibility/
    |-- ARCHITECTURE.md
    `-- LegacyMainEA/CaseManagement/Deletion/
```

- `UI/` 拥有控件、布局、交互意图、确认和结果呈现，不拥有案例规则、正式档案或主 EA 会话状态。
- `CaseManagement/` 拥有案例生命周期用例、契约、运行态和经授权的正式档案事务，不依赖 UI、机会算法或旧主 EA 全局状态。
- `Opportunity/` 只拥有交易机会识别算法及其输入适配，不拥有案例生命周期和案例 UI。
- `Compatibility/` 是隔离旧主 EA 的临时兼容边界，只允许读取旧上下文、编排公开接口和转发成功后的旧宿主刷新。
- `MT5_EnergyTrading.mq5` 保留模块装配、启动和图表事件转发；不得重新吸收删除文案、删除事务或删除专属长期状态。

## 依赖方向

```text
图表事件 -> 主 EA -> Compatibility 删除模块
                         |-> UI_Router -> UI/CaseManagement/Deletion
                         |-> CaseManagement/Deletion/CD_Facade
                         `-> LegacyMainEA Context/Refresh adapters

Opportunity/PureRelease ------------------------------> 自身公开 Facade
```

`UI/` 与 `CaseManagement/` 是直接独立的并列模块，互不 include。只有临时兼容模块可以同时依赖两侧公开入口和旧主 EA；UI 不得访问 `CD_` 内部契约或 CSV，CaseManagement 不得访问按钮对象、`MessageBox`、颜色或旧宿主全局。Opportunity 不依赖删除切片，删除领域也不依赖 Opportunity。

## 文档与目录规则

- 一级按稳定所有权划分，二级按具体功能及共同变化原因划分；领域专用界面进入 `UI/<Domain>/<Capability>/`。
- 根目录和每个稳定一级模块各维护一份 `ARCHITECTURE.md`。叶子能力只有在形成多个独立组件或独立生命周期后才增加本地架构文档。
- 移动文件、改变职责、公开入口、依赖方向、状态所有权或组合接缝时，必须在同次修改中同步根架构和受影响模块文档。
- 模块根部只保留真实 Router、Facade 或架构入口；禁止空目录、占位文件，以及无明确所有者的 `Common`、`Shared`、`Utils`、`Workflow` 或 `Application` 杂物层。
- 架构文档只描述当前结构，不记录旧目录、构建基线、事故时间线或会话过程。

## 删除实验切片

删除按钮是当前唯一完成完整抽离的实验切片：UI 拥有按钮、意图、确认和反馈；CaseManagement 拥有删除资格、预览、提交、恢复、事务和编号高水位；Compatibility 保持同步 `Prepare -> Confirm -> Commit`，并通过只读 Context 与只写 Refresh 两个旧宿主接缝连接当前主 EA。主 EA 只转发启动、按钮生命周期和图表事件。

该结论只覆盖删除按钮，不代表整个 UI、CaseSession、Opportunity 或主 EA 已解耦。结构迁移不改变正式删除语义，也不运行 opportunity quality、Features、Decision、评分、阈值或完整度判定。
