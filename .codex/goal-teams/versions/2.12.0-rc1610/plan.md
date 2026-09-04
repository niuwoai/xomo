# 2.12.0-rc1610 Plan

## 成员与范围

| Member | Subtask | Locked Scope | Deliverable | Validator |
| --- | --- | --- | --- | --- |
| 需求分析-热点正交变换 | 冻结行为语义 | 只读 | 需求规格卡 | Goal Lead |
| 架构-热点正交变换 | 设计原子变换 | 只读 | 架构设计 | 独立评审 |
| 测试-热点正交变换 | 设计回归矩阵 | 只读 | 测试计划 | QA |
| 开发-热点正交变换 | 实现与定向单测 | Hotspot model、Canvas transform、相关测试 | 最小代码变更 | 评审 + QA |

## 停止条件

- rc1610 范围内测试全部通过。
- 版本、CHANGELOG、产品概览和 Goal Teams 文档同步。
- 提交、标签、功能分支与 main 远端落点一致。
- 不启动 rc1640 才要求的完整构建、全量冒烟或 `/Applications` 安装。
