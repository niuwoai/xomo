# 2.12.0-rc1605 Goal Teams 计划

## 目标

锁定或像素锁定的 Figma 组件属性不得再通过属性面板或 ViewModel 直接调用改写，避免属性元数据变化而锁定文本后代保持原值的半更新状态。

## 成员

| 成员 | 任务 | 锁定范围 | 交付 | 验收 |
| --- | --- | --- | --- | --- |
| 需求分析-锁定门禁 | 锁定矩阵与既有惯例 | 只读 | 规格卡 | Goal Lead |
| 开发-锁定门禁 | ViewModel 门禁、UI 禁用、Automation 拒绝、直接测试 | ViewModel、View、Automation Registry、Figma/Automation 测试 | 最小修复 | QA + 评审 |
| 测试-锁定门禁 | 独立动态验证 | 只读执行 | JSON/Markdown | Goal Lead |
| 评审-锁定语义 | 代码与测试审查 | 只读 | PASS/缺口 | Goal Lead |

## 边界

- 复用 `document.isEffectivelyPixelsLocked`，涵盖自身全锁/像素锁及祖先组锁定。
- ViewModel 是最终写入门禁；UI 同步禁用编辑与重置控件。
- 拒绝操作不改当前值、默认快照、文本后代、Undo/Redo 或 History；UI 直接调用可显示既有 `layerLocked` 状态。
- Automation `list` 暴露 `editable`，`set/reset` 锁定时明确失败，不能返回伪成功。
- 不修 TEXT 属性的精确节点绑定，不改 schema、导入或 cursor。
- rc1605 不执行 Release/安装；rc1640 执行下一次完整门禁。

## 停止条件

- 需要新增锁类型或改变全局锁语义。
- 需要修改项目格式、导入或稳定子层身份。
- 外部构建占用唯一构建槽时暂停动态测试。
