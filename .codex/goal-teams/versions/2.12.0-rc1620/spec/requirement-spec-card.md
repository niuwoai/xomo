# Requirement Spec Card

- User story：作为设计编辑者，我可以把一个 Figma 组件实例的覆盖值复制到另一个结构兼容实例，并可一次撤销。
- 输入：优先读取 Xomo 私有 sidecar；不存在时读取 rc1619 兼容纯文本 JSON。
- 约束：完整属性往返、严格 baseline、整单原子、目标 defaults 不变、内容锁生效。
- no-op：非空且合法、所有完整对象已相同；成功但不产生 Undo/History。
- 非目标：组件 identity/swap、结构替换、detach、Figma 网络导入。
