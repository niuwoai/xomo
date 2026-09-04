# 2.12.0-rc1614 Plan

## 成员与范围

| Member | Subtask | Locked Scope | Deliverable | Validator |
| --- | --- | --- | --- | --- |
| 需求分析-Slice Reveal All | 冻结 bounds、几何、preset 与选择语义 | 只读 | 需求规格卡 | Goal Lead |
| 架构-Slice Reveal 接入 | 设计不可删除的原子接线 | 只读 | 架构设计 | 独立评审 |
| 测试-Slice Reveal All | 设计旧实现必红的命令矩阵 | 只读 | 测试计划 | 独立评审 |
| 开发-Slice Reveal All | 实现与定向单测 | CanvasCommands、两个新增测试文件 | 最小代码变更 | 评审 + QA |
| 复核-rc1614 完整性 | 复核代码、测试、文档和 Git 门禁 | 只读 | 验收结论 | Goal Lead |

## 冻结范围

- Reveal target 仅由旧画布与可见可合成图层决定，Slice 不参与 bounds 或 availability。
- Reveal 是非破坏扩画布：合法 Slice 数量、顺序和元数据不减少；任何 unexpected nil 结果整单失败。
- 历史部分越界 Slice 可随新画布重新显露；完全位于旧画布外的 Slice 继续按损坏源拒绝。
- Rotate/Flip、UI、schema、Automation payload、通用 Undo 重构与 Release 均后置。

## 停止条件

- 新增与相邻测试、独立复核和版本契约全部通过。
- 提交、tag、功能分支与 main 远端落点一致。
- rc1614 非 rc1640 周期门禁，不执行 Release、全量 UI 冒烟或 `/Applications` 安装。
