# rc294 中键画布平移测试报告

- 版本：`2.12.0-rc294`
- 生成时间：`2026-07-18 20:51:21 +0800`
- 环境：macOS 26.5.2 / Xcode 17E202 / arm64
- 结果：**通过（2/2）**

## 定向用例

1. `ImageEditorScopeTests/canvasWorkspaceWiresScrollWheelZoomToViewModel()`：通过
2. `ImageEditorScopeTests/middleMousePanUsesFlippedCanvasDeltaWithoutTouchingHistory()`：通过

## 验证内容

- 画布按住鼠标中键拖动时，按照翻转后的画布坐标增量更新 viewport offset。
- 中键导航不写入图层、像素、选区或 History。
- 中键按下、拖动、松开分别触发开始、变化、结束回调；拖动期间显示闭合抓手，释放后恢复当前工具光标。

两个用例均使用 Swift Testing 的完整测试标识精确筛选运行。该报告只覆盖 rc294 的中键平移回归范围，不把测试类中与本次功能无关的历史源码契约用例纳入统计。
