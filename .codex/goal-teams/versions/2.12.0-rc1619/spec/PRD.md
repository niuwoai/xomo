# PRD

## 验收标准

- Inspector 有独立且本地化的 Copy Overrides 入口，只在覆盖数大于零时出现。
- JSON 是既有 Copy All 载荷的严格子集，完整保留 type/value/preferredValues。
- metadata-only 差异收录；Custom 无基线排除。
- 无覆盖不更改剪贴板与状态。
- 自身/祖先 full/pixel lock 不禁止复制。
- `xomo.figma.component_properties` 新增 `copyOverrides`，无覆盖返回明确错误。
