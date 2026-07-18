# Xomo 2.12.0-rc310 测试报告

## 范围

图层或 UI 组件旋转时，在选中框附近实时显示带正负号的角度。按住 Shift 后，HUD 显示真正应用到对象的 15°步进吸附值；提交或 Escape 取消会立即清理临时角度。移动、缩放、视口避让、旋转 Undo 与画布接线保持原行为。

## 验证结果

- Xcode 测试产品增量编译：通过。
- 仓库独立进程测试入口：9 个定向用例全部通过，0 失败。
- 发布契约：3 个测试、7 个断言全部通过。
- 按质量节奏未执行 Release、全量测试、冒烟和 `/Applications` 安装；下一门禁仍为 rc320。

定向用例：

- `moveReadoutIncludesRoundedPositionAndLiveSize`
- `resizeReadoutOnlyShowsDimensions`
- `rotationReadoutShowsSignedAngleToOneDecimalPlace`
- `rotationReadoutTracksShiftSnappingAndClearsWhenCommitted`
- `readoutStaysBelowSelectionWhenViewportHasRoom`
- `readoutFlipsAboveSelectionNearViewportBottomAndClampsHorizontally`
- `escapeCancelsRotationWithoutChangingDocumentHistoryOrUndo`
- `imageEditorRotateHandleSnapsAndUndoRestores`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`

环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1。
