# PRD

## 用户价值

rc1619 已能精确复制覆盖值；rc1620 让这些覆盖值可以跨兼容实例复用，形成接近 Sketch/Figma 的组件覆盖工作流。

## 验收边界

- Copy Overrides → Reset All → Paste Overrides 精确恢复完整属性对象，包括 metadata-only 覆盖。
- 同 baseline 的另一实例可粘贴；同名但 baseline 不同的实例整单拒绝。
- 多属性和匹配 TEXT 后代由一个原子事务应用，一次 Undo/Redo 即可整体回退/重做。
- 干净实例也能看到 Paste Overrides；full/pixel lock 禁用，position/transparency lock 允许。
- UI 和 Automation 共享同一路径，三语言文案与 CLI/MCP schema 同步。
