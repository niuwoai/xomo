# rc1748 像素选区移动模式切换验证

## 本版目标

像素选区正在拖动预览时切换工具或左侧栏模式，旧交互可能收不到匹配的画布结束事件。该版本将模式切换设为事务边界：提交当前有效移动为一个 Undo 操作，并清除视图层的旧拖动态。

## 实现路径

- `ImageEditorViewModel.selectTool(_:)` 与 `selectLeftSidebarTab(_:)` 在实际切换时结束像素选区移动。
- `ImageEditorView` 对工具和侧栏状态变化执行同一收口，并清除 `isPixelSelectionMoveGestureActive`，防止旧模式的手势状态拦截新模式输入。
- 零距离移动的提交行为仍由既有模型逻辑决定；本版没有改变其历史语义。

## 验证结果

- `ImageEditorPixelSelectionMoveTests`：11 项通过。新增用例验证工具切换后产生单个历史/Undo 项，Undo 恢复原选区与像素，Redo 恢复预览结果；侧栏切换验证相同事务边界，并再次切换/移动以确认没有残留事务。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions 通过。
- `scripts/verify_release_contract.rb`：通过；App、CLI 与 Xcode 版本均为 `2.12.0-rc1748`，构建号为 1748。
- `git diff --check`：通过。

## 未覆盖范围与下一步

本版是 ViewModel 事务和 SwiftUI 状态接线的单元/合同验证，未执行真实鼠标拖动 GUI 冒烟，也未运行四十版本 Release 全量构建或覆盖 `/Applications` 安装。当前安装版记录为 rc1729，完整门槛为 rc1760；届时仍需验证可恢复备份、实际光标与完整编辑流程。
