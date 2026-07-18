# Xomo 2.12.0-rc303 测试报告

## 范围

组件拖动开始后，即使左键释放发生在画布或当前窗口边缘之外，也会可靠结束移动事务，避免闭合抓手光标卡住、下一次点击被吞掉。组件库静止时继续使用系统箭头，实际拖动期间继续使用闭合抓手。

## 验证结果

- Xcode 测试产品编译：通过。
- 仓库独立进程测试入口：4 个定向用例全部通过，0 失败。
- 发布契约：3 个测试、7 个断言全部通过。

定向用例：

- `objectDragReleaseAlwaysClosesEvenWhenPointerLeavesCanvasWindow`
- `selectedComponentLibraryObjectAlwaysRoutesToSystemArrowUnlessPanning`
- `draggingAComponentUsesTheClosedHandCursorAcrossSidebarModes`
- `canvasContentHitSharesTheSameSemanticForCursorPaths`

环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1。
