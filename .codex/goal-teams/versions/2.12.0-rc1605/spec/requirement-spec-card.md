# 需求规格卡：锁定 Figma 组件属性写入门禁

## 用户价值

锁定组件表示其内容与属性不可被意外修改。属性元数据和真实文本必须保持一致，不能出现只改一半的状态。

## 必须满足

- 选中层自身 `isLocked` 或 `locksPixels` 时不可编辑属性。
- 任一祖先组全锁或像素锁时不可编辑属性。
- UI 中 TEXT、BOOLEAN、VARIANT 与逐项还原均禁用。
- ViewModel 直接 update/reset 调用同样拒绝。
- 拒绝时 current/default、后代文本、History 与 Undo/Redo 均不变；UI 可显示既有锁定状态。
- 解锁后原有编辑、还原、覆盖计数和 Undo/Redo 正常。
- Automation `list` 保持可读并返回 `editable=false`；`set/reset` 返回明确锁定错误。

## 不做

- 位置锁或透明像素锁不作为属性内容门禁。
- 不改变 Figma 属性到文本后代的匹配规则。
- 不修改项目、导入、同步或 cursor；Automation 只增加可编辑状态与正确错误语义。
