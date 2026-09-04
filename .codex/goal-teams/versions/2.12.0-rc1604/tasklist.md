# 2.12.0-rc1604 Tasklist

| Task ID | Member | Claimed By | Status | Locked Scope | Deliverable | Done Criteria | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GT-1604-01 | 需求分析-组件覆盖可见性 | requirements_rc1604 | done | 只读 | 规格卡 | 最小切片与后置项明确 | Goal Lead |
| GT-1604-02 | 开发-组件覆盖筛选 | developer_rc1604 | done | ViewModel、View、三语、直接测试 | 实现与回归 | 计数/过滤/空态/重置联动 | QA 静态 + 评审 PASS |
| GT-1604-03 | 测试-组件覆盖门禁 | qa_rc1604 | done | 只读执行 | 动态报告 | 定向与相邻回归全绿 | 17 次/16 唯一测试，失败 0 |
| GT-1604-04 | 评审-组件覆盖语义 | review_rc1604 | done | 只读 | 独立审查 | 无语义扩张或 cursor 回归 | 最终 PASS |
| GT-1604-05 | Goal Lead | root | done | 版本、文档、Git | rc1604 闭环 | 提交、标签、main、远端一致 | 实现提交 `fb62d685c`；远端随闭环核验 |
