# rc177 Figma 源节点属性面板验证

- 时间：2026-07-17
- 套件：`XomoFigmaNodeImportPlanTests` + `ImageEditorFigmaProvenanceTests`
- 结果：30/30 通过

选中带有 Figma 来源的图层时，属性面板显示源节点类型和 ID，并可复制 `节点类型:节点 ID` 引用；测试同时覆盖项目保存/重开后的来源字段保留。
