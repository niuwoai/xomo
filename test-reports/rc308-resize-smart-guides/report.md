# Xomo 2.12.0-rc308 测试报告

## 范围

图层或 UI 组件从缩放控制点吸附到画布、手动参考线、网格或其他对象时，画布实时显示对应的横向/纵向智能参考线。缩放结束、Escape 取消或切换为等比缩放时清理参考线，不留下残影；移动预览和组件画布手势保持原行为。

## 验证结果

- Xcode 测试产品增量编译：通过。
- 仓库独立进程测试入口：6 个定向用例全部通过，0 失败。
- 发布契约：3 个测试、7 个断言全部通过。
- 按质量节奏未执行 Release、全量测试、冒烟和 `/Applications` 安装；下一门禁仍为 rc320。

定向用例：

- `resizingLayerSnapsEdgeToNearbyGuide`
- `resizingComponentShowsBothSmartGuidesUntilTransformEnds`
- `resizeSmartGuidesClearForAspectRatioModeAndCancellation`
- `escapeCancelsResizeWithoutChangingDocumentHistoryOrUndo`
- `movingLayerExposesComponentAlignmentGuidesUntilTheMoveFinishes`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`

环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1。
