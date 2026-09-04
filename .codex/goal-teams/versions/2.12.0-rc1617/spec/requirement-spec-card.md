# Requirement Specification Card

- 场景：在“仅看已覆盖”中对单一属性点击还原，条目必须真正退出覆盖列表。
- metadata-only 与 value+metadata 漂移都恢复 type、value、preferredValues 完整快照。
- 其它覆盖与无默认 Custom 不受影响。
- 成功仅一次 Undo/History/status；第二次还原静默 no-op。
- 内容锁在 Undo 前阻止；Automation reset 返回 `overridden: false`。
