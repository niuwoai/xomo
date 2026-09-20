# Decisions

- 采用 rc1630：Figma size constraint 字段的来源可见性是对现有 `xomoFigmaSizeConstraintDefaults` 与当前值的只读派生，不扩大到协议或数据模型。
- 每个字段独立判定；有 defaults 时 `nil` 与 `nil` 是 Imported default，值不同才是 Overridden；没有 defaults 时当前字段为空是 Unset、有值才是 Local only；nil baseline 与 `.empty` baseline 不混淆。
- UI 以紧凑来源徽标替换原本仅表示 override 的圆点；保留现有 reset/clear 行为与 accessibility field id。
