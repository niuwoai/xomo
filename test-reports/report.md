# Xomo v2.12.0-rc55 验证报告

- 生成时间：2026-07-15 01:04 +0800
- 结果：全部通过
- Xcode 相关测试：38/38
- SwiftPM CLI 测试：2/2

## 验证明细

| 验证项 | 结果 |
|---|---:|
| `ImageEditorSavedPathTests` | 28/28 |
| `ImageEditorLayerPanelStyleTests` | 6/6 |
| `LocalizationResourceTests` | 4/4 |
| `XomoMCPServerTests` | 2/2 |
| `scripts/test_layer_panel_tab_style.rb` | 4/4 检查通过 |
| 全新 DerivedData Debug 构建 | 通过 |
| Computer Use 真实界面检查 | 通过 |

## 关键结论

- 保存路径拖放覆盖向上、向下、移除源行后的索引修正、原地和越界无副作用。
- 图层面板页签同时以 `NSTextField.textColor` 与 attributed string 前景色固定为白色。
- 全新 Debug App 的版本为 `2.12.0-rc55`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，架构为 arm64。
- 实际启动全新 Debug App 后，“图层 / 通道 / 复合 / 路径”四个页签均为清晰白字。
