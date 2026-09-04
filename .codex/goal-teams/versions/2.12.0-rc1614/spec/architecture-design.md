# rc1614 Architecture Design

## 最小接线

在 `revealAllLayers()` 的 `pushUndo()` 前，对 `document.slices` 使用稳定 `map` 并复用 `offsetForCanvasResize`。每项必须返回非 nil，否则抛出文件私有 `ImageEditorSliceCanvasTransformError.unexpectedRemoval`；与 Hotspot 的 `allowsRemoval: false` 在同一 `do/catch` 中完成。

随后预计算图层、参考线、Selection、Saved Selection 与 Alpha Channels；成功后一次性写入 `document.slices` 并调用 `syncExportSettingsForCurrentSliceScope()`。

## 原子顺序

Reveal rect/target 验证 → 全部 Slice/Hotspot throwing 预计算 → 其它状态预计算 → `pushUndo()` → 一次性写文档 → Slice scope/Hotspot selection 协调 → 视口、尺寸控件与 History。

## 不变项

- 不修改 `revealAllCanvasRect()`，Slice/Hotspot/Guide/Selection 不参与 bounds。
- 不调用 `normalized`，不清洗或降级元数据。
- 不重构 Canvas Size/Crop 路径，不扩 schema、UI 或 Automation payload。
