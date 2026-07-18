# rc253 PSD 专项报告

## 结果

- 版本：`v2.12.0-rc253`
- 范围：PSD 导入、导出、压缩、蒙版、文字、通道、路径与原生纯色填充往返
- 通过：26/26
- 失败：0
- 构建：arm64 `xcodebuild` 测试包成功生成，部署目标为 macOS 13.0
- CLI：`swift build -c release` 通过

## 本版新增验证

`psdRoundTripPreservesNativeSolidColorFillTag` 创建 Xomo 原生纯色填充层，导出 PSD 后重新导入，确认 `SoCo` 描述符被解析为可编辑纯色填充、图层名称和几何边界保持不变。

复杂图层效果不会错误写入可编辑 `SoCo`：这类填充仍以已经合成的像素结果导出，避免导回后出现重复效果。
