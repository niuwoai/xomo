# Xomo 2.12.0-rc58 定向测试报告

- 生成时间：2026-07-15 02:18:00 +0800
- 总数：**37**，通过：**37**，失败：**0**
- Xcode 隔离测试均以 `jobs=1` 串行执行

✅ 全部通过。

## 按套件汇总

| 套件 | 类型 | 通过/总数 |
|---|---|---|
| XomoFigmaAuthorizedMetadataTests | Xcode Swift Testing | 8/8 |
| XomoFigmaLinkImportTests | Xcode Swift Testing | 5/5 |
| XomoFigmaLinkParserTests | Xcode Swift Testing | 8/8 |
| ImageEditorLayerPanelStyleTests | Xcode Swift Testing | 6/6 |
| LocalizationResourceTests | Xcode Swift Testing | 4/4 |
| XomoMCPServerTests | SwiftPM Swift Testing | 2/2 |
| layer_panel_tab_style | Ruby 源码契约检查 | 4/4 |

## 构建与产物

- Debug `build-for-testing`：通过
- App / CLI 版本：`2.12.0-rc58`
- Bundle ID：`im.some.xomo`
- 最低系统：macOS 13.0
- Debug App 架构：arm64

## 真实界面冒烟

- 图层面板标题和“图层 / 通道 / 复合 / 路径”四个页签均显示浅色文字。
- `Option + Command + F` 可打开 Figma 链接 Sheet。
- 输入已脱敏的测试链接后，本地预览、规范化 URL、安全令牌框和最小权限说明均正确出现。
- 冒烟过程中未输入令牌、未点击读取，未触发钥匙串写入或网络请求。
