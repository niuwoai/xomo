# 2.12.0-rc1611 Plan

## 成员与范围

| Member | Subtask | Locked Scope | Deliverable | Validator |
| --- | --- | --- | --- | --- |
| 需求分析-Slice Image Size | 冻结缩放、预设与选择语义 | 只读 | 需求规格卡 | Goal Lead |
| 架构-Slice Image Size | 设计原子接线 | 只读 | 架构设计 | 独立评审 |
| 测试-Slice Image Size | 设计回归矩阵 | 只读 | 测试计划 | QA |
| 开发-Slice Image Size | 实现与定向单测 | Slice model、CanvasCommands、相关测试 | 最小代码变更 | 评审 + QA |

## 停止条件

- rc1611 范围内测试全部通过。
- 版本、CHANGELOG、产品概览和 Goal Teams 文档同步。
- 提交、标签、功能分支与 main 远端落点一致。
- 不启动 rc1640 才要求的完整构建、全量冒烟或 `/Applications` 安装。
