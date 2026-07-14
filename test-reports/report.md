# Xomo v2.12.0-rc57 验证报告

- 生成时间：2026-07-15 01:48:04 +0800
- 自动化测试：**19/19 通过**
- Debug `build-for-testing`：**通过**
- Computer Use 真实界面冒烟：**通过**

## 测试套件

| 套件 | 结果 |
| --- | --- |
| `XomoFigmaLinkImportTests` | 5/5 |
| `XomoFigmaLinkParserTests` | 8/8 |
| `LocalizationResourceTests` | 4/4 |
| `XomoMCPServerTests` | 2/2 |

## 运行时核对

- App 与 CLI 版本均为 `2.12.0-rc57`。
- Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，Debug App 为 arm64。
- `Option + Command + F` 可打开 Figma 链接预览；输入后立即显示安全解析结果，非白名单 query 被移除，复制规范化链接有明确反馈。
- 输入框、粘贴、预览与复制按钮暴露独立辅助功能标识。
- 深色右侧面板中的标题及“图层 / 通道 / 复合 / 路径”页签保持白色/浅灰文字。
