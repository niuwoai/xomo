# Confirmed Plan

- 澄清状态：用户继续确认长期目标；本轮沿用已提出的 rc1629 小版本方案。
- 假设：来源徽标只表达当前属性相对 imported default 的 provenance，不新增存储字段；Custom 无 baseline 为 Local only。
- 执行顺序：需求/架构/测试独立分析 → SPEC → 开发 → 独立复审 → 静态与动态门禁 → Git 收口。
- 停止条件：实现改变协议或 override 语义；构建槽被占用；独立复审有未关闭 P0/P1/P2。

## Teams 规划

| Member | Goal Slice | Locked Scope | Deliverable | Test Owner | Validator |
| --- | --- | --- | --- | --- | --- |
| 需求分析-Figma 覆盖来源边界 | 冻结三态与 Custom/metadata-only 语义 | 只读 | Requirement Card、PRD | 测试-Figma 来源提示验收 | Goal Lead |
| 架构-Figma 来源徽标模型 | 设计共享纯派生模型 | 只读 | Architecture Design | 测试-Figma 来源提示验收 | 审查-Figma 来源提示回归 |
| 测试-Figma 来源提示验收 | 设计 33/33 目标和静态合同 | 只读 | Test Plan | 本成员 | Goal Lead |
| 开发-Figma 来源徽标收口 | 模型、ViewModel、Inspector、i18n、单测 | 指定源码/资源/测试文件 | 可运行实现 | 测试-Figma 来源提示验收 | 审查-Figma 来源提示回归 |
| 审查-Figma 来源提示回归 | 独立差异与行为复核 | 只读 | Acceptance | Goal Lead | Goal Lead |
