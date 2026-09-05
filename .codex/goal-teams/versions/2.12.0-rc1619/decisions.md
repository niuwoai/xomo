# Decisions

- 剪贴板输出沿用 `[String: XomoFigmaComponentProperty]`，Copy Overrides 只缩小 key 集合，不引入 envelope。
- 覆盖只由导入默认完整对象与当前对象比较决定；无默认 Custom 不是覆盖。
- 无覆盖时 ViewModel 返回 `false` 且不改剪贴板/状态；UI 不显示按钮。
- 复制是只读操作，不受自身或祖先的 full/pixel lock 影响。
- UI overrides-only 状态不参与剪贴板集合。
- Automation 新增 `copyOverrides`，成功后仍返回 rc1618 完整诊断快照。
