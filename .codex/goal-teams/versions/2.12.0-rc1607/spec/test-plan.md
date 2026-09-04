# 测试计划：rc1607

## 直接测试

- 非等比缩放两个热点，覆盖普通矩形与贴边矩形，断言 frame、顺序、UUID、名称、URL。
- 成功操作只增加一次 History/Undo，清空既有 Redo；完整项目快照 Undo/Redo 精确往返。
- 无变化尺寸、非法目标尺寸及非法热点比较当前项目和每个 Undo/Redo 栈元素的完整编码，证明原子失败。
- 选择热点 ID 与热点面板可见状态在成功、失败、Undo/Redo 中不变。
- Automation 真实调用 `xomo.canvas.resize_image`，随后 `xomo.hotspot.list` 返回缩放坐标。

## 相邻回归

- `ImageEditorHotspotHTMLExporterTests`。
- `ImageEditorProjectDocumentTests.projectDocumentRoundTripsNamedHotspotsAndKeepsDestinationURL`。
- 组件库系统箭头核心合同。
- 发布契约、隔离测试器契约、发布结构与 CLI/MCP 2/2。

rc1607 不执行 Release/安装；rc1640 执行完整门禁。
