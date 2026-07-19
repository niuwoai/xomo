# rc404 滤镜快捷控件测试报告

- 版本：`2.12.0-rc404`
- 日期：2026-07-19
- 结果：通过

## 自动化测试

- `filterQuickControlsExposeStableAccessibilityWithoutKeyboardFocus()`：1/1 通过。
- 验证滤镜选择器、强度滑块和三个操作按钮均有稳定辅助功能 ID。
- 验证强度滑块使用本地化“强度”名称，五个控件均显式使用 `focusable(false)`。

## Computer Use 验收

- 真实 rc404 进程中选择“高斯模糊”后，滤镜面板自动展开。
- 辅助功能树显示强度滑块为“强度”，值为 `0.5`，并显示 `image-editor-filter-intensity`。
- 五个控件的稳定 ID 全部可见。
- 点击“应用滤镜”后状态变为“已应用 高斯模糊”，撤销按钮可用。
