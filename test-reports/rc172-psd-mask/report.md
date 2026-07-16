# v2.12.0-rc172 PSD 复杂蒙版报告

- 生成时间：2026-07-17 06:02（Asia/Shanghai）
- 变更范围：栅格蒙版 alpha 导出与往返精度

## 验证结果

| 套件 | 通过/总数 | 结果 |
|---|---:|---|
| `ImageEditorPSDTests` | 18/18 | ✅ 复杂蒙版、ZIP、文字、矢量蒙版、路径资源与基础图层全部通过 |
| `XomoMCPServerTests` | 2/2 | ✅ CLI/MCP 初始化与工具列表通过 |

## 修复说明

PSD 导出不再先经过 AppKit `NSImage.rendered` 重绘后读取透明度，而是通过 Core Graphics 以 `.copy` 混合模式和无插值设置逐像素提取 alpha。此前交替 255/0 的蒙版会被读成 223/32 等混合值；本版已精确恢复。
