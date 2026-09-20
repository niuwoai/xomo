# Test Plan

- 新增恰好 1 个 `ImageEditorFigmaProvenanceTests` 测试，套件 32 → 33。
- 表驱动覆盖：完整相等、value-only、metadata-only、value+metadata、Custom 无 baseline。
- 断言 source presentation、override count/filter、reset 可见性边界、Codable round-trip、搜索不命中来源/本地化文案。
- 读取来源前后比较属性/default 字典、History、Undo/Redo、status、selection、diagnostic/blocked 计数。
- 静态合同锁定共享 ViewModel 判定、来源 badge id、三态三语值、只读无写路径，以及 search 仍仅 key/current value。
- 目标：Figma 33/33、Automation 323/323、Localization 46/46、Cursor 128/128、CLI/MCP 2/2、Release contract 9/9。
