# rc255 PSD 渐变导出修复回归

- 生成时间：2026-07-18
- 测试范围：`ImageEditorPSDTests`
- 总数：**27**，通过：**27**，失败：**0**
- 执行方式：独立进程、`jobs=1`、复用 arm64 测试 bundle

本轮确认 `psdRoundTripPreservesNativeLinearGradientFillTag` 以及全部 PSD 导入/导出、文字、路径、蒙版、通道和兼容性回归均通过。之前遗漏的 `GdFl` 图层记录现在会实际写入 PSD。
