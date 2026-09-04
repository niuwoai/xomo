# 2.12.0-rc1603 Goal Teams 计划

## 目标

修复 Figma IMAGE Fill 提前返回导致 Paint 混合模式和透明度静默丢失诊断的问题。当前单层模型不能证明 Paint 模式提升为图层模式的视觉等价性，因此本版只保证诚实 partial/unsupportedPaint，不伪装 exact 支持。

## 成员

| 成员 | 任务 | 锁定范围 | 交付 | 验收 |
| --- | --- | --- | --- | --- |
| 需求分析-Figma IMAGE Paint 诊断 | 语义与诊断矩阵 | 只读 | 需求规格卡 | 评审复核 |
| 开发-Figma IMAGE Paint 诊断 | mapper 与直接测试 | Content API、新测试 | 最小实现 | QA + 评审 |
| 测试-Figma 导入门禁 | 独立动态测试 | 只读执行 | JSON/Markdown 报告 | Goal Lead |
| 评审-Figma 语义边界 | 代码与测试审查 | 只读 | PASS/缺口 | Goal Lead |

## 假设与边界

- 不执行 Paint blendMode 到 layer blendMode 的提升。
- 不新增持久化字段，不修改 `.xomoproject` schema。
- IMAGE Paint 的非 NORMAL/未知 blendMode、非 1 或非法 opacity 必须显式 partial/unsupportedPaint；默认 NORMAL 与 opacity nil/1 不误报。
- rc1603 不执行 Release 或安装覆盖；rc1640 执行下一次完整门禁。

## 停止条件

- 发现诊断修复需要改变节点隔离、子层合成或持久化语义。
- 现有 import item 无法承载等价结果而必须改 schema。
- 外部构建占用唯一构建槽时暂停动态测试。
