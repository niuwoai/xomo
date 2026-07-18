# rc254 PSD 专项报告

## 结果

- 版本：`v2.12.0-rc254`
- 范围：PSD 导入、导出、压缩、蒙版、文字、通道、路径、纯色填充和线性渐变填充
- 通过：27/27
- 失败：0
- 构建：arm64 `xcodebuild` 测试包成功生成，部署目标为 macOS 13.0
- CLI：`swift build -c release` 通过

## 本版新增验证

`psdRoundTripPreservesNativeLinearGradientFillTag` 创建带三个色标、角度、缩放和反向状态的 Xomo 原生线性渐变填充层，导出 PSD 后重新导入，确认 `GdFl` 描述符被解析为可编辑渐变，色标和几何属性保持不变。

只对无复杂图层效果且确实为线性渐变的图层写入 `GdFl`；径向、反射、菱形和带效果的渐变仍导出已合成像素，避免导回后伪造或重复渲染。
