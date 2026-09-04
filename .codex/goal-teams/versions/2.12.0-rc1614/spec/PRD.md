# rc1614 PRD

## 目标

让 Reveal All 在非破坏扩画布事务中同步投影全部 Slice，并保证交付区域、preset 和导出选择真实可用。

## 验收标准

1. 左、上、右及四向扩展中 Slice 与图层使用同一 offset，尺寸不缩放。
2. 历史部分越界 Slice 使用完整浮点 frame 平移，落入新 target 的旧画布外区域重新显露。
3. Reveal target 和 availability 不受 Slice 影响；合法 Slice 不得被删除。
4. 源与目标 frame 双重校验 scale/width/height preset；非法数据在 Undo 前整单拒绝。
5. Slice 数量、顺序与全部元数据保持，scope 和主 preset 按最终 frame 协调。
6. 成功仅一个 Undo、一条 Reveal All History并清空 Redo；Undo/Redo 完整往返。
7. 现有 `xomo.canvas.transform(revealAll)` 与 `xomo.slice.list` 证明 Automation 复用同一入口。
