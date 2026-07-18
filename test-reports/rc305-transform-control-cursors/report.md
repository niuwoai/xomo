# Xomo 2.12.0-rc305 测试报告

## 范围

图层和 UI 组件的八个变换缩放控制点使用常见的横向、纵向与对角缩放光标，旋转控制点使用环形旋转光标。控制点命中优先于组件库默认箭头和画布边界判断，因此位于画布上方的旋转点也能给出正确反馈；实际拖动仍优先显示闭合抓手。

## 验证结果

- Xcode 测试产品编译：通过。
- 仓库独立进程测试入口：6 个定向用例全部通过，0 失败。
- 发布契约：3 个测试、7 个断言全部通过。

定向用例：

- `layerTransformGeometryFindsTheNearestVisibleControl`
- `layerTransformControlsUseFamiliarResizeAndRotateCursors`
- `transformControlCursorOverridesComponentArrowOutsideDrawableCanvas`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`
- `cropHandlesUseContextualResizeCursors`
- `selectedComponentLibraryObjectAlwaysRoutesToSystemArrowUnlessPanning`

环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1。
