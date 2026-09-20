# Decisions

- 来源状态只由当前属性与可选 imported default 纯派生，不写入 `XomoFigmaComponentProperty`。
- 比较完整属性对象；value 相同但 type 或 preferredValues 不同仍是 Overridden。
- 无 baseline 的 Custom 是 Local only，不计入 override count，不显示 reset。
- 来源文案不参与属性搜索、筛选或 Automation payload。
- 来源徽标与既有 type badge 并存，独立 accessibility identifier，纯只读、不可聚焦和点击。
