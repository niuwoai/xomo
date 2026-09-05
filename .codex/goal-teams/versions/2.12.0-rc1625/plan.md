# Plan

- 澄清状态：用户要求持续小版本推进；本轮由 rc1624 的逐项诊断自然拆出规模化问题定位。
- 假设：`diagnosticCount` 包含可修复 warning；`blockedCount` 只统计数据级 `diagnosis.writable == false`。
- SPEC 状态：Requirement Card、PRD、Architecture、Test Plan 已冻结；HTML Prototype 不适用。
- 执行顺序：共享健康摘要 → ViewModel 统计/交集筛选 → Inspector → Automation → 独立评审 → 串行测试 → 文档/Git。
- 停线：若要求改变持久化、action、paste/cursor 或真实 Figma 实例替换，立即后置。
