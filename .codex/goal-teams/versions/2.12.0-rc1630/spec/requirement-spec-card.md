# Requirement Specification Card

## 核心目标

在 Figma 响应式尺寸约束 Inspector 中，让用户知道每个约束字段是导入默认值、已本地覆盖，还是没有导入基线的本地字段。

## 关键流程

1. 选择带 Figma 尺寸约束的图层。
2. 查看每个字段旁的来源徽标。
3. 修改、清除或还原后，徽标由同一 ViewModel 派生结果即时更新。

## 边界

- 只读展示，不新增 Codable 字段。
- 不改变 Automation/MCP、导入、History/Undo/Redo、cursor 或约束写入规则。
- 缺少 imported defaults 时，空字段显示未设置，有值字段显示仅本地，不误报为 override。
