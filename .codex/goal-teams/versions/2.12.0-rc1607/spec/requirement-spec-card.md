# 需求规格卡：热点随 Image Size 缩放

## 用户价值

用户为视觉内容建立 Fireworks 风格热点后，执行 Image Size 时热点继续覆盖原内容；非等比缩放也不会让可点击区域滞留在旧画布坐标。

## 必须满足

- 使用 `scaleX = targetWidth / oldWidth` 与 `scaleY = targetHeight / oldHeight` 独立缩放热点四边。
- 最后统一以现有 `standardized.integral.intersection(canvasBounds)` 规则外接整数化并裁到目标画布。
- 保留热点数量、顺序、UUID、名称与 URL，只改变 frame。
- 全部热点必须在 `pushUndo()` 前完成转换；任一热点无效时整次 Image Size 拒绝，不能静默删除。
- 成功只建立一次 Undo、只追加一条 Image Resize History；Undo/Redo 恢复完整项目快照。
- 成功、失败、Undo 与 Redo 都保持 `selectedHotspotID` 和热点面板状态。
- 旧项目格式与 `xomo.canvas.resize_image` / `xomo.hotspot.list` 协议不变。

## 不做

- Canvas Size 锚点、Crop/Trim/Reveal、Rotate/Flip 的热点变换。
- Slice 几何同步、持久化 normalized/anchor/constraint。
- 热点 UI、Automation 参数、项目 schema、HTML 响应式脚本或 cursor 改动。
