# Xomo rc120 质量门禁报告

- 执行日期：2026-07-16
- 版本：`2.12.0-rc120`
- 分支：`feature/figma-auto-layout-baseline-rc88`

## 结果

✅ 全部通过。

| 检查项 | 结果 | 证据 |
|---|---:|---|
| Xcode 隔离全量测试 | 916/916 | `test-reports/rc120-full/report.json` |
| Debug 通用构建 | 通过 | `/tmp/xomo-debug-rc120/Build/Products/Debug/Xomo.app` |
| Release 通用构建 | 通过 | `/tmp/xomo-release-rc120/Build/Products/Release/Xomo.app` |
| Xomo CLI 通用构建 | 通过 | `dist/xomo-macos-universal` |
| Xomo CLI 测试 | 2/2 | `XomoMCPServerTests` |
| 应用元数据 | 通过 | Bundle ID `im.some.xomo`；最低 macOS `13.0`；版本 `2.12.0-rc120` |
| 应用架构 | 通过 | `arm64 + x86_64` |
| 安装版 | 通过 | `/Applications/Xomo.app` |
| 真实启动冒烟 | 通过 | System Events 检测到运行中的 `Xomo` |

## 说明

本次是每 20 个小版本执行一次的完整门禁。构建使用 macOS 13 部署目标和未签名通用产物；安装版适合本机验证，正式分发仍需 Developer ID 签名与公证。
