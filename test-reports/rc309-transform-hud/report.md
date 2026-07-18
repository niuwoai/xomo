# Xomo 2.12.0-rc309 测试报告

## 范围

图层或 UI 组件移动时，在选中框附近实时显示 X/Y 与宽高；从控制点缩放时显示实时宽高。轻量信息条不会接收鼠标事件或写入文档 History，在视口底部空间不足时自动翻到选中框上方，并始终夹紧在可见宽度内。

## 验证结果

- Xcode 测试产品增量编译：通过。
- 仓库独立进程测试入口：7 个定向用例全部通过，0 失败。
- 发布契约：3 个测试、7 个断言全部通过。
- 按质量节奏未执行 Release、全量测试、冒烟和 `/Applications` 安装；下一门禁仍为 rc320。

定向用例：

- `moveReadoutIncludesRoundedPositionAndLiveSize`
- `resizeReadoutOnlyShowsDimensions`
- `readoutStaysBelowSelectionWhenViewportHasRoom`
- `readoutFlipsAboveSelectionNearViewportBottomAndClampsHorizontally`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`
- `objectPreviewSnapsBeforeTheRealLayersCommit`
- `resizingComponentShowsBothSmartGuidesUntilTransformEnds`

环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1。
