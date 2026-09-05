# Tasklist

| ID | Owner | Status | Locked scope | Done criteria | Validator |
| --- | --- | --- | --- | --- | --- |
| R1621-REQ | 需求分析-还原类型边界 | done | 只读 ViewModel/测试 | 类型矩阵冻结 | 架构-还原事务 |
| R1621-ARC | 架构-还原事务 | done | 只读生产代码 | 最小改法不破坏事务 | 审查-rc1621独立复核 |
| R1621-QA | 测试-还原回归 | done | 只读测试 | 可击穿旧实现的矩阵 | 审查-rc1621独立复核 |
| R1621-DEV | 开发-类型安全还原 | done | ViewModel/Figma tests | 修复与新增测试完整 | 审查-rc1621独立复核 |
| R1621-DOC | Goal Lead | done | 版本及文档 | 版本契约一致 | 审查-rc1621独立复核 |
| R1621-REV | 审查-rc1621独立复核 | done | 最终 diff 只读 | P0/P1/P2 全关闭 | Goal Lead |
