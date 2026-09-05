# Test Plan

- `ImageEditorFigmaProvenanceTests` 新增诊断矩阵与 Inspector 源码合同，目标 28/28。
- `XomoAutomationTests` 新增逐属性诊断兼容快照，目标 322/322。
- 复跑 `ImageEditorCanvasCursorTests` 128/128，确认组件库箭头与真实平移 cursor 不回退。
- 复跑 CLI/MCP 2/2、发布契约 9/9（27 条断言）、隔离测试器契约与发布结构核验。
- 覆盖合法 VARIANT/INSTANCE_SWAP、重复 key、VARIANT 重名、INSTANCE_SWAP 重名、跨命名空间碰撞、孤儿值、未知类型、非规范 BOOLEAN、锁定与零副作用。
