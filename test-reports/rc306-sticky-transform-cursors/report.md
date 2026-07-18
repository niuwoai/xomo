# Xomo 2.12.0-rc306 测试报告

## 范围

图层或 UI 组件开始缩放/旋转后，当前变换光标保持到鼠标释放，不会因为指针离开小控制点而闪回移动、手掌或系统箭头。释放后立即按实际落点恢复上下文光标；对象整体拖动仍优先使用闭合抓手。

## 验证结果

- Xcode 测试产品编译：通过。
- 仓库独立进程测试入口：5 个定向用例全部通过，0 失败。
- 发布契约：3 个测试、7 个断言全部通过。

定向用例：

- `activeLayerTransformKeepsItsCursorAfterPointerLeavesTheHandle`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`
- `transformControlCursorOverridesComponentArrowOutsideDrawableCanvas`
- `selectedComponentLibraryObjectAlwaysRoutesToSystemArrowUnlessPanning`
- `draggingAComponentUsesTheClosedHandCursorAcrossSidebarModes`

环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1。
