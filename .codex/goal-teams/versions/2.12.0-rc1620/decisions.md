# Decisions

- rc1619 的 `.string` 继续保持 `[String: XomoFigmaComponentProperty]`，不破坏外部 JSON 兼容。
- Copy Overrides 同时写入 `im.some.xomo.figma-component-property-overrides.v1` 私有 sidecar，携带 `version`、`overrides` 和对应 `importedDefaults`。
- sidecar 两个字典必须非空且 key 集精确相同；目标 imported default 必须与源 baseline 完整相等，才能完整替换 type、value 与 preferredValues。
- 私有类型存在但损坏或版本不支持时 fail closed，不降级读取纯文本。
- 仅有纯文本时走保守兼容：key/default 必须存在，type 与 preferredValues 必须与目标 default 相同。
- 任一 unknown、Custom、非法属性、baseline 不兼容或 TEXT 映射歧义都整单拒绝，且无 Undo、History 或项目副作用。
- 非空合法 no-op 成功但不创建 Undo/History；实际变化只创建一次 Undo 和一条 History。
- TEXT 后代更新由修改前快照统一规划，仅在新旧属性均为 TEXT 且 value 变化时执行；锁定后代跳过；组件自身或祖先 full/pixel lock 拒绝整单。
- UI 的 Paste Overrides 始终显示于属性标题栏，不依赖当前 overrideCount；Automation 新增 `pasteOverrides` 并返回 action-specific 计数。
