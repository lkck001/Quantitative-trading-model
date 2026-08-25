# UI 模块架构

## 文档定位

本文件描述 `UI/` 的所有权、公开入口和当前子树。跨模块依赖方向见上级 `ARCHITECTURE.md`；正式构建和当前交接状态见根目录 `SESSION_LOG.md`。

## 当前目录

```text
UI/
|-- ARCHITECTURE.md
|-- UI_Router.mqh
`-- CaseManagement/
    `-- Deletion/
        |-- UI_CM_DeletePanel.mqh
        |-- UI_CM_DeleteActions.mqh
        `-- UI_CM_DeletePresenter.mqh
```

当前删除 UI 规模不足以建立叶子 `ARCHITECTURE.md`，其结构由本文件统一维护。

## 文件职责

| 文件 | 所有内容 | 不得拥有 |
| --- | --- | --- |
| `UI_Router.mqh` | 删除 UI 的稳定公开路由入口 | CSV、删除资格、旧宿主状态 |
| `UI_CM_DeletePanel.mqh` | 按钮创建、销毁、位置、尺寸、颜色、状态和提示 | 案例身份与删除事务 |
| `UI_CM_DeleteActions.mqh` | 点击意图解码、删除计数文案和原生二次确认 | 正式授权落盘、预览或提交 |
| `UI_CM_DeletePresenter.mqh` | 反馈码到用户文案及展示时长的映射 | 领域状态判断和主 EA 反馈实现 |

## 公开入口与事件流

外部调用者只通过 `UI_Router.mqh` 的 `UI_CM_*` 函数创建、销毁和更新按钮，解码删除意图，发起确认并取得展示模型。UI 不持有 `CD_Request`、`CD_Preview`、transaction token、CSV 路径或恢复运行态。

```text
图表对象事件 -> UI_CM_RouteDeleteAction -> 删除意图
组合模块 -> UI_CM_Confirm* -> 用户确认结果
组合模块 -> UI_CM_GetDeleteFeedback -> 文案和展示时长
```

## 依赖规则

- UI 可以依赖 MQL5 图表对象和 `MessageBox` 等呈现 API。
- UI 不 include `CaseManagement/`、`Opportunity/` 或 `Compatibility/`。
- 控件对象名、布局、颜色、提示、确认框和用户文案不得移出 UI。
- 新增其他 UI 能力时按 `UI/<Domain>/<Capability>/` 归类，不得把 UI 文件放入领域目录。
