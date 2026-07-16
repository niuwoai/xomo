# rc175 Figma 布尔运算导入验证

- 时间：2026-07-17
- 专项：`XomoFigmaNodeImportPlanTests`
- 结果：29/29 通过

本版本验证 Figma `BOOLEAN_OPERATION` 使用最终几何路径作为可编辑矢量导入，保留“已展平”的部分保真提示，并且不会把布尔运算的源子图层重复 materialize 到 Xomo 图层列表。
