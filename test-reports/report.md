# Xomo v2.12.0-rc56 验证报告

- 生成时间：2026-07-15 01:20 +0800
- 结果：全部通过
- Xcode 相关测试：12/12
- SwiftPM CLI 测试：2/2

## 验证明细

| 验证项 | 结果 |
|---|---:|
| `XomoFigmaLinkParserTests` | 8/8 |
| `LocalizationResourceTests` | 4/4 |
| `XomoMCPServerTests` | 2/2 |
| Debug `build-for-testing` | 通过 |

## 关键结论

- 解析器识别 Figma 官方现行 Design、File、Prototype、FigJam、Slides、Sites、Buzz 与 Make 链接路径。
- 只接受可信 Figma HTTPS 主机；仿冒域名、凭据、自定义端口、fragment、重复/畸形选择参数和超长输入均被拒绝。
- 规范 URL 与 Codable 预览只保留允许的节点、原型起点和版本参数，测试中的令牌及跟踪值没有进入编码结果。
- Debug App 与 CLI 版本均为 `2.12.0-rc56`；App Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，架构为 arm64。
