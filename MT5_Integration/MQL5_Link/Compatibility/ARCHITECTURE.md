# Compatibility 模块架构

## 文档定位

本文件描述 `Compatibility/` 的临时旧代码兼容边界。它不是业务模块，也不是长期 `Application` 或 `Workflow` 层；当前结构只为在逐步缩小旧主 EA 时保护已抽离的 UI 与 CaseManagement 边界。

## 当前目录

```text
Compatibility/
|-- ARCHITECTURE.md
`-- LegacyMainEA/
    `-- CaseManagement/
        `-- Deletion/
            |-- CM_DeleteModule.mqh
            |-- CM_DeleteContextAdapter.mqh
            `-- CM_DeleteRefreshAdapter.mqh
```

## 文件职责

| 文件 | 所有内容 | 不得拥有 |
| --- | --- | --- |
| `CM_DeleteModule.mqh` | `Prepare -> Confirm -> Commit`、恢复门禁、结果码映射和调用顺序 | UI 文案、删除资格实现、CSV 事务和长期状态 |
| `CM_DeleteContextAdapter.mqh` | 只读捕获当前展示案例、身份和档案路径，生成标准 `CD_Request` | 图表刷新、用户反馈和删除决定 |
| `CM_DeleteRefreshAdapter.mqh` | 转发反馈，进入旧宿主安全空态，重载目录并重置既有显示状态 | 输入快照、删除规则、事务和机会算法 |

Context 与 Refresh 分开，是为了让旧宿主读取依赖和删除后副作用不再聚集为一个过宽的 `HostAdapter`。

## 依赖方向

```text
LegacyMainEA event -> CM_DeleteModule
                      |-> UI/UI_Router
                      |-> CaseManagement/Deletion/CD_Facade
                      |-> CM_DeleteContextAdapter -> legacy globals
                      `-> CM_DeleteRefreshAdapter -> legacy refresh functions
```

Compatibility 可以依赖 UI 和 CaseManagement 的公开入口，也可以调用当前旧主 EA 已声明的会话、目录和显示刷新接口；UI、CaseManagement 和 Opportunity 不得反向依赖 Compatibility。兼容桥不得包含用户文案、控件几何、领域资格、正式存储实现、PureRelease 算法或持久长期状态。

## 删除条件

`LegacyMainEA/CaseManagement/Deletion/` 是明确的临时边界。只有当新的宿主组合入口能够提供标准当前案例快照、正式档案路径、反馈出口和删除后刷新接口时，才可在独立授权下替换或删除该目录。移除兼容桥不得要求修改删除 UI 或 `CD_Facade.mqh` 的领域语义。

该边界的存在只证明当前删除按钮实验切片可替换，不代表旧主 EA 的其他案例功能已经迁移。
