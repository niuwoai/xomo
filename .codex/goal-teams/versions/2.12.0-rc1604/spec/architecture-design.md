# Architecture Design：组件覆盖可见性与筛选

## 设计

- ViewModel 从 `selectedLayerFigmaComponentProperties` 与 `selectedLayerFigmaComponentPropertyDefaults` 派生覆盖键集合、覆盖数及按模式排序后的键。
- 覆盖判断复用现有 `hasSelectedFigmaComponentPropertyOverride`，保持单一语义来源。
- View 新增非持久化 Bool 状态，在标题区显示计数与开关，根据派生键渲染原编辑器。
- 过滤为空时显示本地化空态；数据变化后 SwiftUI 自动重算，逐项重置无需额外同步。

## 不变量

- 当前值、默认值、项目 schema、导入和 materializer 不变。
- 属性更新、TEXT 后代联动、Undo/Redo 和单项重置不变。
- 组件库选择、工具状态和 cursor 不变。
