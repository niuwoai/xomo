# Tasklist

| ID | Owner | Status | Locked scope | Done criteria | Validator |
| --- | --- | --- | --- | --- | --- |
| R1620-REQ | 需求分析-覆盖值粘贴契约 | done | 只读需求相关代码 | 契约与边界无歧义 | 架构-原子粘贴事务 |
| R1620-ARC | 架构-原子粘贴事务 | done | 只读生产代码 | sidecar 与原子路径确定 | 审查-rc1620独立复核 |
| R1620-QA | 测试-覆盖值粘贴验收 | done | 只读测试 | 精确矩阵及命令完整 | 审查-rc1620独立复核 |
| R1620-DEV | 开发-覆盖值粘贴实现 | done | ViewModel/View/i18n/Automation/相关测试 | 功能与新增测试完整 | 审查-rc1620独立复核 |
| R1620-DOC | Goal Lead | done | 版本及文档 | 版本契约一致 | 审查-rc1620独立复核 |
| R1620-REV | 审查-rc1620独立复核 | done | 最终 diff 只读 | P0/P1/P2 全部关闭 | Goal Lead |
