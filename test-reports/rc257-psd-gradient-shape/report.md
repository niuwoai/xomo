# rc257 PSD 渐变矢量形状回归

- 生成时间：2026-07-18
- 测试范围：`ImageEditorPSDTests`
- 总数：**29**，通过：**29**，失败：**0**
- 执行方式：独立进程、`jobs=1`、arm64 测试 bundle

本轮新增外部 `gradient-vector-shape.psd` 夹具，验证 `GdFl` + 闭合 `vmsk` 导入为 Xomo 路径形状、渐变色标/角度/缩放/反向状态、项目保存重开、PSD 导出再导入，以及既有 PSD 兼容性回归。
