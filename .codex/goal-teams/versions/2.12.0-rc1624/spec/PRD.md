# PRD

## 目标

为导入或恢复的 Figma 组件属性提供可预测的读侧健康诊断，防止 UI 对异常数据作出错误解释。

## 行为

- TEXT、规范 BOOLEAN、合法 VARIANT/INSTANCE_SWAP 保持现有编辑能力。
- 非规范 BOOLEAN、损坏候选和未知类型显示原始 type/value 与本地化诊断，不显示会误写的正常控件。
- 合法候选的当前孤儿值原样显示，不自动选择首项或改写；只有用户明确选择合法候选才更新。
- INSTANCE_SWAP 重名候选以 key 区分。
- Automation 每项追加稳定诊断，旧字段与 action 保持兼容，`list` 对异常数据仍成功。

## 验收

- 诊断读取零项目副作用；锁定只影响可编辑性。
- 候选 key 重复时绝不进入 `ForEach(id: key)` Picker。
- rc1623 set/reset/paste、TEXT 保真和 cursor 语义不回退。
