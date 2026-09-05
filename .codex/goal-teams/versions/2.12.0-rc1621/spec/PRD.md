# PRD

## 用户价值

还原跨类型或 metadata-only 的 Figma 属性时，不再意外改写、重排或重命名组件内文本图层。

## 验收边界

- 单项 TEXT→VARIANT 只恢复属性，匹配文本后代整层不变。
- 批量覆盖 TEXT→TEXT、TEXT→非 TEXT、非 TEXT→TEXT、同值 metadata-only 四类组合。
- 只有 TEXT→TEXT 且值改变的可编辑匹配后代更新；锁定后代不变。
- 整批一次 Undo/History；Undo/Redo 同时精确恢复项目状态。
