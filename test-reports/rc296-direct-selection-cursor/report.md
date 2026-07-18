# rc296 路径选择与直接选择光标测试报告

- 版本：`2.12.0-rc296`
- 生成时间：`2026-07-18 21:07:05 +0800`
- 环境：macOS 26.5.2 / Xcode 17E202 / arm64
- 结果：**通过（3/3）**

## 定向用例

1. `ImageEditorCanvasCursorTests/pathSelectionUsesTheFamiliarSystemArrowAndPhotoshopShortcut()`：通过
2. `ImageEditorCanvasCursorTests/directSelectionUsesAWhiteEditingArrowAndSharesTheAGroup()`：通过
3. `veilpicTests/imageEditorCanvasCursorFamiliesMatchToolInteractionSemantics()`：通过

## 验证内容

- 路径选择工具保留系统黑色箭头，用于选中并移动整条路径。
- 直接选择工具使用独立的白色描边箭头，用于编辑锚点和控制柄。
- 两个工具仍共享 Photoshop 风格的 `A` 快捷键组，但不再复用同一个光标族。
- 组件库模式的系统默认箭头路由未改变。
