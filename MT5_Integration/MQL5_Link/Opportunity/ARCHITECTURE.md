# Opportunity 模块架构

## 文档定位

本文件是 `Opportunity/` 的模块级架构入口。跨模块所有权和依赖方向见上级 `ARCHITECTURE.md`；正式构建、档案哈希和当前交接状态见根目录 `SESSION_LOG.md`。

## 当前目录

```text
Opportunity/
|-- ARCHITECTURE.md
`-- PureRelease/
    |-- PR_Facade.mqh
    |-- Contract/
    |-- Core/
    `-- Integration/
```

`Opportunity/` 只拥有交易机会识别算法。案例删除、保存、详情和案例会话属于 `CaseManagement/`；按钮、对话框和结果呈现属于 `UI/`。

## PureRelease

| 分类 | 所有内容 | 不得拥有 |
| --- | --- | --- |
| `PR_Facade.mqh` | 纯释放用例编排和结构化结果 | UI、正式档案写入、旧机会回退 |
| `Contract/` | 类型、输入输出契约和纯结构验证 | 图表副作用、质量结论写入 |
| `Core/` | 行情特征、方向和 Shadow 诊断 | UI、文件、主 EA 全局数组 |
| `Integration/` | PureRelease 专用图表草稿捕获、H1 行情读取和平台错误转换 | 案例生命周期、正式持久化、UI 呈现 |

`PR_Facade.mqh` 是当前唯一公开入口。主 EA 不得 include `Contract/`、`Core/` 或 `Integration/` 内部文件，也不得调用内部阶段函数。

## 状态与依赖

- PureRelease 运行态由该能力自己管理，不由删除切片或 UI 持有。
- Opportunity 不 include `UI/`、`CaseManagement/` 或 `Compatibility/`。
- 临时兼容桥可以在删除完成后调用既有 PureRelease 重置入口，但不得拥有或修改机会识别算法。
- MQL5 缺少目录命名空间，公开和内部符号继续保留 `PR_` 前缀。

## 当前排除

- 当前阶段不运行或调整 quality、Features、Decision、方向、评分、阈值或完整度判定。
- PureRelease 的既有 Shadow 代码不参与人工案例是否成立、是否保存或是否删除的事实判决。
- 本次目录重组不迁移其他机会能力，也不改变任何机会算法行为。
