# 2.12.0-rc1613 Tasklist

| Task ID | Member | Claimed By | Status | Locked Scope | Deliverable | Done Criteria | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GT-1613-01 | 需求分析-Slice Crop/Trim 语义 | requirements_rc1613 | complete | 只读 | 规格卡 | 入口、几何、preset、scope 与 Trim 边界冻结 | Goal Lead：通过 |
| GT-1613-02 | 架构-Slice 裁切接入点 | architecture_rc1613 | complete | 只读 | 架构建议 | 共同漏斗与 Undo 前原子接线 | Goal Lead：通过 |
| GT-1613-03 | 测试-Slice Crop/Trim | testplan_rc1613 | complete | 只读 | 测试矩阵 | 真实命令旧实现必红、完整快照 | Goal Lead：通过 |
| GT-1613-04 | 开发-Slice Crop/Trim | developer_rc1613 | complete | CanvasCommands、两个新增测试文件 | 最小实现 | Direct、Selection、Center、Canvas Trim 与 Automation 一致 | 独立评审 PASS；新增 11/11 |
| GT-1613-05 | 复核-rc1613 完整性 | reviewer_rc1613 | complete | 全部 rc1613 diff，只读 | 复核结论 | 无未关闭 P0/P1/P2，测试有区分力 | 修正四处测试后最终 PASS |
| GT-1613-06 | Goal Lead | root | complete | 版本、文档、Git | rc1613 闭环 | 门禁、提交、标签、main、远端一致 | 动态 70/70；Git 证据见 progress |
