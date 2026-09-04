# 2.12.0-rc1606 Tasklist

| Task ID | Member | Claimed By | Status | Locked Scope | Deliverable | Done Criteria | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GT-1606-01 | 需求审计 | audit_rc1606 | done | 只读 | 现状与风险 | 无既有响应式语义被误复用 | Goal Lead |
| GT-1606-02 | 架构审计 | architecture_rc1606 | done | 只读 | 三案比较 | schema 与几何大改后置 | Goal Lead |
| GT-1606-03 | 测试设计 | testplan_rc1606 | done | 只读 | 回归矩阵 | 能抓住固定 coords 漂移 | Goal Lead |
| GT-1606-04 | 开发 | developer_rc1606 | done | Exporter、相关测试 | 响应式 HTML | 无脚本回退与缩放重算并存 | QA 5/5 + 评审 PASS |
| GT-1606-05 | Goal Lead | root | done | 版本、文档、Git | rc1606 闭环 | 测试、提交、标签、main、远端一致 | 实现提交 `1eb219b48`，闭环提交承载最终标签 |
