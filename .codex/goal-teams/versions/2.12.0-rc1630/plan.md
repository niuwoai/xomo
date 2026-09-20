# Confirmed Plan

- 澄清状态：用户继续确认长期目标；本轮沿用已确认的小版本、单测、提交、合并主线节奏。
- 假设：每个 `XomoFigmaSizeConstraintField` 独立按可选 imported default 判定；`nil == nil` 仍表示 Imported default。
- 执行顺序：需求/架构/测试分析 → SPEC → 开发 → 独立复审 → 静态与动态门禁 → Git 收口。
- 停止条件：改变约束协议或写入语义；构建槽被占用；独立复审出现未关闭 P0/P1/P2。

## Teams 规划

| Member | Goal Slice | Locked Scope | Deliverable | Test Owner | Validator |
| --- | --- | --- | --- | --- | --- |
| 需求分析-Figma 约束来源 | 冻结三态与 nil/Custom 边界 | 只读 | Requirement Card、PRD | 测试-Figma 约束回归 | Goal Lead |
| 架构-Figma 约束徽标 | 设计共享纯派生模型 | 只读 | Architecture Design | 测试-Figma 约束回归 | 审查-Figma 约束回归 |
| 测试-Figma 约束回归 | 设计 34/34 目标和静态合同 | 只读 | Test Plan | 本成员 | Goal Lead |
| 开发-Figma 约束徽标 | 模型、Inspector、i18n、单测 | 指定源码/资源/测试文件 | 可运行实现 | 测试-Figma 约束回归 | 审查-Figma 约束回归 |
| 审查-Figma 约束回归 | 独立差异与行为复核 | 只读 | Acceptance | Goal Lead | Goal Lead |
