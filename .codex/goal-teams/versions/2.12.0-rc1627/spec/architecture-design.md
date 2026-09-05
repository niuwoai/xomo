# Architecture Design

## 决策

在 `ImageEditorViewModel` 增加内部纯值类型 `XomoFigmaComponentPropertyFilterResult`：

- `visibleKeys: [String]`
- `totalCount: Int`
- `isActive: Bool`
- 计算属性 `visibleCount`

新增 `selectedLayerFigmaComponentPropertyFilterResult(...)`，一次捕获属性字典、一次规范化查询、一次 `compactMap + sorted`。旧 `selectedLayerFigmaComponentPropertyKeys(...)` 委托新入口并返回 `visibleKeys`。

`ImageEditorView` 每次渲染只取得一份结果，摘要、空态与 `ForEach` 全部引用它。清除按钮只写三个本地 `@State`，不进入 ViewModel。

## 不变量

- 不新增 `@Published`、Document 字段或缓存。
- 不重复筛选或重新定义 active。
- 不触及 dirty、History/Undo、Automation、剪贴板、导入、组件库和 cursor。
