# 2.12.0-rc1607 Tasklist

| Task ID | Member | Claimed By | Status | Locked Scope | Deliverable | Done Criteria | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GT-1607-01 | 需求分析-热点图像缩放 | requirements_rc1607 | done | 只读 | 规格卡 | Image Size 语义与原子失败冻结 | Goal Lead |
| GT-1607-02 | 架构-热点图像缩放 | architecture_rc1607 | done | 只读 | 架构建议 | 单事务且无 schema 改动 | Goal Lead |
| GT-1607-03 | 测试-热点图像缩放 | testplan_rc1607 | done | 只读 | 测试矩阵 | 旧实现必红、完整快照 | Goal Lead |
| GT-1607-04 | 开发-热点图像缩放 | developer_rc1607 | done | Hotspot model、Canvas Commands、相关测试 | 最小实现 | 直接与 Automation 路径一致 | 评审 PASS，QA 16/16 |
| GT-1607-05 | Goal Lead | root | done | 版本、文档、Git | rc1607 闭环 | 测试、提交、标签、main、远端一致 | 实现提交 `6746cdc80`，闭环提交承载最终标签 |
