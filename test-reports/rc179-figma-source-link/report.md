# rc179 Figma 源链接回溯验证

- 时间：2026-07-17
- 专项：`XomoFigmaNodeImportPlanTests` + `ImageEditorFigmaProvenanceTests`
- 结果：30/30 通过

导入计划保存链接解析器清洗后的规范 Figma URL，图层和项目往返继续保留该链接；属性面板可直接复制链接，且不会把访问令牌写入链接。
