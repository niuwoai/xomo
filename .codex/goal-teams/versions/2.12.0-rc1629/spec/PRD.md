# PRD

## 问题

当前 Inspector 能显示类型、覆盖数和问题数，但单行仍不直观说明当前值是导入默认值、实例覆盖，还是没有 Figma baseline 的本地属性。

## 方案

在类型徽标旁增加来源徽标。来源由 ViewModel 共享的完整 override 判定纯派生，三态分别显示 `Imported default`、`Overridden`、`Local only` 的三语文案。

## 验收

- 完整相等对象显示 Imported default。
- value-only、metadata-only 或两者同时变化显示 Overridden。
- 缺失 default snapshot 的 Custom 显示 Local only，且不显示 reset、不计入 override。
- 来源徽标为只读，不参与搜索/过滤，不写入 Codable 或 Automation。
