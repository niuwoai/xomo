# 2.12.0-rc1605 Tasklist

| Task ID | Member | Claimed By | Status | Locked Scope | Deliverable | Done Criteria | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GT-1605-01 | 需求分析-锁定门禁 | audit_rc1604 | done | 只读 | 锁定矩阵 | 与既有 image fill 语义一致 | Goal Lead |
| GT-1605-02 | 开发-锁定门禁 | developer_rc1605 | done | ViewModel、View、Automation、直接测试 | 最小修复 | UI/直接调用/Automation 均不能写锁定层 | QA 静态 + 评审 PASS |
| GT-1605-03 | 测试-锁定门禁 | qa_rc1605 | done | 只读执行 | 动态报告 | 定向与相邻回归全绿 | 32/32 PASS |
| GT-1605-04 | 评审-锁定语义 | review_rc1605 | done | 只读 | 独立审查 | 无半更新或 Undo 副作用 | 最终 PASS |
| GT-1605-05 | Goal Lead | root | done | 版本、文档、Git | rc1605 闭环 | 提交、标签、main、远端一致 | 实现提交 `3eda38329`，闭环提交承载最终标签 |
