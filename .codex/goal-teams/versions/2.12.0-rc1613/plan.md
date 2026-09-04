# 2.12.0-rc1613 Plan

## 成员与范围

| Member | Subtask | Locked Scope | Deliverable | Validator |
| --- | --- | --- | --- | --- |
| 需求分析-Slice Crop/Trim 语义 | 冻结 Crop 家族、画布 Trim、preset 与选择语义 | 只读 | 需求规格卡 | Goal Lead |
| 架构-Slice 裁切接入点 | 设计共同漏斗的原子接线 | 只读 | 架构设计 | 独立评审 |
| 测试-Slice Crop/Trim | 设计旧实现必红的命令级矩阵 | 只读 | 测试计划 | 独立评审 |
| 开发-Slice Crop/Trim | 实现与定向单测 | CanvasCommands、两个新增测试文件 | 最小代码变更 | 评审 + QA |
| 复核-rc1613 完整性 | 复核代码、测试、文档和 Git 门禁 | 只读 | 验收结论 | Goal Lead |

## 澄清与假设

- rc1613 覆盖普通 Crop、Crop Center、Crop to Selection 与画布级 Trim Transparent，它们都进入同一私有 `crop` 漏斗。
- 图层级 Trim Transparent 不改变画布坐标，不得变换 Slice；本版加入负向回归。
- Slice 校验失败时保持既有 UI 裁剪框关闭与 Automation dispatch 返回语义；错误回传改造另列小版本。
- Reveal All 的非破坏语义与 Crop 不同，留给 rc1614；Rotate/Flip 继续后置。

## 停止条件

- rc1613 新增及相邻定向测试全部通过，并有独立复核证据。
- 版本、CHANGELOG、产品概览、路线图和 Goal Teams 文档同步。
- 提交、tag、功能分支与 main 远端落点一致。
- rc1613 不是 rc1640 周期门禁，不启动 Release、全量 UI 冒烟或 `/Applications` 安装。
