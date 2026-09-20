# Architecture Design

- 新增 `XomoFigmaComponentPropertySourcePresentation` 为 `Equatable, Sendable` 的纯展示值类型。
- ViewModel 方法先检查 `selectedLayerFigmaComponentPropertyDefaults[key]` 是否存在，再调用现有 `hasSelectedFigmaComponentPropertyOverride(_:property:)`，避免复制完整对象比较规则。
- View 只消费 presentation 的 localization key/raw help，来源 badge 不创建 Binding、不调用 ViewModel mutation、不改筛选函数。
- 不向属性模型添加存储字段，因此 Codable、Automation、剪贴板和项目格式保持字节级语义不变。
