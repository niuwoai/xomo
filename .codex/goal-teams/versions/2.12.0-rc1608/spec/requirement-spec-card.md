# Requirement Spec Card

## 用户价值

调整 Canvas Size 后，Fireworks 风格热点应继续覆盖它所对应的画布内容，而不是停留在旧坐标或漂出画布。

## 冻结语义

- 使用与图层一致的九宫格锚点偏移，不缩放热点宽高。
- 平移后执行一次最终 `integral`，再与新画布求交。
- 部分越界裁切；完全越界或仅边界相切时移除。
- 存活热点只替换 `frame`，其 `id`、`name`、`url` 和相对顺序精确保持。
- 损坏或运算溢出的几何使整次命令在 Undo 快照前拒绝。
- 选中热点存活时保持；被移除或原选择已失效时回退到首个存活热点，无热点则为 `nil`；面板显隐不变。
- Undo/Redo 精确恢复文档，不在本版本扩展 UI 选择态历史。

## 九锚点公式

`offset = (newSize - oldSize) × (anchor.horizontalFactor, anchor.verticalFactor)`。

旧画布 `100×80` 扩大到 `140×100` 时，top-left/top/top-right 分别为 `(0,20)`、`(20,20)`、`(40,20)`；中行 Y 为 `10`；底行 Y 为 `0`。
