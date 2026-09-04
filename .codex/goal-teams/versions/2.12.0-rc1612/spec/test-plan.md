# rc1612 Test Plan

## 新测试

- `ImageEditorSliceCanvasSizeTransformTests.swift`：纯 helper、九锚点、半像素/负尺寸、裁切/合法移除、preset 双校验、选择矩阵、单事务 Undo/Redo 与完整原子快照。
- `XomoAutomationSliceCanvasResizeTests.swift`：`xomo.canvas.resize_canvas` 后经 `xomo.slice.list` 验证真实共享入口，并直接检查 preset 与导出投影。

重点夹具：`100×80 → 140×120` 九锚点；`101×81 → 60×40` center 的 `-20.5` 半像素 offset；`100×80 → 60×40` center 同时覆盖保留、裁切、边界相切及完全越界移除。

## 原子失败

覆盖无效目标与源画布、零面积/NaN/无穷/溢出/源全越界 Slice、超限/不支持/非法值 preset、源倍率非法、裁切后目标倍率非法，以及将删除但源 preset 非法。比较 document、Undo/Redo、History、Export Settings、选择、面板、canvasOffset、锚点与四个尺寸控件，仅允许失败状态改变。

## 相邻回归

- rc1611 Slice Image Size 直接与 Automation 测试
- 完整 Canvas Command Tests 与 Hotspot Canvas Size Automation
- Slice preset/export/project round-trip
- 组件库系统箭头与真实平移 cursor
- CLI/MCP 与静态 release contracts

rc1612 不运行 rc1640 才要求的完整 Release、全量冒烟或 `/Applications` 覆盖。
