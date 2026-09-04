# 2.12.0-rc1615 Plan

## 成员与范围

| Member | Subtask | Locked Scope | Deliverable | Validator |
| --- | --- | --- | --- | --- |
| 需求分析-Slice 正交变换 | 冻结五种几何、越界与 preset 语义 | 只读 | 规格卡 | Goal Lead |
| 架构-Slice 正交接入 | 设计模型 helper 与事务接线 | 只读 | 架构设计 | 独立评审 |
| 测试-Slice 正交验收 | 设计旧实现必红的测试矩阵 | 只读 | 测试计划 | 独立评审 |
| 开发-Slice 正交变换 | 实现与定向单测 | DocumentModels、ViewModel、两个新增测试文件 | 最小代码变更 | 评审 + QA |
| 复核-rc1615 完整性 | 复核代码、测试、文档和 Git 门禁 | 只读 | 验收结论 | Goal Lead |

## 冻结范围

- Slice 跟随画布顺/逆 90°、180°及水平/垂直翻转。
- 复用现有 Automation action，不新增 UI、项目 schema 或 wire payload。
- 响应式 Slice、Figma Fill 模型和通用 Canvas transaction 重构后置。

## 停止条件

- 新增与相邻测试、独立复核和版本契约全部通过。
- 提交、tag、功能分支与 main 远端落点一致。
- rc1615 非 rc1640 周期门禁，不执行 Release、全量 UI 冒烟或 `/Applications` 安装。
