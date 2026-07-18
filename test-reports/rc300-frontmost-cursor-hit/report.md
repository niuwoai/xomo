# Xomo `v2.12.0-rc300` 专项测试报告

## 变更范围

移动工具的光标命中现在只采用鼠标处最上方实际可见图层。顶层锁定内容遮住底层可移动内容时，显示禁止操作光标；底层内容不会越过遮挡层抢占四向移动提示。组件库模式的系统箭头语义保持不变。

## 测试环境

- 架构：arm64
- 设备：MacBook Pro
- 系统：macOS 26.5.2

## 测试结果

执行 focused `xcodebuild test`：

- 通过：3
- 失败：0
- 跳过：0

覆盖用例：

1. `ImageEditorCanvasCursorTests/moveCursorUsesTheFrontmostLockedLayerOverAnUnlockedLayer()`
2. `ImageEditorCanvasCursorTests/moveCursorDoesNotClaimOccludedOrPositionLockedContent()`
3. `ImageEditorCanvasCursorTests/selectedComponentLibraryObjectAlwaysRoutesToSystemArrowUnlessPanning()`

发布契约检查 `ruby scripts/test_release_contract.rb`：3 个测试、7 个断言全部通过。
