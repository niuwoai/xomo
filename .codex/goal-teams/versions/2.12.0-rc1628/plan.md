# Confirmed Plan

- 澄清状态：无需额外澄清；用户于 2026-09-05 明确回复“确认 rc1628”。
- 执行顺序：需求、架构、测试独立分析 → 开发实现 → 独立复审 → 串行动静态门禁 → Git 收口。
- 停止条件：实现触及冻结协议；系统唯一构建槽被占用；独立复审仍有未关闭 P0/P1/P2。
- 风险：宽松匹配会掩盖协议异常；trim 会破坏未知值保真；把类型加入搜索会改变 rc1626 合同。

## Teams 规划

| Member | Goal Slice | Locked Scope | Deliverable | Validator |
| --- | --- | --- | --- | --- |
| 需求分析-Figma 类型标签边界 | 冻结映射与保真语义 | 只读 | Requirement、PRD | Goal Lead |
| 架构-Figma 类型展示模型 | 设计纯派生展示模型 | 只读 | Architecture Design | 审查-Figma 类型标签回归 |
| 测试-Figma 类型标签验收 | 设计动态与静态门禁 | 只读 | Test Plan | Goal Lead |
| 开发-Figma 类型徽标收口 | 模型、UI、i18n、测试 | 指定源码/资源/测试文件 | 可运行实现 | 审查-Figma 类型标签回归 |
| 审查-Figma 类型标签回归 | 最终差异与证据复核 | 只读 | Acceptance | Goal Lead |
