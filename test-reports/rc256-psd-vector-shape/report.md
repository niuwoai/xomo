# rc256 PSD 可编辑矢量形状回归

- 生成时间：2026-07-18
- 测试范围：`ImageEditorPSDTests`
- 总数：**28**，通过：**28**，失败：**0**
- 执行方式：独立进程、`jobs=1`、arm64 测试 bundle

本轮新增外部 `solid-vector-shape.psd` 夹具，验证 `SoCo` + 闭合 `vmsk` 导入为 Xomo 路径形状、项目保存重开、PSD 导出再导入，以及既有 PSD 兼容性回归。
