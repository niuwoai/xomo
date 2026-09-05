# Architecture Design

- ViewModel 从 `selectedLayerFigmaComponentPropertyOverrideKeys` 构造覆盖字典，复用 JSONEncoder 与剪贴板 helper。
- Inspector 按钮直接调用无筛选参数的 ViewModel 方法，不按编辑权限禁用。
- Automation `copyOverrides` 调用同一 ViewModel 路径，成功返回既有 `result()`。
- 无新 DTO、无存储迁移、无 Undo/History。
