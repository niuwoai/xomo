# Test Plan

- JSONDecoder 精确比较 Copy All 全量字典与 Copy Overrides 子集，不使用 substring。
- 覆盖 TEXT/BOOLEAN/VARIANT 及 metadata-only，并排除 Custom/未覆盖属性。
- 无覆盖保持剪贴板 sentinel、changeCount 和 status。
- 自身/祖先 full/pixel lock 下复制成功，文档、History、Undo/Redo 不变。
- 源码契约证明 UI filter 未传入复制方法，按钮无编辑锁禁用。
- Automation schema、成功、锁定与无覆盖错误路径。
- 串行运行 `ImageEditorFigmaProvenanceTests`、`XomoAutomationTests`、CLI/MCP 和发布/隔离运行器契约。
