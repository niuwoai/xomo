# Xomo rc140 质量门禁报告

- 执行日期：2026-07-16
- 版本：`2.12.0-rc140`
- 分支：`feature/figma-auto-layout-baseline-rc88`

## 结果

✅ 全部通过。

| 检查项 | 结果 | 证据 |
|---|---:|---|
| Xcode 隔离全量测试 | 932/932 | `test-reports/rc140-full/report.json` |
| Debug 通用构建 | 通过 | `/tmp/xomo-debug-rc140/Build/Products/Debug/Xomo.app` |
| Release 通用构建 | 通过 | `/tmp/xomo-release-rc140/Build/Products/Release/Xomo.app` |
| Xomo CLI 通用构建 | 通过 | `dist/xomo-macos-universal` |
| Xomo CLI 测试 | 2/2 | `XomoMCPServerTests` |
| 应用元数据 | 通过 | Bundle ID `im.some.xomo`；最低 macOS `13.0`；版本 `2.12.0-rc140` |
| 应用架构 | 通过 | App 与 CLI 均为 `arm64 + x86_64` |
| 安装版 | 通过 | `/Applications/Xomo.app` |
| 真实界面冒烟 | 通过 | 启动安装版，切换组件库并插入按钮，画布与四层可编辑图层正常显示 |

## 说明

本次是每 20 个小版本执行一次的完整门禁。构建使用 macOS 13 部署目标和未签名通用产物；安装版适合本机验证，正式分发仍需 Developer ID 签名与公证。首次在受限沙箱内运行测试时被 `testmanagerd` 拒绝，提权后同一套 932 项全部通过；这属于运行环境权限，不是产品测试失败。
