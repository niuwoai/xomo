# rc1615 PRD

## 目标

让画布五种正交变换同步投影全部 Fireworks 风格 Slice，保持交付区域与 preset 可用。

## 验收标准

1. CW、CCW、180°、水平与垂直翻转精确变换 Slice；90° 同步交换画布尺寸。
2. 允许历史部分越界 Slice，完整源外或损坏几何在 Undo 前原子拒绝。
3. 完整浮点 frame 变换后仅一次整数化并裁到目标；合法 Slice 不删除、不重排。
4. scale/width/height preset 在源可见 frame 与目标最终 frame 双校验，constraint/value 和全部 metadata 保持。
5. Slice scope 的有效、nil、stale、empty、no-preset 与非 Slice 状态按最终 frame 协调。
6. 成功仅一个 Undo、清 Redo、追加一条调用方既有 History；Undo/Redo 与尺寸控件正确往返。
7. 现有 `xomo.canvas.transform` 五个 action 经 `xomo.slice.list` 和导出计划证明复用同一入口。
