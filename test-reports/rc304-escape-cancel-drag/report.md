# Xomo 2.12.0-rc304 测试报告

## 范围

组件或普通图层拖动期间按 `Esc` 会取消当前移动事务：丢弃灰色虚线落点预览，不改变对象位置，也不新增历史记录。若当前是 `Option` 复制拖动，还会一并移除尚未提交的副本并恢复原选择。取消后鼠标立即回到系统箭头。

## 验证结果

- Xcode 测试产品编译：通过。
- 仓库独立进程测试入口：4 个定向用例全部通过，0 失败。
- 发布契约：3 个测试、7 个断言全部通过。

定向用例：

- `cancellingAnObjectDragDiscardsPreviewWithoutHistoryOrPositionChange`
- `cancellingAnOptionDragRemovesThePendingDuplicate`
- `movingAnObjectPublishesAndClearsItsDashedPreviewFrame`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`

环境：arm64 MacBook Pro、macOS 26.5.2、Xcode 26.4.1。
