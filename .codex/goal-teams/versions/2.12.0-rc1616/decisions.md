# 2.12.0-rc1616 Decisions

- 覆盖以当前属性与同 key 导入默认的完整对象比较，不只比较 value。
- 无导入默认的 Custom 不算覆盖且不得被批量恢复修改。
- 批量恢复只创建一次 Undo、History 与状态更新；不循环调用单项 reset。
- TEXT 后代传播沿用现有值匹配和有效像素锁规则，按排序 key 确定执行顺序。
- ViewModel 无覆盖时静默 no-op；Automation `resetAll` 在内容锁定时仍按写操作拒绝。
