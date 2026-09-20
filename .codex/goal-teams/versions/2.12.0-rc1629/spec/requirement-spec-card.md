# Requirement Specification Card

- 用户价值：在编辑 Figma 实例时快速知道属性是导入基线、实例覆盖，还是没有导入基线的本地属性。
- Imported default：存在 default snapshot 且当前对象完整相等。
- Overridden：存在 default snapshot 且当前对象任一字段不同，包括 value、type、preferredValues。
- Local only：当前属性存在但 default snapshot 缺失，例如 Custom。
- 视觉：紧凑只读来源徽标；与类型徽标并列；独立帮助文本和 accessibility id。
- 交互边界：不改变 reset、编辑、锁定、搜索、筛选、Automation、项目、History/Undo 或 cursor。
- 验收：三态矩阵、JSON 往返、metadata-only、锁定零副作用、搜索不命中来源文案、三语精确资源。
