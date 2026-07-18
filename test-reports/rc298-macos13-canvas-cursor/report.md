# Xomo `v2.12.0-rc298` 专项测试报告

## 变更范围

为 macOS 13 的透明 AppKit 画布承载层补发精确鼠标坐标，使工具光标能够区分画布空白、可移动对象和禁止操作区域；同时保持滚轮缩放与中键拖动画布行为不变。

## 测试环境

- 架构：arm64
- 设备：MacBook Pro
- 系统：macOS 26.5.2

## 测试结果

执行 focused `xcodebuild test`：

- 通过：2
- 失败：0
- 跳过：0

覆盖用例：

1. `ImageEditorScopeTests/canvasWorkspaceWiresScrollWheelZoomToViewModel()`
2. `ImageEditorCanvasCursorTests/toolsTabPreservesSelectedToolCursorAndPanOverride()`

发布契约检查 `ruby scripts/test_release_contract.rb`：3 个测试、7 个断言全部通过。
