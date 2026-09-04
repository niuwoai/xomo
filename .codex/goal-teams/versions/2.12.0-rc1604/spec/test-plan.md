# 测试计划：rc1604

## 直接测试

- 默认值相等时覆盖数为 0。
- VARIANT、BOOLEAN、TEXT 变化时覆盖键和计数正确。
- 无默认快照的属性仅在全部模式出现。
- 全部与仅覆盖键均稳定排序。
- 筛选状态逐项重置后消失，Undo 后恢复。
- 项目往返后覆盖计数一致。
- 属性面板包含计数、开关、空态的本地化键和辅助功能标识。

## 相邻回归

- `ImageEditorFigmaProvenanceTests`。
- 相关项目文档往返与 Figma component property 导入测试。
- 三语本地化资源测试。
- `ImageEditorCanvasCursorTests` 中组件库箭头定向用例。
- 发布契约、隔离测试器契约与 CLI/MCP 2/2。

rc1604 不执行完整 Release/安装；rc1640 执行下一次完整门禁。
