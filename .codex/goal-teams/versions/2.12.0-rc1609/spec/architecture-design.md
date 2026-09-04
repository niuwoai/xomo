# Architecture Design

## 共用预计算

继续使用 `ImageEditorHotspot.offsetForCanvasResize(offset:targetCanvasSize:)`。在 Canvas Commands 内以小型私有 helper 统一计算变换后的热点和有效选择 ID：

- Crop 模式允许 helper 返回 `nil`，使用稳定 `compactMap` 保序。
- Reveal 模式要求每个结果非 nil；throw 或 nil 都抛到命令边界并原子拒绝。
- 选择为 nil 时不自动选择；非 nil 且不存在于结果时回退首项或 nil。

## 接线点

- `crop(to:historyTitle:)` 是 direct crop、cropCenter、cropToSelection 与 trimTransparent 的共同漏斗，只在此接线。
- `revealAllLayers()` 独立接线，不改变 `revealAllCanvasRect()`，严禁把热点并入 bounds。
- `resizeCanvas` 可复用统一预计算 helper，保持 rc1608 行为且减少选择修复分叉。

## 原子顺序

合法 target/offset → 完整热点与选择预计算 → 图层/参考线预计算 → `pushUndo()` → 一次性写文档和选择 → history。失败仅设置 `imageEditor.status.resizeInvalid`。
