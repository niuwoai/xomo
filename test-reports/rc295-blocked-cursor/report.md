# rc295 移动工具上下文光标测试报告

- 版本：`2.12.0-rc295`
- 生成时间：`2026-07-18 21:00:54 +0800`
- 环境：macOS 26.5.2 / Xcode 17E202 / arm64
- 结果：**通过（3/3）**

## 定向用例

1. `ImageEditorCanvasCursorTests/toolsTabPreservesSelectedToolCursorAndPanOverride()`：通过
2. `ImageEditorCanvasCursorTests/moveCursorHitTestUsesComponentGeometryWithoutChangingSelection()`：通过
3. `ImageEditorCanvasCursorTests/moveCursorDoesNotClaimOccludedOrPositionLockedContent()`：通过

## 验证内容

- 空白画布继续显示开放手掌，表达可平移但没有可移动对象。
- 可移动组件/图层继续显示四向移动光标。
- 可见但位置锁定或被上层内容遮挡的对象显示 macOS `operationNotAllowed`，不再误导为画布平移。
- 三个用例均使用 Swift Testing 完整测试标识精确筛选运行。
