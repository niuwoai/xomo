# Plan

- 澄清状态：用户已要求持续按小版本推进；rc1624 由 rc1623 的读侧缺口自然拆出。
- 假设：成功解码但结构异常的旧属性必须可读；解码阶段缺字段/类型错误不在本版扩展为 lossy decoder。
- SPEC 状态：Requirement Card、PRD、Architecture、Test Plan 已冻结；HTML Prototype 不适用。
- 执行顺序：共享诊断模型 → ViewModel 写入口复用 → Inspector 安全展示 → Automation 只读诊断 → 测试、评审、版本文档、提交合并。
- 停线：若实现要求改变持久化结构、真实 swap 或 paste 兼容合同，立即后置。
