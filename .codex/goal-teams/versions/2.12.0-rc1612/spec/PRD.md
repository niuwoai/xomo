# rc1612 PRD

## 目标

让 Canvas Size 与 Slice 交付元数据保持一致，复用现有九宫格坐标规则，并在裁切后保证导出 preset 仍真实可用。

## 验收标准

1. 九锚点扩大时 Slice 与图层/Hotspot 使用相同 offset，尺寸不缩放。
2. 半像素 offset、负尺寸和部分历史越界按完整浮点边平移，最终一次 integral 后裁切。
3. 一次缩小可同时保留、裁切和合法移除 Slice，幸存项顺序与全部元数据不变。
4. 源与目标最终 frame 双重校验三类 preset；非法数据在 Undo 前整单拒绝。
5. valid/removed/nil/stale/empty Slice scope 正确协调，非 Slice scope 完整不变。
6. 单事务 Undo/Redo、Redo 清空、History、面板、锚点、offset 与尺寸控件符合既有 Canvas Size 语义。
7. `xomo.canvas.resize_canvas` 与 `xomo.slice.list` 证明 Automation 复用真实入口。
