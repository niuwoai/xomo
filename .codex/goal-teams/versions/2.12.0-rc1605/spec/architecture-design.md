# Architecture Design：锁定组件属性门禁

## 设计

- ViewModel 新增 `canEditSelectedFigmaComponentProperties`，要求选中层存在组件属性且未被 `document.isEffectivelyPixelsLocked`。
- `updateSelectedFigmaComponentProperty` 在任何归一化、Undo 快照或状态写入前检查该能力；BOOLEAN 与 reset 继续委托此入口。
- 现有 `figmaComponentPropertyEditor` 的写控件使用同一能力禁用，查看、复制和过滤保持可用。
- Automation `list` 返回 `editable`；完成 key/default 参数校验后，锁定的 `set/reset` 抛出 `operationFailed`。

## 不变量

- 覆盖判断、计数、过滤与排序不变。
- 正常属性更新、TEXT 后代联动、Undo/Redo 和项目往返不变。
- 位置锁、透明像素锁、cursor、导入与项目 schema 不变。
