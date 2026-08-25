# CaseManagement 模块架构

## 文档定位

本文件描述 `CaseManagement/` 的案例生命周期能力、公开入口、状态所有权和正式持久化边界。跨模块关系见上级 `ARCHITECTURE.md`；正式档案哈希和当前交接状态见根目录 `SESSION_LOG.md`。

## 当前目录

```text
CaseManagement/
|-- ARCHITECTURE.md
`-- Deletion/
    |-- CD_Facade.mqh
    |-- Contract/
    |   |-- CD_Types.mqh
    |   `-- CD_Contract.mqh
    `-- Persistence/
        |-- CD_ArchiveStore.mqh
        `-- CD_Transaction.mqh
```

当前删除领域由 `CD_Facade.mqh` 作为唯一公开入口；调用者不得 include `Contract/` 或 `Persistence/` 内部文件。

## 删除能力

| 分类 | 所有内容 | 不得拥有 |
| --- | --- | --- |
| `CD_Facade.mqh` | 删除资格缓存、预览、提交、取消、恢复、恢复运行态和编号高水位 | UI、旧主 EA 会话和案例自动选择 |
| `Contract/` | 请求、预览、结果、稳定状态、身份约束和重置函数 | 文件实现、按钮、确认框和用户文案 |
| `Persistence/` | 七表盘点、指纹、暂存、备份、journal、排他锁、全量替换、复读和恢复 | quality、评分、机会类型判定和 UI 反馈 |

删除写集是七张正式案例 CSV 加 `opportunity_case_sequences.csv`。提交前必须重新盘点并拒绝陈旧预览；最低写入边界必须再次证明 `formalDeleteAuthorized=true`。主记录必须唯一且身份一致，子表允许零行，但已有目标行的 `case_type/symbol/timeframe` 必须一致；这些是删除身份与事务约束，不是 quality 或完整度门禁。

## 状态与事件流

- `CD_RuntimeState` 属于删除领域，保存只读资格缓存和恢复真相；UI、兼容桥和主 EA 不得复制这份长期状态。
- 同一调用栈中的局部 Preview 必须保持 `Prepare -> Confirm -> Commit` 一致，UI 不得持有 manifest 或 transaction token。
- 启动、预览、取消、案例切换和普通 UI 更新不得写正式档案；恢复必须由用户再次确认。
- 提交和恢复共用排他事务锁。失败必须恢复完整写集，或保留可检测的恢复状态。

## 依赖规则

- CaseManagement 不 include `UI/`、`Opportunity/`、`Compatibility/` 或旧主 EA。
- 领域契约不得包含按钮对象名、颜色、`MessageBox`、本地化文案或主 EA 可变全局。
- MQL5 缺少目录命名空间，删除能力继续使用 `CD_` 符号前缀。
- 当前阶段不运行或引入 quality、Features、Decision、评分、阈值或完整度判定。
