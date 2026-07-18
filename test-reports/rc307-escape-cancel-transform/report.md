# Xomo 2.12.0-rc307 测试报告

## 范围

图层或 UI 组件进行缩放、旋转时，按 `Esc` 立即取消本次变换并精确恢复变换前的文档。取消操作不新增历史记录或撤销步骤；鼠标仍按住时，残余拖动事件不会重新开启第二次变换，活动变换光标保持到鼠标释放。

## 验证结果

- Xcode 测试产品编译：通过。
- 仓库独立进程测试入口：5 个定向用例全部通过，0 失败。
- 发布契约：3 个测试、7 个断言全部通过。

定向用例：

- `escapeCancelsResizeWithoutChangingDocumentHistoryOrUndo`
- `escapeCancelsRotationWithoutChangingDocumentHistoryOrUndo`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`
- `cancellingAnObjectDragDiscardsPreviewWithoutHistoryOrPositionChange`
- `activeLayerTransformKeepsItsCursorAfterPointerLeavesTheHandle`

环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1。
