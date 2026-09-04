# 2.12.0-rc1615 Tasklist

| Task ID | Member | Claimed By | Status | Locked Scope | Deliverable | Done Criteria | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GT-1615-01 | 需求分析-Slice 正交变换 | requirements_rc1615 | complete | 只读 | 规格卡 | 五种几何、越界、preset 与 scope 语义冻结 | Goal Lead：通过 |
| GT-1615-02 | 架构-Slice 正交接入 | architecture_rc1615 | complete | 只读 | 架构建议 | helper、原子事务与 Undo/Redo 接线 | Goal Lead：通过 |
| GT-1615-03 | 测试-Slice 正交验收 | testplan_rc1615 | complete | 只读 | 测试矩阵 | 真实 action 旧实现必红、完整快照 | Goal Lead：通过 |
| GT-1615-04 | 开发-Slice 正交变换 | developer_rc1615 | complete | DocumentModels、ViewModel、两个新增测试文件 | 最小实现 | Direct 与 Automation 一致且不丢交付语义 | 评审 PASS；动态新增 6/6 |
| GT-1615-05 | 复核-rc1615 完整性 | reviewer_rc1615 | complete | 全部 rc1615 diff，只读 | 复核结论 | 无未关闭 P0/P1/P2，测试有区分力 | 最终 PASS |
| GT-1615-06 | Goal Lead | root | in-progress | 版本、文档、Git | rc1615 闭环 | 门禁、提交、标签、main、远端一致 | 动态门禁 PASS，Git 待闭环 |
