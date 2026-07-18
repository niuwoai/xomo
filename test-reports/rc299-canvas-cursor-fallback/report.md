# Xomo `v2.12.0-rc299` 专项测试报告

## 变更范围

组件库模式继续使用系统箭头；在 macOS 13 尚未收到画布首个鼠标坐标时，不再猜测鼠标位于可移动对象上，而是先显示系统箭头。收到 AppKit 承载层的真实坐标后，再恢复工具、对象、锁定区域或画布平移的语义光标。

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

1. `ImageEditorCanvasCursorTests/selectedComponentLibraryObjectAlwaysRoutesToSystemArrowUnlessPanning()`
2. `XomoLeftSidebarTests/componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures()`

发布契约检查 `ruby scripts/test_release_contract.rb`：3 个测试、7 个断言全部通过。
