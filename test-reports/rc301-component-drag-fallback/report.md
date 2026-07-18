# Xomo `v2.12.0-rc301` 专项测试报告

## 变更范围

画布内已命中的 UI 组件新增 AppKit 左键拖动兜底。macOS 13 的拖放承载层或 SwiftUI 手势没有拿到拖拽时，透明 AppKit 承载层会接管组件拖动；普通工具、导入拖放和带 Command/Option/Shift/Control 的操作不被消费。预览仍只更新保持尺寸的灰色虚线，释放时才写入位置与 History。

## 测试环境

- 架构：arm64
- 设备：MacBook Pro
- 系统：macOS 26.5.2

## 测试结果

执行 focused `xcodebuild test`：

- 通过：4
- 失败：0
- 跳过：0

覆盖用例：

1. `XomoCanvasObjectTests/movingAnObjectPublishesAndClearsItsDashedPreviewFrame()`
2. `XomoCanvasObjectTests/repeatedDragUpdatesAccumulateInThePreviewBeforeCommit()`
3. `ImageEditorCanvasCursorTests/draggingAComponentUsesTheClosedHandCursorAcrossSidebarModes()`
4. `ImageEditorCanvasCursorTests/selectedComponentLibraryObjectAlwaysRoutesToSystemArrowUnlessPanning()`

发布契约检查 `ruby scripts/test_release_contract.rb`：3 个测试、7 个断言全部通过。
