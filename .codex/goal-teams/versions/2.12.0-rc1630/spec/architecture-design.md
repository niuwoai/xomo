# Architecture Design

- 在共享模型层定义 `XomoFigmaSizeConstraintSourcePresentation` 四态枚举（unset/importedDefault/overridden/localOnly）及 localization key。
- 在 `ImageEditorStackLayout` 的 ViewModel extension 提供按 field 派生的纯函数：先判断 defaults 是否存在，再按当前字段是否为空区分 unset/localOnly，最后比较字段值。
- Inspector 仅消费 presentation 并渲染 `Text + Capsule`；不在 View 内复制比较逻辑，不增加按钮、Binding 或写入副作用。
- 既有 `hasSelectedFigmaSizeConstraintOverride` 复用同一 presentation，避免 UI 与 reset/Automation 判断漂移。
